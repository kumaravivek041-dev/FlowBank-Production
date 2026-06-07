import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../home/section_header.dart';
import '../collaboration/members-view-row.dart';
import '../collaboration/members-entries-billsplitting.dart';
import 'package:http/http.dart' as http;
import '../collaboration/add_Entries.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../collaboration/inPage_add_members_page.dart';
import 'package:flowbank/api/api_service.dart';
import '../notification/exit_request_page.dart';
import '../notification/notification-page.dart';

/// --------------------
/// Member Model
/// --------------------
class Member {
  final String name;
  final String email;
  final String role;
  final double totalAmount;
  final double paidAmount;

  Member({
    required this.name,
    required this.email,
    required this.role,
    required this.totalAmount,
    required this.paidAmount,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'member',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// --------------------
/// Collaboration Screen
/// --------------------
class BillSplitting extends StatefulWidget {
  final String dashboardId;

  const BillSplitting({
    super.key,
    required this.dashboardId,
  });

  @override
  State<BillSplitting> createState() => _BillSplittingState();
}

class _BillSplittingState extends State<BillSplitting> {
  bool _pageLoading = true;
  int _selectedIndex = 1;
  String _userInitials = 'U';
  bool _isExpanded = false;
  String? ownerEmail;
  double? totalAmount;
  bool isLoadingTotal = true;
  String currency = "USD"; // default
  String? userEmail;
  List<Member> members = [];

  List<EntryItem> entries = [];
  bool isLoadingEntries = true;

  bool hasExitRequests = false;
  bool isCheckingExitRequests = true;



  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    
  setState(() => _pageLoading = true);

  await _loadUserEmail();
  await _fetchDashboardCurrency();
  await _fetchOwnerEmail();
  await _checkExitRequests();
  await _fetchBillSplitTotal();
  await _fetchEntries();
  await _fetchMembersAndSplit();
    
    
    
if (!mounted) return;
  setState(() => _pageLoading = false);
    

  
}

  
  Map<String, double> _calculatePaidAmountsFromEntries() {
  final Map<String, double> paidMap = {};

  for (final entry in entries) {
    final userName = entry.title; // this is userName (email/name mapping already done)
    paidMap[userName] = (paidMap[userName] ?? 0) + entry.amount;
  }

  return paidMap;
}


  Future<void> _fetchEntries() async {
  try {
    final response = await ApiService.get(
  "/api/collab/dashboard-entries?dashboardId=${widget.dashboardId}",
  context
);


    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      setState(() {
        entries = data.map((e) {
          return EntryItem(
            entryId: e["_id"],
            title: e["userName"], // email for now
            subtitle: e["status"] ?? "pending",
            date: e["createdAt"] != null
                ? e["createdAt"].toString().substring(0, 10)
                : "",
            amount: (e["amount"] as num).toDouble(),
            // totalAmount: (e["amount"] as num).toDouble(),
          );
        }).toList();

        isLoadingEntries = false;
      });
    } else {
      isLoadingEntries = false;
    }
  } catch (e) {
    debugPrint("Failed to fetch entries: $e");
    isLoadingEntries = false;
  }

//   if (!isLoadingTotal) {
//   await _fetchMembersAndSplit();
// }

}


    Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'user';
      _userInitials = prefs.getString('userInitials') ?? 'U';
    });
  }

  /// Fetch total amount
  Future<void> _fetchBillSplitTotal() async {
    try {
      final response = await ApiService.get(
  "/api/collab/bill-split-total?dashboardId=${widget.dashboardId}",
  context
);


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          totalAmount = (decoded["totalAmount"] as num).toDouble();
          isLoadingTotal = false;
        });

        // Fetch members & calculate split
        // await _fetchMembersAndSplit();
      } else {
        setState(() => isLoadingTotal = false);
      }
    } catch (e) {
      debugPrint("Failed to fetch bill split total: $e");
      setState(() => isLoadingTotal = false);
    }
  }

  /// Fetch members and calculate split
  Future<void> _fetchMembersAndSplit() async {
  try {
    // 1️⃣ Fetch Dashboard Members
    final membersResponse = await ApiService.get(
  "/api/collab/dashboard-members-by-dashboard?dashboardId=${widget.dashboardId}",
  context
);


    if (membersResponse.statusCode != 200) return;

    final membersData = jsonDecode(membersResponse.body) as List;
    if (membersData.isEmpty) return;

    // 2️⃣ Extract emails
    final emails = membersData.map((m) => m['userId']).toList();

    // 3️⃣ Fetch users by emails to get names
    final usersResponse = await ApiService.post(
  "/api/collab/users-by-emails",
  {"emails": emails},
  context
);


    if (usersResponse.statusCode != 200) return;

    final usersData = jsonDecode(usersResponse.body) as List;

    // Map email -> name
    final userMap = {for (var u in usersData) u['email']: u['name']};

    // 4️⃣ Calculate split amount
    if (totalAmount == null) return;
    final memberCount = membersData.length;
    final splitAmount = totalAmount! / memberCount;

    // 5️⃣ Map members with names and split
final paidMap = _calculatePaidAmountsFromEntries();

List<Member> tempMembers = membersData.map((m) {
  final email = m['userId'];
  final role = m['role'] ?? 'member';
  final name = userMap[email] ?? email;

  double paidAmount;

  if (role == 'owner') {
    // 🔒 Owner always fully paid
    paidAmount = splitAmount;
  } else {
    // 🔢 Sum of all entries made by this user
    paidAmount = paidMap[name] ?? 0.0;
  }

  return Member(
    name: name,
    email: email,
    role: role,
    totalAmount: splitAmount,
    paidAmount: paidAmount,
  );
}).toList();


    setState(() {
      members = tempMembers;
    });
  } catch (e) {
    debugPrint("Failed to fetch members and split: $e");
  }
}

