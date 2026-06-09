import 'dart:convert';
import 'package:flowbank/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// import '../collaboration/add_members_page.dart';
import '../collaboration/add_members_page.dart';

enum GroupType { billSplitting, sharedExpenses, ledgerTracking }

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  GroupType? _selectedType;
  String _selectedCurrency = "USD";
  bool? _hasVerificationSource;
  String? userEmail;
  String? userName;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'user';
    });
  }

  // Future<void> _loadUserName() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     userName = prefs.getString('userName') ?? 'user';
  //   });
  // }

  String _mapGroupType(GroupType type) {
    switch (type) {
      case GroupType.billSplitting:
        return "Bill Splitting";
      case GroupType.sharedExpenses:
        return "Shared Expense";
      case GroupType.ledgerTracking:
        return "Ledger Tracking";
    }
  }

  Future<void> _createGroup() async {
    if (userEmail == null || _selectedType == null) return;

    setState(() => isLoading = true);

    final body = {
      "name": _groupNameController.text.trim(),
      "type": _mapGroupType(_selectedType!),
      "ownerId": userEmail,
      // "ownerName": userName,
      "currency": _selectedCurrency,
      "settings": {"requireVerification": _hasVerificationSource ?? false},
    };

    try {
      final response = await ApiService.post(
        "/api/collab/create-dashboard",
        body,
        context
      );

      

      if (response.statusCode == 201) {
        print("hello");

        final decoded = jsonDecode(response.body);
        final String dashboardId = decoded["dashboard"]["_id"];

        final body2 = {
          "dashboardId": dashboardId,
          "userId": userEmail,
          // "userName": userName,
          "role": "owner",
        };

              final response2 = await ApiService.post(
              "/api/collab/add-member",
              body2,
              context
               );


      if (response2.statusCode != 201) {
  throw Exception("Failed to add creator as owner");
}

        print("hello2");

        print("STATUS CODE: ${response.statusCode}");
        print("RESPONSE BODY: ${response.body}");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group created successfully")),
        );

        final groupType = _mapGroupType(_selectedType!);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AddMembersPage(
              dashboardId: dashboardId,
              groupType: groupType,
              currency: _selectedCurrency,
              ),
          ),
        );
      } else {
        print("STATUS CODE: ${response.statusCode}");
        print("RESPONSE BODY: ${response.body}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isButtonEnabled =
        _selectedType != null && _groupNameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Center(
          child: Text(
            'Create Group',
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
              const Text(
                "Group Name",
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
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Office Expenses, Goa Trip',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.group, color: Color(0xFF217BFF)),
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
                "Currency",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CurrencyOption(
                    label: "USD",
                    isSelected: _selectedCurrency == "USD",
                    onTap: () => setState(() => _selectedCurrency = "USD"),
                  ),
                  const SizedBox(width: 12),
                  _CurrencyOption(
                    label: "USD",
                    isSelected: _selectedCurrency == "USD",
                    onTap: () => setState(() => _selectedCurrency = "USD"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Source of Verification",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _VerificationRadio(
                    label: "Yes",
                    value: true,
                    groupValue: _hasVerificationSource,
                    onChanged: (val) =>
                        setState(() => _hasVerificationSource = val),
                  ),
                  const SizedBox(width: 20),
                  _VerificationRadio(
                    label: "No",
                    value: false,
                    groupValue: _hasVerificationSource,
                    onChanged: (val) =>
                        setState(() => _hasVerificationSource = val),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Group Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _GroupTypeCard(
                        title: 'Bill Splitting',
                        subtitle: 'Split bills equally or custom',
                        icon: Icons.receipt_long_rounded,
                        isSelected: _selectedType == GroupType.billSplitting,
                        onTap: () => setState(
                          () => _selectedType = GroupType.billSplitting,
                        ),
                      ),
                      _GroupTypeCard(
                        title: 'Shared Expenses',
                        subtitle: 'Track group spending together',
                        icon: Icons.groups_rounded,
                        isSelected: _selectedType == GroupType.sharedExpenses,
                        onTap: () => setState(
                          () => _selectedType = GroupType.sharedExpenses,
                        ),
                      ),
                      _GroupTypeCard(
                        title: 'Ledger Tracking',
                        subtitle: 'Track who owes whom',
                        icon: Icons.book_rounded,
                        isSelected: _selectedType == GroupType.ledgerTracking,
                        onTap: () => setState(
                          () => _selectedType = GroupType.ledgerTracking,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _createGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled
                  ? const Color(0xFF217BFF)
                  : Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                :  Text(
                    'Create Group',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600,
                      color: isButtonEnabled
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : Color(0xFF217BFF),
                      ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Verification Radio
class _VerificationRadio extends StatelessWidget {
  final String label;
  final bool value;
  final bool? groupValue;
  final ValueChanged<bool?> onChanged;

  const _VerificationRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Radio<bool>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: const Color(0xFF217BFF),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Currency Option
class _CurrencyOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF217BFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF217BFF) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF217BFF),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Group Type Card
class _GroupTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF5FAFF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color.fromARGB(168, 33, 122, 255)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD1E9FF),
                child: Icon(icon, color: const Color(0xFF217BFF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF4F8DF7)),
            ],
          ),
        ),
      ),
    );
  }
}
