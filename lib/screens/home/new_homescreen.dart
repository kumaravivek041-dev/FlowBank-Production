import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../home/profile.dart';
import '../home/section_header.dart';
import '../onboarding/OnboardingScreen.dart';
import '../home/status_card.dart';
import '../home/status_card_box.dart';
import '../home/user-total-balance-view.dart';
import '../home/bank_transactions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../collaboration/collaboration_screen.dart';
import '../notification/notification-page.dart';
import 'financial_health_screen.dart';
import '../ai/ai_hub_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flowbank/api/api_service.dart';
import '../home/home_skeleton_loader.dart';
import 'all_transactions_screen.dart';
import '../connectBank/connect_bank_screen.dart';
import 'all_goals_screen.dart';
import '../investments/all_investments_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName;
  String? userInitials;
  String? email;
  double? totalBalance;
  List<BankAccount> plaidAccounts = [];
  List<Map<String, dynamic>> recentTransactions = [];
  bool isLoadingData = true;
  List<Map<String, dynamic>> allTransactions = [];
  List<Map<String, dynamic>> _manualHomeTransactions = [];
  List<Map<String, dynamic>> _goals = [];
  bool _goalsLoading = true;
  Map<String, String> _categorizedMap = {};
  List<Map<String, dynamic>> _investments = [];
  bool _investmentsLoading = true;
  double? _monthlyIncome;
  bool _incomeConfirmed = false;
  bool _incomeBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCategorizations();
    _fetchInvestments();
    _fetchSavedIncome();
  }

  static const List<String> _themeOrder = ['red', 'purple', 'blue'];

  IconData _goalIcon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'food':          return Icons.restaurant_rounded;
      case 'transport':     return Icons.directions_car_rounded;
      case 'subscriptions': return Icons.subscriptions_rounded;
      case 'bills':         return Icons.receipt_rounded;
      case 'shopping':      return Icons.shopping_bag_rounded;
      case 'health':        return Icons.favorite_rounded;
      case 'education':     return Icons.school_rounded;
      case 'entertainment': return Icons.movie_rounded;
      case 'home':          return Icons.home_rounded;
      default:              return Icons.savings_rounded;
    }
  }

Widget _addGoalSmallPlaceholder(String themeColor, {required VoidCallback onTap}) {
  final Map<String, Color> accents = {
    'red':    const Color(0xFFC11574),
    'purple': const Color(0xFFB968F6),
    'blue':   const Color(0xFF217BFF),
  };
  final Map<String, Color> bgs = {
    'red':    const Color(0xFFFEF6FB),
    'purple': const Color(0xFFF9F2FF),
    'blue':   const Color(0xFFF5FAFF),
  };
  final Map<String, Color> borders = {
    'red':    const Color(0xFFF6DBEA),
    'purple': const Color(0xFFF1E1FE),
    'blue':   const Color(0xFFD7E8FF),
  };

  // Match the exact size InfoCard renders at
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 72,
      decoration: BoxDecoration(
        color: bgs[themeColor],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borders[themeColor]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: accents[themeColor], size: 22),
          const SizedBox(height: 6),
          Text('Add Goal',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accents[themeColor])),
        ],
      ),
    ),
  );
}

Widget _addGoalBigPlaceholder({required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      // Match InfoCard_Box height
      height: 188,
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E8FF)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: Color(0xFF217BFF), size: 28),
          SizedBox(height: 8),
          Text('Add Goal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF217BFF))),
        ],
      ),
    ),
  );
}

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
      userInitials = prefs.getString('userInitials') ?? 'U';
      email = prefs.getString('userEmail') ?? '';
      
    });
    if (email != null && email!.isNotEmpty) {
    _fetchGoals();
    _fetchTotalBalance();  // ✅ Now email is guaranteed
    
  }
  }

  // Future<void> _loadUserEmail() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     email = prefs.getString('userEmail') ?? '';
  //   });
  //   if (email != null && email!.isNotEmpty) {
  //   await _fetchTotalBalance();  // ✅ Now email is guaranteed
  // }
  // }

  // Add this inside _HomeScreenState