Future<void> _fetchDashboardCurrency() async {
  try {
    final response = await ApiService.post(
  "/api/collab/dashboards-by-ids",
  {
    "ids": [widget.dashboardId],
  },
  context
);


    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List;

      if (decoded.isNotEmpty) {
        setState(() {
          currency = decoded[0]["currency"] ?? "USD";
        });
      }
    }
  } catch (e) {
    debugPrint("Failed to fetch dashboard currency: $e");
  }
}

 Future<void> _fetchOwnerEmail() async {
    try {
      final response = await ApiService.get(
  "/api/collab/dashboard/${widget.dashboardId}",
  context
);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          ownerEmail = data['ownerId']; // 🔥 ownerId comes from your MongoDB schema
        });
      } else {
        debugPrint("Failed to fetch owner: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching owner email: $e");
    }
  }

  Future<void> _checkExitRequests() async {
  if (ownerEmail == null || userEmail != ownerEmail) {
    setState(() {
      hasExitRequests = false;
      isCheckingExitRequests = false;
    });
    return;
  }

  try {
    final response = await ApiService.get(
      "/api/collab/exit-requests-by-dashboard?dashboardId=${widget.dashboardId}",
      context,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      setState(() {
        hasExitRequests = decoded["hasExitRequests"] == true;
        isCheckingExitRequests = false;
      });
    } else {
      isCheckingExitRequests = false;
    }
  } catch (e) {
    debugPrint("Failed to check exit requests: $e");
    isCheckingExitRequests = false;
  }
}




  final Color activeColor = const Color(0xFF217BFF);
  final Color inactiveColor = const Color(0xFF667085);

Widget _loadingScreen() {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Colors.blue.shade100,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF217BFF)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Loading content",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF217BFF),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
  //   if (_pageLoading) {
  //   return _loadingScreen();
  // }
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,

        /// Floating Button
        floatingActionButton: Padding(
  padding: EdgeInsets.only(bottom: 80 + bottomInset),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [

      /// -------- Add Entries Button --------
AnimatedOpacity(
  opacity: _isExpanded ? 1 : 0,
  duration: const Duration(milliseconds: 300),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: _isExpanded ? 48 : 38,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF217BFF).withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
  heroTag: "add_entries",
  backgroundColor: (ownerEmail != null && ownerEmail == userEmail)
      ? Colors.grey.shade400 // lighter grey for disabled
      : const Color(0xFF217BFF),
  elevation: 0,
  onPressed: (ownerEmail != null && ownerEmail == userEmail)
      ? null // disables the button
      : () {
          setState(() => _isExpanded = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEntriesPage(
                dashboardId: widget.dashboardId,
              ),
            ),
          );
        },
  label: Text(
    "Add Entries",
    style: TextStyle(
      color: (ownerEmail != null && ownerEmail == userEmail)
          ? const Color.fromARGB(255, 255, 255, 255).withOpacity(1.0) // reduced opacity
          : Colors.white,
      fontWeight: FontWeight.w700,
    ),
  ),
  icon: Icon(
    Icons.receipt_long,
    color: (ownerEmail != null && ownerEmail == userEmail)
        ? Colors.white.withOpacity(1.0) // reduced opacity
        : Colors.white,
  ),
),

    ),
  ),
),


      const SizedBox(height: 12),

      /// -------- Add Members Button --------
