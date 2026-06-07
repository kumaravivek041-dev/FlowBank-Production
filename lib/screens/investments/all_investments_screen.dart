import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart';
import 'create_investment_screen.dart';
import 'closed_investments_screen.dart';
import 'investment_detail_sheet.dart';
import 'net_worth_screen.dart';
import '../collaboration/collaboration_screen.dart';
import '../notification/notification-page.dart';

class AllInvestmentsScreen extends StatefulWidget {
  const AllInvestmentsScreen({super.key});

  @override
  State<AllInvestmentsScreen> createState() => _AllInvestmentsScreenState();
}

class _AllInvestmentsScreenState extends State<AllInvestmentsScreen> {
  static const _blue   = Color(0xFF1E88E5);
  static const _textDark  = Color(0xFF1A1F36);
  static const _textMid   = Color(0xFF475467);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey    = Color(0xFFF5F7FA);
  static const _border    = Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _investments = [];
  bool _loading = true;
  String _userName = 'User';
  String _userInitials = 'U';
  static const int _selectedIndex = 0;
  Map<String, dynamic>? _benchmark;
  bool _benchmarkLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchInvestments();
    _fetchBenchmark();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userName = prefs.getString('userName') ?? 'User';
      _userInitials = prefs.getString('userInitials') ?? 'U';
    });
  }

  Future<void> _fetchInvestments() async {
    try {
      final res = await ApiService.get('/api/investments/active', context);
      if (res.statusCode == 200 && mounted) {
        final List data = jsonDecode(res.body);
        setState(() {
          _investments = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchBenchmark() async {
    if (mounted) setState(() => _benchmarkLoading = true);
    try {
      final res = await ApiService.get('/api/networth/benchmark', context);
      if (res.statusCode == 200 && mounted) {
        setState(() { _benchmark = jsonDecode(res.body); _benchmarkLoading = false; });
      } else {
        if (mounted) setState(() => _benchmarkLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _benchmarkLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CreateInvestmentScreen()),
        ).then((_) => _fetchInvestments()),
        backgroundColor: _blue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Investment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Manrope')),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
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
                selectedItemColor: _blue,
                unselectedItemColor: const Color(0xFF667085),
                currentIndex: _selectedIndex,
                showUnselectedLabels: true,
                onTap: (index) {
                  if (index == 0) {
                    Navigator.pop(context);
                  } else if (index == 1) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CollaborationScreen()));
                  } else if (index == 2) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage()));
                  }
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'Groups'),
                  BottomNavigationBarItem(icon: Icon(Icons.notification_add), label: 'Notifications'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchInvestments();
                await _fetchBenchmark();
              },
              color: _blue,
              child: _investments.isEmpty
                  ? _buildEmpty()
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _InvestmentTile(
                                investment: _investments[i],
                                onRefresh: _fetchInvestments,
                              ),
                              childCount: _investments.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: _buildBenchmarkSection()),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                      ],
                    ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255).withOpacity(0.0),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 18, right: 26, bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Investments',
                          style: TextStyle(
                            color: Color(0xFF0179FE),
                            fontSize: 28,
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildMenuButton(),
                        ),
                      ],
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

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'networth') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NetWorthScreen()));
        } else if (value == 'closed') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClosedInvestmentsScreen()));
        }
      },
      offset: const Offset(0, 44),
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'networth',
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0179FE).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF0179FE)),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Net Worth', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Manrope')),
              Text('Assets & liabilities', style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
            ]),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'closed',
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF475467).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF475467)),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Closed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Manrope')),
              Text('Exited investments', style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
            ]),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.more_horiz_rounded, size: 16, color: Color(0xFF475467)),
          SizedBox(width: 5),
          Text('More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475467), fontFamily: 'Manrope')),
        ]),
      ),
    );
  }

  Widget _buildBenchmarkSection() {
    if (_benchmarkLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _blue))),
      );
    }
    if (_benchmark == null || !(_benchmark!['hasBenchmark'] as bool? ?? false)) {
      return const SizedBox.shrink();
    }

    final portfolioReturn = (_benchmark!['portfolioReturn'] as num).toDouble();
    final benchmarkReturn = (_benchmark!['benchmarkReturn'] as num).toDouble();
    final alpha = (_benchmark!['alpha'] as num).toDouble();
    final portfolioValue = (_benchmark!['portfolioValue'] as num).toDouble();
    final benchmarkValue = (_benchmark!['benchmarkValue'] as num).toDouble();
    final chartData = (_benchmark!['chartData'] as List?) ?? [];
    final outperforming = alpha >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.leaderboard_rounded, color: _blue, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('vs S&P 500', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark, fontFamily: 'Manrope')),
            Text('Benchmark Comparison', style: TextStyle(fontSize: 11, color: _textLight)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: outperforming
                  ? const Color(0xFF10B981).withOpacity(0.10)
                  : const Color(0xFFEF4444).withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(outperforming ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 11, color: outperforming ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              const SizedBox(width: 3),
              Text(
                '${alpha > 0 ? '+' : ''}${alpha.toStringAsFixed(1)}% alpha',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: outperforming ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _benchStat('Your Portfolio', '\$${portfolioValue.toStringAsFixed(0)}',
              '${portfolioReturn >= 0 ? '+' : ''}${portfolioReturn.toStringAsFixed(1)}%',
              portfolioReturn >= 0 ? _blue : const Color(0xFFEF4444)),
          const SizedBox(width: 10),
          _benchStat('S&P 500 (SPY)', '\$${benchmarkValue.toStringAsFixed(0)}',
              '${benchmarkReturn >= 0 ? '+' : ''}${benchmarkReturn.toStringAsFixed(1)}%',
              const Color(0xFF64748B)),
        ]),
        if (chartData.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBenchmarkChart(chartData),
        ],
        const SizedBox(height: 10),
        Text(
          outperforming
              ? 'Your portfolio outperformed S&P 500 by ${alpha.toStringAsFixed(1)}%'
              : 'S&P 500 outperformed your portfolio by ${alpha.abs().toStringAsFixed(1)}%',
          style: TextStyle(
              fontSize: 11,
              color: outperforming ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _benchStat(String label, String value, String pct, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _textLight)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFamily: 'Manrope')),
        Text(pct, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.75))),
      ]),
    ),
  );

  Widget _buildBenchmarkChart(List chartData) {
    double maxVal = 1;
    for (final m in chartData) {
      final inv = (m['invested'] as num).toDouble();
      final spy = (m['spyValue'] as num).toDouble();
      if (inv > maxVal) maxVal = inv;
      if (spy > maxVal) maxVal = spy;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _legendDot(_blue, 'Amount Invested'),
        const SizedBox(width: 14),
        _legendDot(const Color(0xFF64748B), 'SPY Value'),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: chartData.map<Widget>((m) {
            final inv = (m['invested'] as num).toDouble();
            final spy = (m['spyValue'] as num).toDouble();
            final invH = (inv / maxVal * 60).clamp(4.0, 60.0);
            final spyH = (spy / maxVal * 60).clamp(4.0, 60.0);
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 5,
                    height: invH,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Container(
                    width: 5,
                    height: spyH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withOpacity(0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ));
          }).toList(),
        ),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          chartData.isNotEmpty ? (chartData.first['date'] as String) : '',
          style: const TextStyle(fontSize: 9, color: _textLight),
        ),
        Text(
          chartData.isNotEmpty ? (chartData.last['date'] as String) : '',
          style: const TextStyle(fontSize: 9, color: _textLight),
        ),
      ]),
    ]);
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: _textLight)),
  ]);

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: _bgGrey, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.trending_up_rounded, color: _textLight, size: 34)),
      const SizedBox(height: 16),
      const Text('No investments yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
      const SizedBox(height: 6),
      const Text('Tap "Add Investment" to start tracking', style: TextStyle(fontSize: 13, color: _textLight)),
    ]));
  }
}