// Predefined gradient pairs for cards
final List<List<Color>> _cardGradients = [
  [Color(0xFFB28DFF), Color(0xFFF3B0FF)],
  [Color(0xFF2193FF), Color(0xFF6DD5ED)],
  [Color(0xFF11998e), Color(0xFF38ef7d)],
  [Color(0xFFf7971e), Color(0xFFffd200)],
  [Color(0xFFc94b4b), Color(0xFF4b134f)],
];

Future<void> _fetchGoals() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    //final response = await ApiService.get("/api/bank/all-data/$email", context);
    final res = await ApiService.get(
      '/api/goals/my-goals',
      context
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      setState(() {
        _goals = data.cast<Map<String, dynamic>>();
        _goalsLoading = false;
      });
    }
  } catch (_) {
    setState(() => _goalsLoading = false);
  }
}

Future<void> _fetchInvestments() async {
  try {
    // ignore: use_build_context_synchronously
    final res = await ApiService.get('/api/investments/active', context);
    if (res.statusCode == 200 && mounted) {
      final List data = jsonDecode(res.body);
      setState(() {
        _investments = data.cast<Map<String, dynamic>>();
        _investmentsLoading = false;
      });
    }
  } catch (_) {
    if (mounted) setState(() => _investmentsLoading = false);
  }
}

Future<void> _fetchSavedIncome() async {
  try {
    // ignore: use_build_context_synchronously
    final res = await ApiService.get('/api/auth/income', context);
    if (res.statusCode == 200 && mounted) {
      final data = jsonDecode(res.body);
      setState(() {
        _monthlyIncome = (data['monthlyIncome'] as num?)?.toDouble();
        _incomeConfirmed = data['incomeConfirmed'] == true;
      });
    }
  } catch (_) {}
}

double _estimateIncomeFromTransactions(List<Map<String, dynamic>> transactions) {
  final Map<String, double> byMonth = {};
  for (final t in transactions) {
    final rawAmount = (t['amount'] as num?)?.toDouble() ?? 0.0;
    if (rawAmount >= 0) continue; // only credits (negative = money in from Plaid)
    final dateStr = t['date']?.toString() ?? '';
    try {
      final dt = DateTime.parse(dateStr);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + rawAmount.abs();
    } catch (_) {}
  }
  if (byMonth.isEmpty) return 0;
  final sorted = byMonth.keys.toList()..sort();
  final last3 = sorted.length > 3 ? sorted.sublist(sorted.length - 3) : sorted;
  return last3.fold(0.0, (s, k) => s + byMonth[k]!) / last3.length;
}

Future<void> _saveIncome(double amount) async {
  try {
    // ignore: use_build_context_synchronously
    final res = await ApiService.patch(
      '/api/auth/income',
      {'monthlyIncome': amount, 'incomeConfirmed': true},
      context,
    );
    if (res.statusCode == 200 && mounted) {
      setState(() { _monthlyIncome = amount; _incomeConfirmed = true; });
    }
  } catch (_) {}
}

void _showEditIncomeDialog(double current) {
  final ctrl = TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Monthly Income', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(ctrl.text);
            if (val != null && val >= 0) {
              Navigator.pop(context);
              _saveIncome(val);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF217BFF)),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> _fetchCategorizations() async {
  try {
    // ignore: use_build_context_synchronously
    final res = await ApiService.get('/api/categorize/my-categorizations', context);
    if (res.statusCode == 200 && mounted) {
      final List data = jsonDecode(res.body);
      setState(() {
        _categorizedMap = {
          for (final r in data)
            r['transactionId'].toString(): (r['categoryRefName']?.toString().isNotEmpty == true
                ? r['categoryRefName'].toString()
                : r['categorizedTo'] == 'goal' ? 'Goal' : 'Group'),
        };
      });
    }
  } catch (_) {}
}

void _showHomeCategorizeSheet(PlaidTransaction tx) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CategorizationSheet(
      tx: tx,
      onSuccess: (transactionId, refName) {
        if (mounted) setState(() => _categorizedMap[transactionId] = refName);
      },
    ),
  );
}

