import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'goal_setup_screen.dart';
import 'spending_forecast_screen.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  // Match your app theme + premium purple accents
  static const _blue = Color(0xFF217BFF);
  static const _titleBlue = Color(0xFF0179FE);
  static const _bg = Colors.white;
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

  // Purple accent for glow
  static const _purple = Color(0xFF7C3AED); // premium violet
  static const _pink = Color(0xFFE879F9); // soft neon pink

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _summary;
  List<dynamic> _cuts = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      final uri = Uri.parse('${ApiConfig.nodeServerUrl}/api/ai/financial-health');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final goalEstimates = (data['goalEstimates'] as List<dynamic>? ?? []);
      final firstGoal = goalEstimates.isNotEmpty ? goalEstimates[0] as Map : null;
      final savingsRate = (data['savingsRate'] as num?)?.toDouble() ?? 0;
      final runwayMonths = (data['runwayMonths'] as num?)?.toDouble() ?? 0;

      setState(() {
        _summary = {
          'predicted_spend_next_30_days': data['avgMonthlySpend'],
          'estimated_monthly_net': data['monthlySavings'],
          'saving_goal_feasible': savingsRate > 0 && firstGoal?['monthsToAchieve'] != null,
          'goal_estimated_months_to_reach': firstGoal?['monthsToAchieve']?.toString(),
          'shortage_warning': runwayMonths < 2 && runwayMonths > 0
              ? 'Warning: At your current spending rate, your balance may run out in ${runwayMonths.toStringAsFixed(1)} months.'
              : null,
          'goal_title': firstGoal?['name'],
          'goal_target_amount': firstGoal != null ? ((firstGoal['remaining'] as num?)?.toDouble() ?? 0) : null,
          'inputs': {'currency': 'USD', 'currency_symbol': '\$'},
        };
        _cuts = (data['costCuttingSuggestions'] as List<dynamic>? ?? []).map((c) {
          return {
            'category': c['merchant'],
            'suggested_cut_percent': '20',
            'estimated_saving_next_30_days': (c['avgPerVisit'] as num?)?.toDouble() ?? 0,
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _money(num? v) {
    if (v == null) return "-";
    return v.toStringAsFixed(2);
  }

  String _fmtMoney(num? v) {
    final inputs = (_summary?["inputs"] as Map?) ?? {};
    final currency = inputs["currency"]?.toString() ?? "PKR";
    final symbol =
        inputs["currency_symbol"]?.toString() ??
        (currency == "PKR" ? "₨" : "\$");

    if (v == null) return "-";
    return "$symbol ${_money(v)}";
  }

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
    return Scaffold(
      extendBodyBehindAppBar: true, // ✅ makes bg reach the very top
      backgroundColor: const Color.fromARGB(
        0,
        0,
        0,
        0,
      ), // ✅ keep consistent + avoids dark gap
      // Premium glass app bar to match Home
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,

          // ❌ disable default back arrow
          automaticallyImplyLeading: false,
          titleSpacing: 0,

          // ✅ Custom glowing white back arrow
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.20),
                      blurRadius: 28,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),

          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 18,
                    right: 18,
                    bottom: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Financial Health",
                        style: TextStyle(
                          fontFamily: "Manrope",
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          // ===== Premium background glows (FULL SCREEN, NO GAP) =====
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;

                return Stack(
                  children: [
                    Positioned(
                      top: -h * 0.18,
                      right: -w * 0.42,
                      child: _BgGlow(
                        color: _purple.withOpacity(0.22),
                        size: h * 0.70,
                      ),
                    ),
                    Positioned(
                      top: -h * 0.14,
                      left: -w * 0.48,
                      child: _BgGlow(
                        color: _blue.withOpacity(0.16),
                        size: h * 0.72,
                      ),
                    ),
                    Positioned(
                      top: h * 0.18,
                      left: -w * 0.45,
                      child: _BgGlow(
                        color: _pink.withOpacity(0.12),
                        size: h * 0.80,
                      ),
                    ),
                    Positioned(
                      top: h * 0.22,
                      right: -w * 0.35,
                      child: _BgGlow(
                        color: _purple.withOpacity(0.14),
                        size: h * 0.78,
                      ),
                    ),
                    Positioned(
                      bottom: -h * 0.22,
                      right: -w * 0.45,
                      child: _BgGlow(
                        color: _pink.withOpacity(0.14),
                        size: h * 0.88,
                      ),
                    ),
                    Positioned(
                      bottom: -h * 0.20,
                      left: -w * 0.48,
                      child: _BgGlow(
                        color: _blue.withOpacity(0.12),
                        size: h * 0.82,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ===== Content =====
          _loading
              ? const _PremiumLoading()
              : (_error != null)
              ? _PremiumErrorView(error: _error!, onRetry: _fetch)
              : _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final s = _summary ?? {};

    final predictedSpend = s["predicted_spend_next_30_days"];
    final monthlyNet = s["estimated_monthly_net"];
    final savingFeasible = s["saving_goal_feasible"];
    final goalMonths = s["goal_estimated_months_to_reach"];
    final shortageWarning = s["shortage_warning"];
    final goalTitle = (s["goal_title"] ?? _summary?["inputs"]?["goal_title"])
        ?.toString();
    final goalAmount =
        (s["goal_target_amount"] ?? _summary?["inputs"]?["goal_target_amount"]);
    final goalTargetRaw =
        s["goal_target_amount"] ?? (_summary?["inputs"]?["goal_target_amount"]);
    final currency = _summary?["inputs"]?["currency"]?.toString() ?? "PKR";

    final bool hasGoal =
        goalTitle != null && goalTitle.trim().isNotEmpty && goalAmount != null;

    final String goalStatusText;
    if (!hasGoal) {
      goalStatusText = "Not set";
    } else if (goalMonths != null) {
      goalStatusText = "$goalMonths months";
    } else {
      goalStatusText = "Needs adjustment";
    }
    final goalTarget = (goalTargetRaw is num) ? goalTargetRaw.toDouble() : null;

    final bool feasible = savingFeasible == true;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top:
            MediaQuery.of(context).padding.top +
            110, // keep content below appbar
        bottom: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Premium hero insight card =====
          AIGlowHeroCard(
            title: "AI Insights (Next 30 Days)",
            subtitle: "Powered by your spending patterns",
            rows: [
              _HeroMetricRow(
                label: "Predicted Spending",
                value: _fmtMoney((predictedSpend as num?) ?? 0),
              ),
              _HeroMetricRow(
                label: "Estimated Monthly Net",
                value: _fmtMoney((monthlyNet as num?) ?? 0),
              ),
              _HeroMetricRow(
                label: "Saving Goal Feasible",
                value: feasible ? "Yes" : "No",
                valuePill: feasible ? _Pill.success : _Pill.warning,
              ),
            ],
            onRefresh: _fetch,
          ),

          const SizedBox(height: 18),

          // ===== Goals =====
          _ShimmerSectionTitle(text: "Goals"),
          const SizedBox(height: 10),

          _GlassCard(
            glowA: _purple.withOpacity(0.18),
            glowB: _blue.withOpacity(0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Your active goal",
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          colors: [
                            _purple.withOpacity(0.18),
                            _blue.withOpacity(0.18),
                          ],
                        ),
                        border: Border.all(color: _blue.withOpacity(0.18)),
                      ),
                      child: Text(
                        goalStatusText,
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                _ShimmerSectionTitle(text: "Goals"),
                const SizedBox(height: 4),
                Text(
                  "You can have one active goal at a time",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: "Manrope",
                    color: Colors.deepPurple.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                if (!hasGoal)
                  const Text(
                    "No active goal found. Set one to get predictions.",
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              _purple.withOpacity(0.25),
                              _blue.withOpacity(0.25),
                            ],
                          ),
                          border: Border.all(color: _blue.withOpacity(0.15)),
                        ),
                        child: const Icon(Icons.flag_rounded, color: _blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goalTitle!,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Target: $currency ${_money((goalAmount as num?) ?? 0)}",
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: _GradientButton(
              text: "Set / Update Goal",
              loading: false,
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  _premiumRoute(const GoalSetupScreen()),
                );
                if (updated == true) _fetch();
              },
            ),
          ),

          const SizedBox(height: 14),

          if (shortageWarning != null && shortageWarning.toString().isNotEmpty)
            _GlassCard(
              glowA: Colors.orange.withOpacity(0.14),
              glowB: _pink.withOpacity(0.12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shortageWarning.toString(),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Manrope",
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 18),

          // ===== Cost cutting suggestions =====
          // ===== Cost cutting suggestions =====
          _ShimmerSectionTitle(text: "Cost Cutting Suggestions"),
          const SizedBox(height: 10),

          if (_cuts.isEmpty)
            const _EmptyHint(
              text: "No suggestions yet (need more transaction history).",
            )
          else
            Column(
              children: _cuts.take(3).map((c) {
                final cat = c["category"]?.toString() ?? "Other";
                final pct = c["suggested_cut_percent"]?.toString() ?? "0";
                final save = c["estimated_saving_next_30_days"];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionCard(
                    category: cat,
                    subtitle:
                        "Reduce by $pct% → Save about ${_fmtMoney((save as num?) ?? 0)}",
                    glowA: _purple.withOpacity(0.14),
                    glowB: _blue.withOpacity(0.10),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 18),
          const SizedBox(height: 14),

          _GlassCard(
            glowA: _purple.withOpacity(0.18),
            glowB: _blue.withOpacity(0.14),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                // Navigator.push(
                //   context,
                //   _premiumRoute(const SpendingForecastScreen()),
                // );
              },
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          _purple.withOpacity(0.28),
                          _blue.withOpacity(0.22),
                        ],
                      ),
                      border: Border.all(color: _blue.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: _blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Spending Forecast",
                          style: TextStyle(
                            fontFamily: "Manrope",
                            color: _text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "See your next 30 days trend with a clean chart + peak-day insights.",
                          style: TextStyle(
                            fontFamily: "Manrope",
                            color: _muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: _purple.withOpacity(0.10),
                      border: Border.all(color: _purple.withOpacity(0.18)),
                    ),
                    child: const Text(
                      "View",
                      style: TextStyle(
                        fontFamily: "Manrope",
                        color: _purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _blue,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 14),
          // ===== Refresh =====
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _GradientButton(
              text: "Refresh Insights",
              loading: false,
              onPressed: _fetch,
            ),
          ),

          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

// ========================
// Background glow blob (radial, premium)
// ========================
class _BgGlow extends StatelessWidget {
  final Color color;
  final double size;
  const _BgGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ========================
// Premium Loading View
// ========================
class _PremiumLoading extends StatelessWidget {
  const _PremiumLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: const Color(0xFFE7F0FF),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF217BFF)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Loading insights",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF217BFF),
              fontFamily: "Manrope",
            ),
          ),
        ],
      ),
    );
  }
}

// ========================
// Premium Error View
// ========================
class _PremiumErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _PremiumErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 34,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Couldn’t load insights",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: "Manrope",
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.35,
              fontFamily: "Manrope",
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _GradientButton(
              text: "Retry",
              loading: false,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

// ========================
// Premium glass card (used across the screen)
// ========================
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color glowA;
  final Color glowB;

  const _GlassCard({
    required this.child,
    required this.glowA,
    required this.glowB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: glowA, blurRadius: 26, spreadRadius: 1),
          BoxShadow(color: glowB, blurRadius: 26, spreadRadius: -4),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ========================
// Premium gradient CTA button
// ========================
class _GradientButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF217BFF);
    const purple = Color(0xFF7C3AED);

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.zero,
        elevation: 0,
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [blue.withOpacity(0.95), purple.withOpacity(0.95)],
          ),
          boxShadow: [
            BoxShadow(
              color: blue.withOpacity(0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: purple.withOpacity(0.14),
              blurRadius: 22,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    fontFamily: "Manrope",
                  ),
                ),
        ),
      ),
    );
  }
}

// ========================
// Premium Hero Card (Glow border + moving strip)
// ========================
class AIGlowHeroCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<_HeroMetricRow> rows;
  final VoidCallback onRefresh;

  const AIGlowHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.onRefresh,
  });

  @override
  State<AIGlowHeroCard> createState() => _AIGlowHeroCardState();
}

