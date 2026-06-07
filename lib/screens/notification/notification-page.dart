import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import '../notification/notification-outlook.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowbank/api/api_service.dart';
import '../home/profile.dart';
import '../collaboration/collaboration_screen.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? userEmail;
  String _userInitials = 'U';

  List notifications = [];
  bool _pageLoading = false;

  static const int _selectedIndex = 2;
  static const Color _activeColor = Color(0xFF217BFF);
  static const Color _inactiveColor = Color(0xFF667085);

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      userEmail = prefs.getString('userEmail');
      _userInitials = prefs.getString('userInitials') ?? 'U';
      _pageLoading = true;
    });
    
    if (userEmail != null) {
      await fetchNotifications(userEmail!);
    }

    if (!mounted) return;

  setState(() {
    _pageLoading = false;
  }); 
  }

  Future<void> fetchNotifications(String userEmail) async {
    try {
      final response = await ApiService.get(
        "/api/notifications/$userEmail",
        context
      );

      if (response.statusCode == 200) {
        setState(() {
          notifications = json.decode(response.body);
        });
      } else {
        print("Failed to fetch notifications: ${response.body}");
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }
  }

  Widget _loadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/money-loading.json', width: 150, height: 150),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Colors.blue.shade100,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF217BFF)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
}

  @override
  Widget build(BuildContext context) {

    if (_pageLoading) {
    return _loadingScreen();
  }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
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
            padding: const EdgeInsets.only(
              left: 18,
              right: 26,
              bottom: 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Notifications",
                      style: TextStyle(
                        color: Color(0xFF0179FE),
                        fontSize: 28,
                        fontFamily: "Manrope",
                        fontWeight: FontWeight.w700,
                      ),
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
                        child: Container(
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
  ),
),


      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
        child: notifications.isEmpty
            ? Center(
                child: Text(
                  "You will see your notifications here",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return NotificationOutlook(
                    titleText: n['title'] ?? 'No Title',
                    badgeText: n['type'] ?? '',
                    bodyText: n['body'] ?? '',
                  );
                },
              ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            backgroundColor: Colors.white.withOpacity(0.6),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _activeColor,
            unselectedItemColor: _inactiveColor,
            onTap: (index) {
              if (index == 0) {
                Navigator.popUntil(context, (route) => route.isFirst);
              } else if (index == 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CollaborationScreen()),
                );
              }
              // index == 2: already here
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
    );
  }
}