Future<void> _fetchTotalBalance() async {
  final stopwatch = Stopwatch()..start();
  try {
    final response = await ApiService.get("/api/bank/all-data/$email", context);

    print("⏱ API call took: ${stopwatch.elapsedMilliseconds} ms");

    if (response.statusCode == 200) {
      final parseWatch = Stopwatch()..start();
      final data = jsonDecode(response.body);

      print("⏱ JSON decode took: ${parseWatch.elapsedMilliseconds} ms");

      // Parse accounts
      final List accountsRaw = data['accounts'] ?? [];
final List<BankAccount> parsedAccounts = [];

for (int i = 0; i < accountsRaw.length; i++) {
  final acc = accountsRaw[i];

  String dateConnected = '';
  try {
    final dt = DateTime.parse(acc['dateConnected']);
    dateConnected =
        '${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
  } catch (_) {
    dateConnected = '';
  }

  // Parse sub-accounts
  final List subRaw = acc['subAccounts'] ?? [];
  final List<Map<String, dynamic>> subAccounts = subRaw
      .map((s) => Map<String, dynamic>.from(s))
      .toList();

  parsedAccounts.add(BankAccount(
    bankName: acc['institutionName'] ?? 'Bank',
    amount: (acc['totalBalance'] as num?)?.toDouble() ?? 0.0,
    dateConnected: dateConnected,
    gradientColors: _cardGradients[i % _cardGradients.length],
    subAccounts: subAccounts,
  ));
}
      // Parse recent transactions (last 5 from historical)
      final List historicalRaw = data['historical'] ?? [];
      final List<Map<String, dynamic>> allTxRaw = historicalRaw
    .map((t) => Map<String, dynamic>.from(t))
    .toList();
final List<Map<String, dynamic>> parsedTransactions = allTxRaw.take(5).toList();

      setState(() {
        totalBalance = (data['totalBalance'] as num?)?.toDouble() ?? 0.0;
        plaidAccounts = parsedAccounts;
        recentTransactions = parsedTransactions;
        isLoadingData = false;
        allTransactions = allTxRaw;   // ← add this
        print('✅ Total Balance: $totalBalance');
        print('✅ Accounts: ${plaidAccounts.length}');
        print('✅ Transactions: ${recentTransactions.length}');
      });
      _fetchManualTransactions();
    } else {
      print('Failed to fetch data: ${response.body}');
      setState(() => isLoadingData = false);
    }
  } catch (e) {
    print('Error fetching data: $e');
    setState(() => isLoadingData = false);
  }
}

Future<void> _fetchManualTransactions() async {
  try {
    final res = await ApiService.get('/api/manual-transactions', context);
    if (res.statusCode == 200 && mounted) {
      final List data = jsonDecode(res.body);
      final normalized = data.map<Map<String, dynamic>>((m) {
        final rawDate = m['date']?.toString() ?? '';
        final dateStr = rawDate.contains('T') ? rawDate.split('T').first : rawDate;
        final isDebit = (m['isDebit'] as bool?) ?? true;
        final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
        return {
          'transaction_id': 'manual_${m['_id']}',
          'name': m['name']?.toString() ?? 'Transaction',
          'amount': isDebit ? amount : -amount,
          'date': dateStr,
          'category': m['category']?.toString() ?? 'Other',
          'account_name': (m['source'] == 'ocr') ? 'Receipt' : 'Manual',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _manualHomeTransactions = normalized;
          final combined = [...allTransactions, ...normalized];
          combined.sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
          recentTransactions = combined.take(5).toList();
        });
      }
    }
  } catch (_) {}
}

Future<void> _handleRefresh() async {
  setState(() {
    isLoadingData = true;
    _investmentsLoading = true;
  });
  await Future.wait([
    _loadUserData(),
    _fetchInvestments(),
    _fetchCategorizations(),
  ]);
}

