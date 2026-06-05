import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import '../authentication/signup_modal.dart';
import '../authentication/login_modal.dart';
import '../authentication/notification.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  int currentIndex = 0;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sh = MediaQuery.of(context).size.height;
    final double sw = MediaQuery.of(context).size.width;

    // Scale fonts based on screen width — clamp so they don't get tiny or huge
    final double titleFontSize = (sw * 0.108).clamp(26.0, 46.0);
    final double descFontSize  = (sw * 0.044).clamp(12.0, 18.0);

    final bool isLastSlide = currentIndex == onboardingData.length - 1;
    final Color activeColor   = isLastSlide ? const Color(0xFFB968F6) : const Color(0xFF1E88E5);
    final Color inactiveColor = isLastSlide ? const Color.fromARGB(255, 221, 186, 247) : const Color(0xFFBBDEFB);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: sh * 0.09,
            right: -50,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: CurvePainter(),
            ),
          ),
          Positioned(
            bottom: sh * 0.17,
            left: -80,
            child: CustomPaint(
              size: const Size(300, 300),
              painter: WavePainter(),
            ),
          ),

          // SafeArea keeps content away from status bar and nav bar insets
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: sh * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image — original size, not constrained
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Image.asset(
                        onboardingData[currentIndex]["image"]!,
                        key: ValueKey<String>(onboardingData[currentIndex]["image"]!),
                      ),
                    ),

                    SizedBox(height: sh * 0.012),

                    // Logo row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text(
                                '◆',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'FlowBank',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: sh * 0.022),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            onboardingData[currentIndex]["title1"]!,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: sh * 0.005),
                          Text(
                            onboardingData[currentIndex]["title2"]!,
                            style: TextStyle(
                              color: activeColor,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: sh * 0.016),
                          Text(
                            onboardingData[currentIndex]["desc"]!,
                            style: TextStyle(
                              color: const Color(0xFF424242),
                              fontSize: descFontSize,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                              letterSpacing: 0.25,
                            ),
                          ),
                          SizedBox(height: sh * 0.02),

                          // Progress dots
                          Row(
                            children: List.generate(onboardingData.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(right: 8),
                                width: currentIndex == index ? 36 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: currentIndex == index ? activeColor : inactiveColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: sh * 0.03),

                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                if (currentIndex < onboardingData.length - 1) {
                                  setState(() => currentIndex++);
                                } else {
                                  showSignUpBottomSheet(context, onMessage: (msg) {
                                    showCustomNotification(context, msg);
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isLastSlide ? "Get Started" : "Next",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              if (isLastSlide) {
                                showLoginBottomSheet(context, onMessage: (msg) {
                                  showCustomNotification(context, msg);
                                });
                              } else {
                                setState(() => currentIndex = onboardingData.length - 1);
                              }
                            },
                            child: Text(
                              isLastSlide ? "Already have an account?" : "Skip",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.3,
      size.width * 0.2, size.height,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.3,
      size.width * 0.5, size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.7,
      size.width, size.height * 0.5,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => false;
}