class _AIGlowHeroCardState extends State<AIGlowHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF217BFF);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(0.24),
                blurRadius: 28,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.25),
                blurRadius: 26,
                spreadRadius: -8,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GlowBorderPainter(progress: _c.value, radius: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF217BFF), Color(0xFF6DD5ED)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: "Manrope",
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Manrope",
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...widget.rows.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WhiteMetricRow(row: r),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: widget.onRefresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                              ),
                            ),
                            child: const Text(
                              "Refresh AI Summary",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                fontFamily: "Manrope",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.35,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.30),
                                Colors.white.withOpacity(0.00),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroMetricRow {
  final String label;
  final String value;
  final _Pill? valuePill;

  const _HeroMetricRow({
    required this.label,
    required this.value,
    this.valuePill,
  });
}

enum _Pill { success, warning }

class _WhiteMetricRow extends StatelessWidget {
  final _HeroMetricRow row;
  const _WhiteMetricRow({required this.row});

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (row.valuePill == null) {
      trailing = Text(
        row.value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          fontFamily: "Manrope",
        ),
      );
    } else {
      final pillColor = (row.valuePill == _Pill.success)
          ? const Color(0xFF12B76A)
          : const Color(0xFFF79009);

      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: Colors.white.withOpacity(0.18),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pillColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pillColor.withOpacity(0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              row.value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFamily: "Manrope",
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          row.label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: "Manrope",
          ),
        ),
        trailing,
      ],
    );
  }
}

