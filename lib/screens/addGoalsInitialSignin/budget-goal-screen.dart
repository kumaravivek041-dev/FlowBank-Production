import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowbank/api/api_service.dart';
import '../home/new_homescreen.dart';

// ─── Category model ───────────────────────────────────────────────────────────
class _Category {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _Category({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_Category> _categories = [
  _Category(id: 'food',          label: 'Food & Dining',    icon: Icons.restaurant_rounded,        color: Color(0xFFFF6B6B)),
  _Category(id: 'home',          label: 'Home',             icon: Icons.home_rounded,               color: Color(0xFF4ECDC4)),
  _Category(id: 'subscriptions', label: 'Subscriptions',    icon: Icons.subscriptions_rounded,      color: Color(0xFF9B59B6)),
  _Category(id: 'transport',     label: 'Transport',        icon: Icons.directions_car_rounded,     color: Color(0xFF3498DB)),
  _Category(id: 'shopping',      label: 'Shopping',         icon: Icons.shopping_bag_rounded,       color: Color(0xFFE67E22)),
  _Category(id: 'health',        label: 'Health',           icon: Icons.favorite_rounded,           color: Color(0xFF2ECC71)),
  _Category(id: 'education',     label: 'Education',        icon: Icons.school_rounded,             color: Color(0xFF1E88E5)),
  _Category(id: 'entertainment', label: 'Entertainment',    icon: Icons.movie_rounded,              color: Color(0xFFF39C12)),
  _Category(id: 'other',         label: 'Other',            icon: Icons.more_horiz_rounded,         color: Color(0xFF95A5A6)),
];

// ─── Duration model ───────────────────────────────────────────────────────────
class _Duration {
  final String id;
  final String label;
  final String sublabel;
  final IconData icon;

  const _Duration({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.icon,
  });
}

const List<_Duration> _durations = [
  _Duration(id: 'weekly',   label: 'Weekly',   sublabel: 'Resets every 7 days',   icon: Icons.view_week_rounded),
  _Duration(id: 'monthly',  label: 'Monthly',  sublabel: 'Resets every month',    icon: Icons.calendar_month_rounded),
  _Duration(id: 'yearly',   label: 'Yearly',   sublabel: 'Resets every year',     icon: Icons.event_repeat_rounded),
];

// ─── Main Screen ──────────────────────────────────────────────────────────────
class BudgetGoalScreen extends StatefulWidget {
  final VoidCallback? onGoalAdded;
  const BudgetGoalScreen({super.key, this.onGoalAdded});

  @override
  State<BudgetGoalScreen> createState() => _BudgetGoalScreenState();
}

class _BudgetGoalScreenState extends State<BudgetGoalScreen>
    with TickerProviderStateMixin {

  final PageController _pageController = PageController();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  int _currentPage = 0;
  String? _selectedGoalType;   // 'spending' or 'savings'
  String? _selectedCategory;
  String? _selectedDuration;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _blue      = Color(0xFF1E88E5);
  static const _green     = Color(0xFF2ECC71);
  static const _textGrey  = Color(0xFF475467);
  static const _borderGrey = Color(0xFFCCD0D7);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _goalNameController.dispose();
    _amountController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────
  void _nextPage() {
    if (_currentPage < 3) {
      _fadeController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
      _fadeController.forward();
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _fadeController.reset();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
      _fadeController.forward();
    }
  }

  // ─── Validation ─────────────────────────────────────────────────────────────
  bool get _canProceed {
    switch (_currentPage) {
      case 0: return _selectedGoalType != null;
      case 1:
        final amount = double.tryParse(_amountController.text.trim());
        return _goalNameController.text.trim().isNotEmpty &&
            amount != null && amount > 0;
      case 2: return _selectedDuration != null;
      case 3: return _selectedCategory != null;
      default: return false;
    }
  }

  // ─── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) {
        _showError('User not found. Please log in again.');
        return;
      }
      final response = await ApiService.post(
        '/api/goals/goal-set',
        {
          'userId':    userId,
          'goalName':  _goalNameController.text.trim(),
          'amount':    double.parse(_amountController.text.trim()),
          'resetDuration': _selectedDuration,
          'category':  _selectedCategory,
          'goalType':  _selectedGoalType,
        },
        context,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSuccess();
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Failed to save goal.');
      }
    } catch (e) {
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess() {
    final isSavings = _selectedGoalType == 'savings';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF2ECC71), size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'Goal Created!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                isSavings
                    ? 'Your savings goal has been saved. Log your savings to track progress.'
                    : 'Your spending limit has been saved. We\'ll track your spending against it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: _textGrey, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onGoalAdded != null) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      widget.onGoalAdded!();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black, size: 20),
                onPressed: _prevPage,
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.black, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
        title: _StepIndicator(current: _currentPage, total: 4),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _Page0GoalType(
                  selected: _selectedGoalType,
                  fadeAnim: _fadeAnim,
                  onSelect: (type) => setState(() => _selectedGoalType = type),
                ),
                _Page1Goal(
                  nameController: _goalNameController,
                  amountController: _amountController,
                  fadeAnim: _fadeAnim,
                  goalType: _selectedGoalType,
                  onChanged: () => setState(() {}),
                ),
                _Page2Duration(
                  selected: _selectedDuration,
                  fadeAnim: _fadeAnim,
                  onSelect: (id) => setState(() => _selectedDuration = id),
                ),
                _Page3Category(
                  selected: _selectedCategory,
                  fadeAnim: _fadeAnim,
                  onSelect: (id) => setState(() => _selectedCategory = id),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _canProceed && !_isLoading ? _nextPage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPage == 0 && _selectedGoalType == 'savings' ? _green : _blue,
                  disabledBackgroundColor: _borderGrey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _currentPage < 3 ? 'Continue' : 'Create Goal',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isDone   = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDone || isActive ? const Color(0xFF1E88E5) : const Color(0xFFCCD0D7),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Page 0: Goal Type ────────────────────────────────────────────────────────
class _Page0GoalType extends StatelessWidget {
  final String? selected;
  final Animation<double> fadeAnim;
  final void Function(String) onSelect;

  const _Page0GoalType({
    required this.selected,
    required this.fadeAnim,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.track_changes_rounded, color: Color(0xFF1E88E5), size: 28),
            ),
            const SizedBox(height: 20),
            const Text(
              'What kind of goal?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you want to track this goal.',
              style: TextStyle(fontSize: 15.5, color: Color(0xFF667085), height: 1.5),
            ),
            const SizedBox(height: 36),

            _GoalTypeCard(
              id: 'spending',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF1E88E5),
              title: 'Spending Limit',
              description: 'Set a maximum you don\'t want to exceed. Going over means you\'ve overspent.',
              selected: selected == 'spending',
              onTap: () => onSelect('spending'),
            ),
            const SizedBox(height: 14),
            _GoalTypeCard(
              id: 'savings',
              icon: Icons.savings_rounded,
              color: const Color(0xFF2ECC71),
              title: 'Savings Target',
              description: 'Set an amount you want to save. Falling short means you need to save more.',
              selected: selected == 'savings',
              onTap: () => onSelect('savings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTypeCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTypeCard({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : const Color(0xFFE4E7EC),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF667085), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : const Color(0xFFD0D5DD),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Goal Name + Amount ───────────────────────────────────────────────
class _Page1Goal extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final Animation<double> fadeAnim;
  final String? goalType;
  final VoidCallback onChanged;

  const _Page1Goal({
    required this.nameController,
    required this.amountController,
    required this.fadeAnim,
    required this.goalType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSavings = goalType == 'savings';
    return FadeTransition(
      opacity: fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.flag_rounded, color: Color(0xFF1E88E5), size: 28),
            ),
            const SizedBox(height: 20),
            const Text(
              'Set your goal',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              isSavings
                  ? 'Give your savings goal a name and set a target amount.'
                  : 'Give your budget a name and set a spending limit.',
              style: const TextStyle(fontSize: 15.5, color: Color(0xFF667085), height: 1.5),
            ),
            const SizedBox(height: 36),

            const Text('Goal name',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF344054), letterSpacing: 0.1)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDec(
                hint: isSavings ? 'e.g. Emergency Fund' : 'e.g. Monthly Groceries',
                prefix: const Icon(Icons.label_outline_rounded, color: Color(0xFF98A2B3), size: 20),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              isSavings ? 'Savings target (PKR)' : 'Budget limit (PKR)',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF344054), letterSpacing: 0.1),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5), letterSpacing: -0.5),
              decoration: _inputDec(
                hint: '0',
                prefix: const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('PKR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF98A2B3))),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Quick select',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF98A2B3), fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['1,000', '2,500', '5,000', '10,000', '25,000'].map((v) {
                final numVal = v.replaceAll(',', '');
                return GestureDetector(
                  onTap: () { amountController.text = numVal; onChanged(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBDD7FF), width: 1),
                    ),
                    child: Text('PKR $v',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5))),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: Duration ─────────────────────────────────────────────────────────
class _Page2Duration extends StatelessWidget {
  final String? selected;
  final Animation<double> fadeAnim;
  final void Function(String) onSelect;

  const _Page2Duration({required this.selected, required this.fadeAnim, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.repeat_rounded, color: Color(0xFF9B59B6), size: 28),
            ),
            const SizedBox(height: 20),
            const Text('Reset period',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('How often should your progress reset to zero?',
                style: TextStyle(fontSize: 15.5, color: Color(0xFF667085), height: 1.5)),
            const SizedBox(height: 36),
            ..._durations.map((d) {
              final isSelected = selected == d.id;
              return GestureDetector(
                onTap: () => onSelect(d.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E88E5).withValues(alpha: 0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFFE4E7EC),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E88E5).withValues(alpha: 0.12) : const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(d.icon,
                            color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF667085), size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.label,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFF1E88E5) : Colors.black)),
                            const SizedBox(height: 2),
                            Text(d.sublabel, style: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3))),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFFD0D5DD),
                            width: 2,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Page 3: Category ─────────────────────────────────────────────────────────
class _Page3Category extends StatelessWidget {
  final String? selected;
  final Animation<double> fadeAnim;
  final void Function(String) onSelect;

  const _Page3Category({required this.selected, required this.fadeAnim, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.category_rounded, color: Color(0xFFFF6B6B), size: 28),
            ),
            const SizedBox(height: 20),
            const Text('Pick a category',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('Which area does this goal cover?',
                style: TextStyle(fontSize: 15.5, color: Color(0xFF667085), height: 1.5)),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
              ),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isSelected = selected == cat.id;
                return GestureDetector(
                  onTap: () => onSelect(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? cat.color.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? cat.color : const Color(0xFFE4E7EC),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: isSelected ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? cat.color : const Color(0xFF344054),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared input decoration ──────────────────────────────────────────────────
InputDecoration _inputDec({required String hint, Widget? prefix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD0D5DD), fontSize: 15),
    prefixIcon: prefix != null
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: prefix)
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCCD0D7), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
    ),
  );
}