// ─── Investment Tile ──────────────────────────────────────────────────────────

class _InvestmentTile extends StatelessWidget {
  final Map<String, dynamic> investment;
  final VoidCallback onRefresh;

  const _InvestmentTile({required this.investment, required this.onRefresh});

  static const _textDark  = Color(0xFF1A1F36);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey    = Color(0xFFF5F7FA);

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

  String get _typeLabel {
    switch (investment['type']) {
      case 'stock':       return 'Stock';
      case 'crypto':      return 'Crypto';
      case 'real_estate': return 'Real Estate';
      case 'business':    return 'Business';
      default:            return 'Other';
    }
  }

  double get _totalInvested {
    final buys = (investment['buyEntries'] as List?) ?? [];
    return buys.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _totalUnits {
    final buys = (investment['buyEntries'] as List?) ?? [];
    final withdrawals = (investment['withdrawalEntries'] as List?) ?? [];
    final bought = buys.fold(0.0, (s, e) => s + ((e['unitsAcquired'] as num?)?.toDouble() ?? 0.0));
    final withdrawn = withdrawals.fold(0.0, (s, e) => s + ((e['unitsWithdrawn'] as num?)?.toDouble() ?? 0.0));
    return bought - withdrawn;
  }

  String _fmtFreq(String f) {
    switch (f) {
      case 'weekly':   return 'Weekly';
      case 'monthly':  return 'Monthly';
      case 'yearly':   return 'Yearly';
      case 'one_time': return 'One-Time';
      default:         return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InvestmentDetailSheet(
          investment: investment,
          onRefresh: onRefresh,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(investment['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark, fontFamily: 'Manrope'), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(_typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
                const SizedBox(width: 6),
                Text(_fmtFreq(investment['frequency'] ?? ''), style: const TextStyle(fontSize: 11, color: _textLight, fontWeight: FontWeight.w500)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${_totalInvested.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text('invested', style: const TextStyle(fontSize: 11, color: _textLight)),
            ]),
          ]),
          if (_totalUnits > 0) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: color.withOpacity(0.1)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_totalUnits.toStringAsFixed(4)} units held',
                style: const TextStyle(fontSize: 12, color: _textLight, fontWeight: FontWeight.w500)),
              Text('Target: \$${((investment['targetAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/period',
                style: const TextStyle(fontSize: 12, color: _textLight, fontWeight: FontWeight.w500)),
            ]),
          ],
        ]),
      ),
    );
  }
}
