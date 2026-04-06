import 'package:flutter/material.dart';
import 'package:presensia/view/attendancehomepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const AttendanceHomepage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/splash_screen.png',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
                // const SizedBox(height: 28),
                // Text(
                //   'Presensia',
                //   style: theme.textTheme.headlineMedium?.copyWith(
                //     fontWeight: FontWeight.w800,
                //     color: const Color(0xFF144D43),
                //     letterSpacing: 0.6,
                //   ),
                // ),
                // const SizedBox(height: 12),
                // Text(
                //   'Absensi cepat, akurat, dan selalu terpantau.',
                //   textAlign: TextAlign.center,
                //   style: theme.textTheme.titleMedium?.copyWith(
                //     color: const Color(0xFF4D6B64),
                //     height: 1.5,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