List<Bank> _buildBanksFromTransactions(List<Map<String, dynamic>> txList) {
  if (txList.isEmpty) return [];
  final Map<String, List<TransactionItem>> byAccount = {};
  for (final t in txList) {
    final accountName = (t['account_name'] ?? t['accountName'] ?? 'My Account').toString();
    final rawAmount = (t['amount'] as num?)?.toDouble() ?? 0.0;
    final isDebit = rawAmount > 0;
    final name = (t['name'] ?? t['merchant_name'] ?? 'Transaction').toString();
    final date = _fmtDate(t['date']?.toString() ?? '');
    final category = _fmtCategory(t['category']);
    final txId = t['transaction_id']?.toString() ?? t['id']?.toString() ?? '';
    final categorizedIn = _categorizedMap[txId];
    byAccount.putIfAbsent(accountName, () => []).add(TransactionItem(
      title: name,
      subtitle: category,
      date: date,
      amount: rawAmount.abs(),
      isPositive: !isDebit,
      categorizedIn: categorizedIn,
      onCategorize: categorizedIn == null
          ? () => _showHomeCategorizeSheet(PlaidTransaction(
                transactionId: txId,
                name: name,
                amount: rawAmount.abs(),
                date: t['date']?.toString() ?? '',
                category: category,
                accountName: accountName,
                isDebit: isDebit,
              ))
          : null,
    ));
  }
  return byAccount.entries.map((e) {
    final label = e.key;
    return Bank(
      name: label.length > 16 ? '${label.substring(0, 14)}…' : label,
      logoText: label.substring(0, 2).toUpperCase(),
      transactions: e.value,
    );
  }).toList();
}

String _fmtDate(String raw) {
  try {
    final dt = DateTime.parse(raw);
    const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month]}';
  } catch (_) { return raw; }
}

