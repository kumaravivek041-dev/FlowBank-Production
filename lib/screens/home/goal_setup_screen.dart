import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool loading = false;
  String? error;

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userId");
  }

  Future<void> saveGoal() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final userId = await _getUserId();
      if (userId == null) {
        throw Exception("User not logged in (userId missing).");
      }

      final title = _titleCtrl.text.trim();
      final amount = double.tryParse(_amountCtrl.text.trim());

      if (title.isEmpty) throw Exception("Please enter a goal name.");
      if (amount == null || amount <= 0) {
        throw Exception("Enter a valid dollar amount.");
      }

      final uri = Uri.parse("http://127.0.0.1:8000/goals");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "title": title,
          "target_amount": amount,
          "currency": "USD",
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to save goal: ${res.body}");
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonEnabled =
        _titleCtrl.text.trim().isNotEmpty && _amountCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Center(
          child: Text(
            'Set a Goal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF217BFF),
              fontSize: 26,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),

              // Premium info banner (matching Create Group vibe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color.fromARGB(154, 33, 122, 255),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFD1E9FF),
                      child: Icon(Icons.flag_rounded, color: Color(0xFF217BFF)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Add a goal and we’ll estimate when you’ll reach it based on your income & spending.",
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Goal Name",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(154, 33, 122, 255),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: "e.g. New iPhone, Emergency Fund",
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF217BFF),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Target Amount (\$)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(154, 33, 122, 255),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "e.g. 50000",
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF217BFF),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 12),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const Spacer(),
            ],
          ),
        ),
      ),

      // Bottom CTA (matching Create Group)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: (loading || !isButtonEnabled) ? null : saveGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled
                  ? const Color(0xFF217BFF)
                  : Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Save Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isButtonEnabled
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : const Color(0xFF217BFF),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
