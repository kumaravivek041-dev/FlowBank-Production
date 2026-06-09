import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '/models/forecast_point.dart';
import '/api/forecast_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpendingForecastScreen extends StatefulWidget {
  const SpendingForecastScreen({super.key});

  @override
  State<SpendingForecastScreen> createState() => _SpendingForecastScreenState();
}

class _SpendingForecastScreenState extends State<SpendingForecastScreen> {
  // Theme (matches your FinancialHealth premium vibe)
  static const _blue = Color(0xFF217BFF);
  static const _titleBlue = Color(0xFF0179FE);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

  static const _purple = Color(0xFF7C3AED);
  static const _pink = Color(0xFFE879F9);

  late Future<List<ForecastPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAndFetch();
  }

  Future<List<ForecastPoint>> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    if (userId == null || userId.isEmpty) {
      throw Exception("User not logged in (no userId in SharedPreferences)");
    }

    return ForecastApi.fetchForecast(userId: userId, horizon: 30);
  }

  // ---------- Formatting ----------
  String _two(int n) => n.toString().padLeft(2, "0");
  String _fmtDate(DateTime d) => "${d.year}-${_two(d.month)}-${_two(d.day)}";
  String _fmtShort(DateTime d) => "${d.day}/${d.month}";

  String _compact(num v) {
    final n = v.abs();
    if (n >= 10000000) return "${(v / 10000000).toStringAsFixed(1)}Cr";
    if (n >= 100000) return "${(v / 100000).toStringAsFixed(1)}L";
    if (n >= 1000) return "${(v / 1000).toStringAsFixed(1)}k";
    return v.toStringAsFixed(0);
  }

  String _pkr(num? v, {int decimals = 0}) {
    if (v == null) return "-";
    final fixed = v.toStringAsFixed(decimals);
    return "\$ $fixed";
  }

  double _niceStep(double range) {
    // Pick a readable axis interval
    if (range <= 0) return 1;
    final raw = range / 4;
    final pow10 = (raw == 0)
        ? 1
        : (raw.abs().toString().split(".").first.length);
    final base = pow10 <= 1 ? 1 : (pow10 == 2 ? 10 : (pow10 == 3 ? 100 : 1000));
    final candidate = (raw / base).round().clamp(1, 9) * base;
    return candidate.toDouble();
  }

  Route _premiumRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
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
      extendBodyBehindAppBar: true, // ✅ makes bg reach the very top (UI only)
      backgroundColor: const Color.fromARGB(0, 0, 0, 0), // ✅ no dark gap
      // Premium glass appbar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,

          // ❌ remove iconTheme (we’ll control leading manually)
          automaticallyImplyLeading: false,
          titleSpacing: 0,

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
                      color: Colors.white.withOpacity(0.45), // glow
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
                        "Spending Forecast",
                        style: TextStyle(
                          fontFamily: "Manrope",
                          color: Color.fromARGB(255, 255, 244, 249),
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

          FutureBuilder<List<ForecastPoint>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _PremiumLoading(text: "Loading forecast");
              }
              if (snap.hasError) {
                return _PremiumErrorView(
                  error: snap.error.toString(),
                  onRetry: () => setState(() => _future = _loadAndFetch()),
                );
              }

              final points = snap.data ?? [];
              if (points.isEmpty) {
                return const Center(
                  child: Text(
                    "No forecast data",
                    style: TextStyle(
                      fontFamily: "Manrope",
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              // Spots
              final spots = <FlSpot>[];
              for (int i = 0; i < points.length; i++) {
                spots.add(FlSpot(i.toDouble(), points[i].yhat.toDouble()));
              }

              // Raw bounds from forecast
              final double minYRaw = points
                  .map((e) => e.yhatLower.toDouble())
                  .reduce((a, b) => a < b ? a : b);

              final double maxYRaw = points
                  .map((e) => e.yhatUpper.toDouble())
                  .reduce((a, b) => a > b ? a : b);

              // Add padding so chart breathes
              final double range = (maxYRaw - minYRaw).abs();
              final double pad = (range * 0.12)
                  .clamp(1.0, double.infinity)
                  .toDouble();

              // Final bounds used by the chart
              final double minY = (minYRaw - pad)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              final double maxY = (maxYRaw + pad).toDouble();

              final interval = _niceStep((maxY - minY));

              // Insights
              final total = points.fold<double>(0, (s, p) => s + p.yhat);
              final avg = total / points.length;

              ForecastPoint maxPoint = points.first;
              for (final p in points) {
                if (p.yhat > maxPoint.yhat) maxPoint = p;
              }

              final start = points.first.ds;
              final end = points.last.ds;

              // Simple suggestions (UX)
              final suggestions = <String>[
                "Use this forecast to set a weekly budget and avoid surprise spikes.",
                "If your peak day is near salary date, try auto-saving before spending starts.",
                "Cutting even 10% from your top category can materially improve monthly net.",
              ];

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: MediaQuery.of(context).padding.top + 110,
                  bottom: 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary hero
                    _GlassCard(
                      glowA: _purple.withOpacity(0.18),
                      glowB: _blue.withOpacity(0.14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  _purple.withOpacity(0.25),
                                  _blue.withOpacity(0.25),
                                ],
                              ),
                              border: Border.all(
                                color: _blue.withOpacity(0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: _blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Next 30 Days Forecast",
                                  style: TextStyle(
                                    fontFamily: "Manrope",
                                    color: _text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "From ${_fmtDate(start)} to ${_fmtDate(end)}",
                                  style: const TextStyle(
                                    fontFamily: "Manrope",
                                    color: _muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // KPI row
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: "Total (30d)",
                            value: _pkr(total, decimals: 0),
                            glowA: _purple.withOpacity(0.16),
                            glowB: _pink.withOpacity(0.10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            title: "Avg / Day",
                            value: _pkr(avg, decimals: 0),
                            glowA: _blue.withOpacity(0.14),
                            glowB: _purple.withOpacity(0.10),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _KpiCard(
                      title: "Peak Day",
                      value:
                          "${_fmtDate(maxPoint.ds)} • ${_pkr(maxPoint.yhat, decimals: 0)}",
                      glowA: Colors.orange.withOpacity(0.14),
                      glowB: _pink.withOpacity(0.10),
                      leadingIcon: Icons.bolt_rounded,
                    ),

                    const SizedBox(height: 14),

                    // Chart Card
                    _GlassCard(
                      glowA: _purple.withOpacity(0.18),
                      glowB: _blue.withOpacity(0.14),
                      child: SizedBox(
                        height: 290,
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: interval,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: const Color(
                                    0xFF101828,
                                  ).withOpacity(0.06),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 52,
                                  interval: interval,
                                  getTitlesWidget: (value, meta) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(
                                        _compact(value),
                                        style: const TextStyle(
                                          fontFamily: "Manrope",
                                          fontSize: 10.5,
                                          color: _muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx >= points.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _fmtShort(points[idx].ds),
                                        style: const TextStyle(
                                          fontFamily: "Manrope",
                                          fontSize: 10,
                                          color: _muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                tooltipRoundedRadius: 14,
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),

                                // ✅ FIX: use tooltipBgColor instead of getTooltipColor
                                tooltipBgColor: Colors.white.withOpacity(0.92),

                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((s) {
                                    final idx = s.x.toInt().clamp(
                                      0,
                                      points.length - 1,
                                    );
                                    final p = points[idx];
                                    return LineTooltipItem(
                                      "${_fmtDate(p.ds)}\n"
                                      "Predicted: ${_pkr(p.yhat, decimals: 0)}",
                                      const TextStyle(
                                        fontFamily: "Manrope",
                                        color: _text,
                                        fontWeight: FontWeight.w900,
                                        height: 1.2,
                                        fontSize: 12.5,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                gradient: const LinearGradient(
                                  colors: [_purple, _blue],
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _purple.withOpacity(0.18),
                                      _blue.withOpacity(0.06),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Suggestions
                    _SectionTitle(
                      "Reading Suggestions",
                      colorA: const Color.fromARGB(255, 212, 190, 248),
                      colorB: _pink,
                    ),
                    const SizedBox(height: 10),

                    Column(
                      children: suggestions
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SuggestionTile(text: t),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 14),

                    // Preview list (nice)
                    _SectionTitle(
                      "Preview (First 5 Days)",
                      colorA: const Color.fromARGB(255, 212, 190, 248),
                      colorB: _pink,
                    ),
                    const SizedBox(height: 10),

                    _GlassCard(
                      glowA: _blue.withOpacity(0.14),
                      glowB: _purple.withOpacity(0.12),
                      child: Column(
                        children: List.generate(points.length.clamp(0, 5), (i) {
                          final p = points[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == 4 ? 0 : 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmtDate(p.ds),
                                  style: const TextStyle(
                                    fontFamily: "Manrope",
                                    color: _text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Text(
                                  _pkr(p.yhat, decimals: 0),
                                  style: const TextStyle(
                                    fontFamily: "Manrope",
                                    color: _muted,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- Premium pieces ----------

// ✅ UPDATED: Radial premium glow (matches FinancialHealthScreen)
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

class _PremiumLoading extends StatelessWidget {
  final String text;
  const _PremiumLoading({required this.text});

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
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Manrope",
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF217BFF),
            ),
          ),
        ],
      ),
    );
  }
}

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
            "Couldn’t load forecast",
            style: TextStyle(
              fontFamily: "Manrope",
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Manrope",
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF217BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Retry",
                style: TextStyle(
                  fontFamily: "Manrope",
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          BoxShadow(color: glowA, blurRadius: 28, spreadRadius: 1),
          BoxShadow(color: glowB, blurRadius: 28, spreadRadius: -4),
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

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color glowA;
  final Color glowB;
  final IconData? leadingIcon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.glowA,
    required this.glowB,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      glowA: glowA,
      glowB: glowB,
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF5FAFF),
                border: Border.all(
                  color: const Color(0xFF217BFF).withOpacity(0.12),
                ),
              ),
              child: Icon(leadingIcon, color: const Color(0xFF217BFF)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Manrope",
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Manrope",
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color colorA;
  final Color colorB;

  const _SectionTitle(this.text, {required this.colorA, required this.colorB});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(colors: [colorA, colorB]).createShader(rect);
      },
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Manrope",
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),  
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  const _SuggestionTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFE3F2FD),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF217BFF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Manrope",
                color: Color(0xFF667085),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
