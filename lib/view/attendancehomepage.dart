import 'package:flutter/material.dart';
import 'package:presensia/view/registrasion_page.dart';

class AttendanceHomepage extends StatelessWidget {
  const AttendanceHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE8FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '#SmartAttendance',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF246BDB),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selamat Datang di',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF1A1D29),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Presensia',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF246BDB),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mencatat kehadiran jadi lebih mudah,\nakurat, dan transparan dalam satu\ngenggaman.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.gps_fixed_rounded,
                          iconColor: Color(0xFF246BDB),
                          label: 'Presisi GPS',
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.shield_rounded,
                          iconColor: Color(0xFF15803D),
                          label: 'Data Aman',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF222531),
                        side: const BorderSide(
                          color: Color(0xFFA9C7FF),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _GoogleLogoBadge(),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF222531),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xFFE5EAF4), thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF7B8194),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Color(0xFFE5EAF4), thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => const RegistrasionPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4753E8),
                        foregroundColor: Colors.white,
                        elevation: 7,
                        shadowColor: const Color(0x334753E8),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Daftar dengan Email',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                      children: const [
                        TextSpan(text: 'Sudah punya akun? '),
                        TextSpan(
                          text: 'Masuk',
                          style: TextStyle(
                            color: Color(0xFF246BDB),
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _GoogleLogoBadge extends StatelessWidget {
  const _GoogleLogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
          children: [
            TextSpan(
              text: 'G',
              style: TextStyle(color: Color(0xFF4285F4)),
            ),
            TextSpan(
              text: '·',
              style: TextStyle(color: Color(0xFFEA4335)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFF1A1D29),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
