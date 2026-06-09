import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/onboarding/OnboardingScreen.dart';
import 'screens/home/new_homescreen.dart';
//import 'package:device_preview/device_preview.dart';
import 'screens/collaboration/delete_Group.dart';
import 'screens/connectBank/connect_bank_screen.dart';

class _MouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://e0a1696c3250f1f6cc2ad07f0197e045@o4511531821760512.ingest.us.sentry.io/4511531824840704';
      options.tracesSampleRate = 1.0;
      options.environment = 'production';
    },
    appRunner: () async {
      await Sentry.captureException(Exception('Test: Sentry is working in FlowBank'));
      WidgetsFlutterBinding.ensureInitialized();
      // Hide bottom nav bar (back/home/recents), keep status bar
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
      runApp(
          //   DevicePreview(
          // enabled: true,
          // builder: (context) => const MyApp(),
          // )
          const MyApp()
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowBank',
      theme: ThemeData(fontFamily: 'Manrope', useMaterial3: true),
      scrollBehavior: _MouseScrollBehavior(),
            //locale: DevicePreview.locale(context),
      //builder: DevicePreview.appBuilder,

      home: const _AuthGate(),

      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => token != null && token.isNotEmpty
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Blank white screen while checking auth
    return const Scaffold(backgroundColor: Colors.white);
  }
}
