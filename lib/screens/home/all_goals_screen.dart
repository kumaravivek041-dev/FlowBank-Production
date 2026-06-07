import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flowbank/api/api_service.dart';
import 'dart:convert';
import '../addGoalsInitialSignin/budget-goal-screen.dart';
import '../home/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllGoalsScreen extends StatefulWidget {
  const AllGoalsScreen({super.key});

  @override
  State<AllGoalsScreen> createState() => _AllGoalsScreenState();
}

class _AllGoalsScreenState extends State<AllGoalsScreen> {
  static const _textDark  = Color(0xFF1A1F36);
  static const _textLight = Color(0xFF98A2B3);
  static const _bgGrey    = Color(0xFFF5F7FA);

  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;
  String? userName;
  String? userInitials;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchGoals();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userName     = prefs.getString('userName') ?? 'User';
        userInitials = prefs.getString('userInitials') ?? 'U';
      });
    }
  }

  Future<void> _fetchGoals() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.get('/api/goals/my-goals', context);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _goals = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _accentColor(String? theme) {
    switch (theme) {
      case 'purple': return const Color(0xFF9B59B6);
      case 'blue':   return const Color(0xFFE53935);
      default:       return const Color(0xFF1E88E5); 
    }
  }

  IconData _categoryIcon(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          flexibleSpace: SafeArea(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Goals',
                            style: TextStyle(
                              fontSize: 28,
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          // const SizedBox(height: 2),
                          // Text(
                          //   userName ?? 'User',
                          //   style: const TextStyle(
                          //     color: Color(0xFF0179FE),
                          //     fontSize: 16,
                          //     fontFamily: 'Manrope',
                          //     fontWeight: FontWeight.w600,
                          //   ),
                          // ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProfileScreen()),
                          ),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5FAFF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              userInitials ?? 'U',
                              style: const TextStyle(
                                color: Color(0xFF0179FE),
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BudgetGoalScreen(onGoalAdded: _fetchGoals),
            ),
          );
        },
        backgroundColor: const Color(0xFF217BFF),
        elevation: 2,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Goal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
            fontSize: 14,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGoals,
        color: const Color(0xFF217BFF),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF217BFF)))
            : _goals.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _emptyState(),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _goals.length,
                    itemBuilder: (context, i) => _GoalTile(
                      goal: _goals[i],
                      accentColor: _accentColor(_goals[i]['themeColor'] as String?),
                      icon: _categoryIcon(_goals[i]['category'] as String?),
                      onTap: () => _showAddSpendSheet(_goals[i]),
                    ),
                  ),
      ),
    );
  }

  void _showAddSpendSheet(Map<String, dynamic> goal) {
    final String goalId    = goal['_id']?.toString() ?? '';
    final String goalName  = goal['goalName'] ?? '';
    final double amount    = (goal['amount'] as num).toDouble();
    final double spent     = (goal['currentSpend'] as num? ?? 0).toDouble();
    final accentColor      = _accentColor(goal['themeColor'] as String?);
    final bool isSavings   = (goal['goalType'] as String?) == 'savings';
    final amountCtrl       = TextEditingController();
    bool submitting        = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Goal icon + name row
                    Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                          alignment: Alignment.center,
                          child: Icon(_categoryIcon(goal['category'] as String?), color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goalName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Manrope', color: accentColor),
                              ),
                              Text(
                                '\$${spent.toStringAsFixed(0)} of \$${amount.toStringAsFixed(0)} spent',
                                style: const TextStyle(fontSize: 12, fontFamily: 'Manrope', color: Color(0xFF98A2B3)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0,
                        minHeight: 6,
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Label
                    Text(
                      isSavings ? 'How much did you save?' : 'How much did you spend?',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Manrope', color: Color(0xFF1A1F36)),
                    ),
                    const SizedBox(height: 10),

                    // Amount input
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(fontSize: 15, fontFamily: 'Manrope', color: Color(0xFF1A1F36)),
                      decoration: InputDecoration(
                        hintText: 'e.g. 700',
                        hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontFamily: 'Manrope'),
                        prefixText: '\$  ',
                        prefixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontFamily: 'Manrope'),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final val = double.tryParse(amountCtrl.text.trim());
                                if (val == null || val <= 0) return;

                                setSheetState(() => submitting = true);
                                try {
                                  final res = await ApiService.patch(
                                    '/api/goals/$goalId/add-spend',
                                    {'amount': val},
                                    context,
                                  );
                                  if (res.statusCode == 200 && mounted) {
                                    Navigator.pop(ctx);
                                    _fetchGoals();
                                  }
                                } catch (_) {
                                } finally {
                                  setSheetState(() => submitting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isSavings ? 'Add Savings' : 'Add Spend', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Manrope', color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _bgGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.savings_rounded, color: _textLight, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'No goals yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Manrope',
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Add Goal to create your first budget goal',
            style: TextStyle(fontSize: 13, color: _textLight, fontFamily: 'Manrope'),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Map<String, dynamic> goal;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  const _GoalTile({
    required this.goal,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  Color _progressColor(bool isSavings, double progress) {
    if (isSavings) {
      if (progress >= 1.0) return const Color(0xFF2ECC71);
      if (progress >= 0.5) return const Color(0xFF2ECC71);
      return const Color(0xFFE67E22);
    } else {
      if (progress >= 1.0) return const Color(0xFFE53935);
      if (progress >= 0.7) return const Color(0xFFE67E22);
      return accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double amount    = (goal['amount'] as num).toDouble();
    final double spent     = (goal['currentSpend'] as num? ?? 0).toDouble();
    final double progress  = amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
    final String name      = goal['goalName'] ?? '';
    final String duration  = _capitalize(goal['resetDuration'] ?? 'monthly');
    final bool isSavings   = (goal['goalType'] as String?) == 'savings';
    final Color barColor   = _progressColor(isSavings, progress);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E8FF), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Manrope',
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Manrope',
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Manrope',
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSavings
                            ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
                            : const Color(0xFF1E88E5).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSavings ? 'Savings' : 'Limit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Manrope',
                          color: isSavings ? const Color(0xFF2ECC71) : const Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: barColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSavings
                      ? 'PKR ${spent.toStringAsFixed(0)} saved of PKR ${amount.toStringAsFixed(0)}'
                      : 'PKR ${spent.toStringAsFixed(0)} spent of PKR ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Manrope',
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
