const router = require('express').Router();
const axios = require('axios');
const protect = require('../middleware/middleware.js');
const { ModerateLimiter } = require('./rateLimiter.js');
const BankAccount = require('../models/user_BankAccount.js');
const BudgetGoal = require('../models/BudgetGoal.js');
const Investment = require('../models/Investment.js');
const User = require('../models/User.js');
const ManualTransaction = require('../models/ManualTransaction.js');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');
const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
const PYTHON_AI = process.env.PYTHON_AI_URL || 'http://127.0.0.1:8001';

const plaidClient = new PlaidApi(new Configuration({
  basePath: PlaidEnvironments.sandbox,
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
}));

// ─── Helper: gather user financial context ────────────────────────────────────

async function getUserFinancialContext(userId, userEmail) {
  try {
    const [user, bankAccounts, goals, investments, manualTxs] = await Promise.all([
      User.findById(userId).select('monthlyIncome incomeConfirmed'),
      BankAccount.find({ user: userId }),
      BudgetGoal.find({ userId: userId }),
      Investment.find({ userId: userId.toString(), status: 'active' }),
      ManualTransaction.find({ userId: userId.toString() }).sort({ date: -1 }).limit(200),
    ]);

    // Fetch transactions from Plaid for each bank account
    let allTransactions = [];
    let totalBalance = 0;

    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(endDate.getMonth() - 3);

    await Promise.all(bankAccounts.map(async (account) => {
      try {
        const [txRes, balRes] = await Promise.all([
          plaidClient.transactionsGet({
            access_token: account.plaidAccessToken,
            start_date: startDate.toISOString().split('T')[0],
            end_date: endDate.toISOString().split('T')[0],
          }),
          plaidClient.accountsBalanceGet({ access_token: account.plaidAccessToken }),
        ]);
        allTransactions = allTransactions.concat(txRes.data.transactions);
        totalBalance += balRes.data.accounts.reduce((s, a) => s + (a.balances.current || 0), 0);
      } catch (_) {}
    }));

    // Merge manual transactions (normalize to Plaid convention: positive=expense)
    const normalizedManual = manualTxs.map(t => ({
      date: t.date instanceof Date ? t.date.toISOString().split('T')[0] : String(t.date).split('T')[0],
      amount: t.isDebit ? t.amount : -t.amount,
      category: t.category || 'Other',
      name: t.name,
      merchant_name: t.name,
    }));
    allTransactions = allTransactions.concat(normalizedManual);

    // Current month stats
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const thisMonthDebits = allTransactions.filter(t => new Date(t.date) >= monthStart && t.amount > 0);
    const thisMonthCredits = allTransactions.filter(t => new Date(t.date) >= monthStart && t.amount < 0);

    const monthlySpend = thisMonthDebits.reduce((s, t) => s + t.amount, 0);
    const monthlyCredits = thisMonthCredits.reduce((s, t) => s + Math.abs(t.amount), 0);
    const monthlyIncome = (user?.monthlyIncome > 0) ? user.monthlyIncome : monthlyCredits;
    const netThisMonth = monthlyCredits - monthlySpend;

    // Top categories
    const catMap = {};
    thisMonthDebits.forEach(t => {
      const cat = Array.isArray(t.category) ? t.category[t.category.length - 1] : (t.category || 'Other');
      catMap[cat] = (catMap[cat] || 0) + t.amount;
    });
    const topCategories = Object.entries(catMap)
      .sort((a, b) => b[1] - a[1]).slice(0, 5)
      .map(([c, a]) => `${c}: $${a.toFixed(0)}`);

    const goalsSummary = goals.map(g =>
      `${g.goalName}: $${g.currentSpend} of $${g.amount} (${g.category})`
    ).join('; ') || 'No active goals';

    const investSummary = investments.map(inv => {
      const invested = inv.buyEntries.reduce((s, e) => s + e.amount, 0);
      return `${inv.name} (${inv.type}): $${invested.toFixed(0)} invested`;
    }).join('; ') || 'No active investments';

    const context = `
USER FINANCIAL SNAPSHOT (${now.toDateString()}):
- Bank Balance: $${totalBalance.toFixed(2)}
- Monthly Income: $${monthlyIncome.toFixed(2)}/month
- Spent This Month: $${monthlySpend.toFixed(2)}
- Income This Month: $${monthlyCredits.toFixed(2)}
- Net This Month: ${netThisMonth >= 0 ? '+' : ''}$${netThisMonth.toFixed(2)} (${netThisMonth >= 0 ? 'surplus' : 'deficit'})
- Top Spending: ${topCategories.join(', ') || 'N/A'}
- Goals: ${goalsSummary}
- Investments: ${investSummary}
    `.trim();

    return { context, transactions: allTransactions, totalBalance, monthlyIncome, goals: goals.map(g => g.toObject()) };
  } catch (e) {
    console.error('Context error:', e.message);
    return { context: 'Financial data unavailable.', transactions: [], totalBalance: 0, monthlyIncome: 0, goals: [] };
  }
}