// ========================
// Shared premium components
// ========================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF101828),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        fontFamily: "Manrope",
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: "Manrope",
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String category;
  final String subtitle;
  final Color glowA;
  final Color glowB;

  const _SuggestionCard({
    required this.category,
    required this.subtitle,
    required this.glowA,
    required this.glowB,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF217BFF);

    return _GlassCard(
      glowA: glowA,
      glowB: glowB,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFE3F2FD), Color(0xFFF5FAFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: blue.withOpacity(0.10),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.pie_chart_rounded, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Manrope",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Manrope",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================
// Moving glow border painter (white strip moves around)
// ========================
class _GlowBorderPainter extends CustomPainter {
  final double progress;
  final double radius;

  _GlowBorderPainter({required this.progress, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF217BFF);
    final rect = Offset.zero & size;

    final r = RRect.fromRectAndRadius(
      rect.deflate(0.9),
      Radius.circular(radius),
    );

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: 6.283185307179586,
      transform: GradientRotation(6.283185307179586 * progress),
      colors: [
        blue.withOpacity(0.0),
        blue.withOpacity(0.22),
        Colors.white.withOpacity(0.95),
        blue.withOpacity(0.32),
        blue.withOpacity(0.0),
      ],
      stops: const [0.0, 0.40, 0.50, 0.60, 1.0],
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = sweep.createShader(rect);

    final innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = blue.withOpacity(0.16);

    canvas.drawRRect(r, innerGlow);
    canvas.drawRRect(r, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

class _ShimmerSectionTitle extends StatelessWidget {
  final String text;
  const _ShimmerSectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    const blue = Color.fromARGB(255, 243, 248, 255);
    const purple = Color.fromARGB(255, 246, 241, 255);

    return Container(
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [blue, purple],
          ).createShader(bounds);
        },
        child: Text(
          text,
          style: TextStyle(
            fontFamily: "Manrope",
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: purple.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              Shadow(
                color: blue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
