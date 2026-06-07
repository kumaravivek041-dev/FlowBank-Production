const router = require('express').Router();
const protect = require('../middleware/middleware.js');
const ManualTransaction = require('../models/ManualTransaction.js');
const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const VALID_CATEGORIES = [
  'Food & Drink', 'Shopping', 'Transport', 'Healthcare',
  'Entertainment', 'Utilities', 'Travel', 'Education', 'Other',
];

// ─── POST /api/manual-transactions ────────────────────────────────────────────
router.post('/', protect, async (req, res) => {
  try {
    const { name, amount, date, category, isDebit, source } = req.body;
    if (!name || amount == null) return res.status(400).json({ message: 'name and amount required' });

    const tx = await ManualTransaction.create({
      userId:   req.user._id.toString(),
      name,
      amount:   Math.abs(parseFloat(amount)),
      date:     date ? new Date(date) : new Date(),
      category: VALID_CATEGORIES.includes(category) ? category : 'Other',
      isDebit:  isDebit !== undefined ? Boolean(isDebit) : true,
      source:   ['manual', 'ocr'].includes(source) ? source : 'manual',
    });

    res.status(201).json(tx);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ─── GET /api/manual-transactions ─────────────────────────────────────────────
router.get('/', protect, async (req, res) => {
  try {
    const txs = await ManualTransaction.find({ userId: req.user._id.toString() }).sort({ date: -1 });
    res.json(txs);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ─── POST /api/manual-transactions/scan — OCR via Groq Vision ─────────────────
router.post('/scan', protect, async (req, res) => {
  try {
    const { imageBase64, mimeType } = req.body;
    if (!imageBase64) return res.status(400).json({ message: 'imageBase64 required' });

    const mime = mimeType || 'image/jpeg';
    const today = new Date().toISOString().split('T')[0];

    const completion = await groq.chat.completions.create({
      model: 'llama-3.2-11b-vision-preview',
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: { url: `data:${mime};base64,${imageBase64}` },
          },
          {
            type: 'text',
            text: `You are a receipt parser. Extract the transaction info and return ONLY a valid JSON object with exactly these fields:
{"name":"store or merchant name","amount":0.00,"date":"YYYY-MM-DD","category":"one of: Food & Drink, Shopping, Transport, Healthcare, Entertainment, Utilities, Travel, Education, Other"}
Rules: amount = total paid as a number (no currency symbols), date in YYYY-MM-DD format (use ${today} if not visible). Return ONLY the JSON object, no explanation.`,
          },
        ],
      }],
      max_tokens: 200,
      temperature: 0.1,
    });

    const content = completion.choices[0]?.message?.content?.trim() || '';
    const match = content.match(/\{[\s\S]*?\}/);
    if (!match) return res.status(422).json({ message: 'Could not extract data from receipt' });

    const data = JSON.parse(match[0]);

    res.json({
      name:     String(data.name || '').trim() || 'Unknown',
      amount:   Math.abs(parseFloat(data.amount) || 0),
      date:     typeof data.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(data.date) ? data.date : today,
      category: VALID_CATEGORIES.includes(data.category) ? data.category : 'Other',
      isDebit:  true,
    });
  } catch (e) {
    console.error('OCR scan error:', e.message);
    res.status(500).json({ message: 'Could not process receipt. Please enter details manually.' });
  }
});

// ─── DELETE /api/manual-transactions/:id ──────────────────────────────────────
router.delete('/:id', protect, async (req, res) => {
  try {
    await ManualTransaction.findOneAndDelete({ _id: req.params.id, userId: req.user._id.toString() });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;
