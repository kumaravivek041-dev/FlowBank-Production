import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../collaboration/collaboration_screen.dart';
import 'package:flowbank/api/api_service.dart';

class BillSplittingAmountPage extends StatefulWidget {
  final String dashboardId;
  final String currency;

  const BillSplittingAmountPage({
    super.key,
    required this.dashboardId,
    required this.currency,
  });

  @override
  State<BillSplittingAmountPage> createState() =>
      _BillSplittingAmountPageState();
}

class _BillSplittingAmountPageState extends State<BillSplittingAmountPage> {
  final TextEditingController _amountController = TextEditingController();
  bool isLoading = false;

  bool get isButtonEnabled =>
      _amountController.text.isNotEmpty &&
      double.tryParse(_amountController.text) != null;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
  final amount = double.parse(_amountController.text);

  setState(() => isLoading = true);

  try {
    final response = await ApiService.post(
      "/api/collab/set-bill-split-total",
      {"dashboardId": widget.dashboardId,
        "totalAmount": amount,},
        context
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Splitting amount set successfully"),
        ),
      );

      // ✅ NAVIGATE TO COLLABORATION PAGE
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const CollaborationScreen(),
        ),
        (route) => false, // removes all previous screens
      );
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded["message"] ?? "Failed");
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  } finally {
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: const Text(
          'Set Splitting Amount',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF217BFF),
            fontSize: 26,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Text(
                  "Before You Continue",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "To ensure fair and transparent bill splitting, you need to "
                  "define a base amount beforehand. This amount will be used "
                  "as the foundation for all bill calculations within this group.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFFC107),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF9800),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "This is a one-time setup.\n\n"
                          "Once you enter and confirm this amount, it cannot be "
                          "changed in the future on the bill splitting page. "
                          "Please double-check the value before continuing.",
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  "Splitting Amount",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color.fromARGB(154, 33, 122, 255),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: "e.g. 2500",
                      prefixIcon: widget.currency == "USD"
    ? const Icon(
        Icons.attach_money_rounded,
        color: Color(0xFF217BFF),
      )
    : const SizedBox(
        width: 56, // same visual width as an icon
        child: Center(
          child: Text(
            "\$",
            style: TextStyle(
              color: Color(0xFF217BFF),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),

                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isButtonEnabled && !isLoading ? _continue : null,
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
                : Text(
                    "Confirm & Continue",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isButtonEnabled
                          ? Colors.white
                          : const Color(0xFF217BFF),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