AnimatedOpacity(
  opacity: _isExpanded ? 1 : 0,
  duration: const Duration(milliseconds: 200),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: _isExpanded ? 48 : 38,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF217BFF).withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: "add_members",
        backgroundColor: const Color(0xFF217BFF),
        elevation: 0,
onPressed: (ownerEmail != null && ownerEmail == userEmail)
    ? () {
        setState(() => _isExpanded = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InpageAddMembersPage(
              dashboardId: widget.dashboardId,
            ),
          ),
        );
      }
    : null,

        label: const Text(
          "Add Members",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(
          Icons.person_add,
          color: Colors.white,
        ),
      ),
    ),
  ),
),


      const SizedBox(height: 16),

      /// -------- Main FAB --------
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF217BFF).withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF217BFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Icon(
            _isExpanded ? Icons.close : Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    ],
  ),
),
floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,

        /// App Bar
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            flexibleSpace: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 26, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Bill Splitting",
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Manrope",
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              "CollaBorations",
                              style: TextStyle(
                                color: Color(0xFF0179FE),
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5FAFF),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _userInitials,
                              style: const TextStyle(
                                color: Color(0xFF0179FE),
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
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

        /// Body
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 187,
                  decoration: BoxDecoration(
                    color: Color(0xFF4893FF),
                    borderRadius: BorderRadius.circular(27),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isCheckingExitRequests &&
    hasExitRequests &&
    ownerEmail == userEmail)
  Column(
    children: [
      
      InkWell(
  borderRadius: BorderRadius.circular(26),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExitRequestPage(dashboardId: widget.dashboardId),
      ),
    );
  },
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 2.0,
      ),
      child: Text(
        "View Exit Requests",
        style: TextStyle(
          color: Color(0xFF4893FF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ),
),

      const SizedBox(height: 10),
    ],
  ),

                      Text(
                        "Total Amount to Split",
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontFamily: "Manrope",
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      Text(
                        isLoadingTotal
                            ? "—"
                            : currency == "USD"
    ? "\$${totalAmount?.toStringAsFixed(2) ?? "0.00"}"  // for GPT: the total amount should be the total of all the approved entries
    : "${currency} ${totalAmount?.toStringAsFixed(2) ?? "0.00"}",
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontFamily: "Manrope",
                          fontSize: 37,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Split between ${members.length} group members",
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontFamily: "Manrope",
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 27),

                /// Group Members
                SectionHeader(
                  title: "Group Members",
                  showButton: true,
                ),
                const SizedBox(height: 16),
                MembersViewRow(
                  members: members
                      .map((m) => {
                            'name': m.name,
                            'email': m.email,
                            'role': m.role,
                            'totalAmount': m.totalAmount,
                            'paidAmount': m.paidAmount,
                          })
                      .toList(),
                ),
                const SizedBox(height: 24),

                /// All Entries
                SectionHeader(
                  title: "All Entries",
                  showButton: true,
                ),
                const SizedBox(height: 16),
                EntriesEntryList(entries: entries),

              ],
            ),
          ),
        ),

        /// Bottom Navigation
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 70 + bottomInset.clamp(0, 40),
              color: Colors.white.withOpacity(0.6),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: activeColor,
                unselectedItemColor: inactiveColor,
                onTap: (index) {
                  if (index == 0) {
                    Navigator.popUntil(context, (r) => r.isFirst);
                  } else if (index == 2) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage()));
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
    );
  }
}