// ─── POST /api/ai/chat ────────────────────────────────────────────────────────

router.post('/chat', protect, ModerateLimiter, async (req, res) => {
  try {
    const { message, history = [] } = req.body;
    if (!message) return res.status(400).json({ message: 'message required' });

    const { context } = await getUserFinancialContext(req.user._id, req.user.email);

    const systemPrompt = `You are Finara, a personal financial AI assistant in the FlowBank app. You have the user's real financial data below. Use it to give personalised, actionable advice.

${context}

GUIDELINES:
- Be conversational, warm, and concise (2-4 sentences unless more detail is truly needed)
- Always ground advice in the user's actual numbers
- If asked about a purchase, consider their balance, monthly net, and goals
- Use $ for amounts. Never fabricate numbers not in the snapshot
- If data is missing for a question, say so honestly`;

    const messages = [
      { role: 'system', content: systemPrompt },
      ...history.slice(-10),
      { role: 'user', content: message },
    ];

    const completion = await groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      messages,
      max_tokens: 512,
      temperature: 0.7,
    });

    res.json({ reply: completion.choices[0]?.message?.content || 'Could not generate a response.' });
  } catch (e) {
    console.error('Chat error:', e.message);
    res.status(500).json({ message: e.message });
  }
});

// ─── GET /api/ai/spending-forecast ───────────────────────────────────────────

router.get('/spending-forecast', protect, async (req, res) => {
  try {
    const { transactions } = await getUserFinancialContext(req.user._id, req.user.email);
    if (transactions.length < 5) return res.status(400).json({ message: 'Not enough transaction data' });

    const formatted = transactions.map(t => ({
      date: typeof t.date === 'string' ? t.date : new Date(t.date).toISOString().split('T')[0],
      amount: parseFloat(t.amount) || 0,
      category: Array.isArray(t.category) ? t.category[t.category.length - 1] : (t.category || 'Other'),
    }));

    const result = await axios.post(`${PYTHON_AI}/ai/forecast`, { transactions: formatted, forecastDays: 30 }, { timeout: 60000 });
    res.json(result.data);
  } catch (e) {
    console.error('Forecast error:', e.message);
    res.status(500).json({ message: e.response?.data?.error || e.message });
  }
});

// ─── GET /api/ai/financial-health ────────────────────────────────────────────

router.get('/financial-health', protect, async (req, res) => {
  try {
    const { transactions, totalBalance, monthlyIncome, goals } = await getUserFinancialContext(req.user._id, req.user.email);
    if (transactions.length < 5) return res.status(400).json({ message: 'Not enough transaction data' });

    const formatted = transactions.map(t => ({
      date: typeof t.date === 'string' ? t.date : new Date(t.date).toISOString().split('T')[0],
      amount: parseFloat(t.amount) || 0,
      category: Array.isArray(t.category) ? t.category[t.category.length - 1] : (t.category || 'Other'),
      name: t.merchant_name || t.name || 'Unknown',
    }));

    const result = await axios.post(`${PYTHON_AI}/ai/health`, {
      transactions: formatted,
      monthlyIncome,
      currentBalance: totalBalance,
      goals,
    }, { timeout: 60000 });
    res.json(result.data);
  } catch (e) {
    console.error('Health error:', e.message);
    res.status(500).json({ message: e.response?.data?.error || e.message });
  }
});

module.exports = router;