String _fmtCategory(dynamic cat) {
  if (cat == null) return 'Uncategorized';
  if (cat is String) return cat;
  if (cat is List && cat.isNotEmpty) return cat.last.toString();
  return 'Uncategorized';
}


  int _selectedIndex = 0;

  final Color activeColor = const Color(0xFF217BFF);
  final Color inactiveColor = const Color(0xFF667085);

  Route _premiumRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slide = Tween<Offset>(
          begin: const Offset(0.0, 0.04),
          end: Offset.zero,
        ).animate(curved);

        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,

        // ---------------------- APP BAR ----------------------
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0, // disable default shadow
            backgroundColor: const Color.fromARGB(
              0,
              255,
              255,
              255,
            ).withOpacity(0.0),
            surfaceTintColor: Colors.transparent, // IMPORTANT
            automaticallyImplyLeading: false,
            titleSpacing: 0,

            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 18,
                      right: 26,
                      bottom: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Welcome,",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontFamily: "Manrope",
                                    fontWeight: FontWeight.w700,
                                    height: -0.5,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  userName ?? 'User',
                                  style: TextStyle(
                                    color: Color(0xFF0179FE),
                                    fontSize: 28,
                                    fontFamily: "Manrope",
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
    Navigator.push(
      context,
       MaterialPageRoute(
        builder: (context) => ProfileScreen(),
      ),
    );
  },
                                child:  Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF5FAFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      userInitials ?? 'U',
                                      style: TextStyle(
                                        color: Color(0xFF0179FE), 
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ),
        ),

        // ---------------------- BODY (SCROLLABLE) ----------------------
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF0179FE),      // Spinner color (matches your theme)
          backgroundColor: Colors.white,        // Spinner background
          displacement: 40,                     // How far down the indicator appears
          strokeWidth: 2.5,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: BouncingScrollPhysics(), 
            ),
            
            child: Column(
              children: [
                // -------- INCOME BANNER --------
                Builder(builder: (_) {
                  if (_incomeBannerDismissed || _incomeConfirmed) return const SizedBox.shrink();
                  if (isLoadingData || allTransactions.isEmpty) return const SizedBox.shrink();
                  final estimated = _monthlyIncome ?? _estimateIncomeFromTransactions(allTransactions);
                  if (estimated <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBDD7FF), width: 1.2),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF217BFF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF217BFF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Estimated Monthly Income',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
                          const SizedBox(height: 2),
                          Text('\$${estimated.toStringAsFixed(0)}/month',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1F36), fontFamily: 'Manrope')),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _saveIncome(estimated),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF217BFF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(child: Text('Confirm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showEditIncomeDialog(estimated),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F0FE),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBDD7FF)),
                                  ),
                                  child: const Center(child: Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF217BFF)))),
                                ),
                              ),
                            ),
                          ]),
                        ])),
                        GestureDetector(
                          onTap: () => setState(() => _incomeBannerDismissed = true),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF98A2B3)),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),

                // -------- YOUR GOALS --------

                // -------- TOP SECTION --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
          
                      SectionHeader(
                        title: "Your Goals",
                        showButton: true,
                        onViewAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllGoalsScreen()),
                          ).then((_) => _fetchGoals());
                        },
                      ),
          
                      const SizedBox(height: 16),
          
                      Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 170,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Slot 1 - small card
        _goals.length > 1
            ? InfoCard(
                title: _goals[1]['goalName'],
                currentValue: (_goals[1]['currentSpend'] as num).toInt(),
                maxValue: (_goals[1]['amount'] as num).toInt(),
                themeColor: 'red',
                icon: _goalIcon(_goals[1]['category'] as String?),
              )
            : _addGoalSmallPlaceholder('red', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllGoalsScreen()))
                  .then((_) => _fetchGoals());
              }),

        const SizedBox(height: 8),

        // Slot 2 - small card
        _goals.length > 2
            ? InfoCard(
                title: _goals[2]['goalName'],
                currentValue: (_goals[2]['currentSpend'] as num).toInt(),
                maxValue: (_goals[2]['amount'] as num).toInt(),
                themeColor: 'purple',
                icon: _goalIcon(_goals[2]['category'] as String?),
              )
            : _addGoalSmallPlaceholder('purple', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllGoalsScreen()))
                  .then((_) => _fetchGoals());
              }),
      ],
    ),
    ),

    const SizedBox(width: 12),

    // Slot 0 - big card (first/primary goal)
    Expanded(
      child: _goals.isNotEmpty
          ? InfoCard_Box(
              title: _goals[0]['goalName'],
              currentValue: (_goals[0]['currentSpend'] as num).toInt(),
              maxValue: (_goals[0]['amount'] as num).toInt(),
              themeColor: 'blue',
              icon: _goalIcon(_goals[0]['category'] as String?),
            )
          : _addGoalBigPlaceholder(onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AllGoalsScreen()))
                .then((_) => _fetchGoals());
            }),
    ),
  ],
),
          
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
          
                // -------- INVESTMENTS --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Investments',
                        showButton: true,
                        onViewAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AllInvestmentsScreen()),
                          ).then((_) => _fetchInvestments());
                        },
                      ),
                      const SizedBox(height: 12),
                      _investmentsLoading
                          ? const SizedBox(
                              height: 72,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E88E5))),
                            )
                          : _investments.isEmpty
                              ? GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AllInvestmentsScreen()),
                                  ).then((_) => _fetchInvestments()),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7FA),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.trending_up_rounded, color: Color(0xFF98A2B3), size: 28),
                                        SizedBox(height: 8),
                                        Text('No investments yet',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
                                        SizedBox(height: 2),
                                        Text('Tap to start tracking your investments',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _investments.take(4).map((inv) => _HomeInvestmentTile(
                                    investment: inv,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AllInvestmentsScreen()),
                                    ).then((_) => _fetchInvestments()),
                                  )).toList(),
                                ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // -------- USER TOTAL CARDS --------
                // -------- USER TOTAL CARDS --------
          isLoadingData
              ? const HomeSkeletonLoader()
              : plaidAccounts.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB0B0B0), width: 1.2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 36, color: Color(0xFF5E5E5E)),
                    const SizedBox(height: 10),
                    const Text(
                      'No bank connected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D3D3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Connect a bank to see your accounts and transactions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5E5E5E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConnectBankScreen(isAddingNew: true)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF217BFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '+ Add Bank',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : UserTotal(accounts: plaidAccounts),
          
                // -------- TRANSACTIONS --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      const SizedBox(height: 26),
          
                      SectionHeader(
            title: 'Recent Transactions',
            showButton: allTransactions.isNotEmpty || _manualHomeTransactions.isNotEmpty,
            destination: AllTransactionsScreen(
              rawTransactions: allTransactions,
              userName: userName ?? 'User',
            ),
          ),
          const SizedBox(height: 16),
          (allTransactions.isEmpty && _manualHomeTransactions.isEmpty)
              ? Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: const [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF98A2B3), size: 32),
            SizedBox(height: 10),
            Text('No recent transactions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF667085))),
          ]),
                )
              : BankTransactionsWidget(
          banks: _buildBanksFromTransactions(recentTransactions),
          maxTransactionsPerBank: 5,
                ),
                    ],
                  ),
                ),
          
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Column(
                    children: [
                      SectionHeader(
                          title: "AI Analysis",
                          showButton: false,
                          destination: OnboardingScreen(),
                        ),
                        const SizedBox(height: 12),
                        AIFinancialHeroCard(
            onTap: () {
              Navigator.push(
                context,
                _premiumRoute(const AiHubScreen()),
              );
            },
          ),
          
                  ],
                  ),
                ),
                      
                // -------- SPACE FOR BOTTOM NAV --------
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),

        // ---------------------- BOTTOM NAV ----------------------
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 70 + bottomInset.clamp(0, 40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  selectedItemColor: activeColor,
                  unselectedItemColor: inactiveColor,
                  currentIndex: _selectedIndex,
                  showUnselectedLabels: true,
                  onTap: (index) {
                    if (index == 1) {
                      // Navigate to Groups page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CollaborationScreen(),
                        ),
                      );
                    } 
                    else if (index == 2) {
    // Navigate to Notifications page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationPage(),
      ),);} 
      else {
                      setState(() {
                        _selectedIndex = index;
                      });
                    }
                  },

                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded),
                      label: "Home",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.groups_rounded),
                      label: "Groups",
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.notification_add),
                      label: "Notifications",
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Home Investment Tile ─────────────────────────────────────────────────────

class _HomeInvestmentTile extends StatelessWidget {
  final Map<String, dynamic> investment;
  final VoidCallback onTap;

  const _HomeInvestmentTile({required this.investment, required this.onTap});

  Color get _typeColor {
    switch (investment['type']) {
      case 'stock':       return const Color(0xFF1E88E5);
      case 'crypto':      return const Color(0xFFF59E0B);
      case 'real_estate': return const Color(0xFF10B981);
      case 'business':    return const Color(0xFF7C3AED);
      default:            return const Color(0xFF64748B);
    }
  }

  IconData get _typeIcon {
    switch (investment['type']) {
      case 'stock':       return Icons.show_chart_rounded;
      case 'crypto':      return Icons.currency_bitcoin_rounded;
      case 'real_estate': return Icons.apartment_rounded;
      case 'business':    return Icons.business_center_rounded;
      default:            return Icons.trending_up_rounded;
    }
  }

  double get _totalInvested {
    final buys = (investment['buyEntries'] as List?) ?? [];
    return buys.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  }

  String get _typeLabel {
    switch (investment['type']) {
      case 'stock':       return 'Stock';
      case 'crypto':      return 'Crypto';
      case 'real_estate': return 'Real Estate';
      case 'business':    return 'Business';
      default:            return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18), width: 1.1),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
            child: Icon(_typeIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(investment['name'] ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1F36), fontFamily: 'Manrope'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_typeLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${_totalInvested.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            const Text('invested', style: TextStyle(fontSize: 10, color: Color(0xFF98A2B3))),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF98A2B3)),
        ]),
      ),
    );
  }
}

class AIFinancialHeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const AIFinancialHeroCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // 🔵 BACKGROUND (Replace this with your SVG)
              Positioned.fill(
  child: Image.asset(
    "assets/financial-prediction-background.png",
    fit: BoxFit.cover,
  ),
),



              // Optional curve overlay (subtle design detail)
              // Positioned(
              //   right: -40,
              //   top: -40,
              //   child: Container(
              //     width: 200,
              //     height: 200,
              //     decoration: BoxDecoration(
              //       border: Border.all(
              //         color: Colors.white.withOpacity(0.3),
              //         width: 1,
              //       ),
              //       shape: BoxShape.circle,
              //     ),
              //   ),
              // ),

              // CONTENT
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 41,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✨ Icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),

                    const Spacer(),

                    // 🧠 Title
                    Text(
                      "Financial\nPrediction System\nPowered by AI",
                      style: TextStyle(
                        fontSize: width < 360 ? 28 : 29,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.12,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 📄 Description
                    Text(
                      "An AI-powered system that provides near-accurate predictions of your financial stability and future outlook",
                      style: TextStyle(
                        fontSize: width < 360 ? 11 : 12.5,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // 🔘 Button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Try It",
                        style: TextStyle(
                          color: Color(0xFF217BFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}