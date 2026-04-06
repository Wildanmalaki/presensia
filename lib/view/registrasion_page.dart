import 'package:flutter/material.dart';
import 'package:presensia/services/auth_service.dart';
import 'package:presensia/view/login_page.dart';

class RegistrasionPage extends StatefulWidget {
  const RegistrasionPage({super.key});

  @override
  State<RegistrasionPage> createState() => _RegistrasionPageState();
}

class _RegistrasionPageState extends State<RegistrasionPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _jurusanController = TextEditingController();
  final TextEditingController _jenisKelaminController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _jurusanController.dispose();
    _jenisKelaminController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final batch = _batchController.text.trim();
    final jurusan = _jurusanController.text.trim();
    final jenisKelamin = _jenisKelaminController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Nama, email, dan password wajib diisi.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Password dan konfirmasi harus sama.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.register(
      name: name,
      email: email,
      password: password,
      batch: batch.isEmpty ? null : batch,
      jurusan: jurusan.isEmpty ? null : jurusan,
      jenisKelamin: jenisKelamin.isEmpty ? null : jenisKelamin,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Registrasi berhasil.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (context) => const LoginPage()),
      );
      return;
    }

    _showMessage(result.message ?? 'Registrasi gagal.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FF),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE9F0FF), Color(0xFFF1FFF7), Color(0xFFF8FAFF)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/splash_screen.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Presensia',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF246BDB),
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buat Akun Baru',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF222531),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Silakan isi form pendaftaran.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF6D7385),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _RegistrationField(
                            controller: _nameController,
                            label: 'NAMA',
                            hintText: 'Nama Lengkap',
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 16),
                          _RegistrationField(
                            controller: _batchController,
                            label: 'BATCH',
                            hintText: 'Masukkan batch Anda',
                            icon: Icons.local_offer_rounded,
                          ),
                          const SizedBox(height: 16),
                          _RegistrationField(
                            controller: _jurusanController,
                            label: 'JURUSAN',
                            hintText: 'Masukkan jurusan Anda',
                            icon: Icons.local_offer_rounded,
                          ),
                          const SizedBox(height: 16),
                          _RegistrationField(
                            controller: _jenisKelaminController,
                            label: 'JENIS KELAMIN',
                            hintText: 'Masukkan jenis kelamin Anda',
                            icon: Icons.local_offer_rounded,
                          ),
                          _RegistrationField(
                            controller: _emailController,
                            label: 'EMAIL',
                            hintText: 'email@gmail.com',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _RegistrationField(
                            controller: _passwordController,
                            label: 'PASSWORD',
                            hintText: '••••••••',
                            icon: Icons.lock_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          _RegistrationField(
                            controller: _confirmPasswordController,
                            label: 'CONFIRM PASSWORD',
                            hintText: '••••••••',
                            icon: Icons.verified_user_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),

                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _register,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF222531),
                                side: const BorderSide(
                                  color: Color(0xFFA9C7FF),
                                  width: 1.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color.fromARGB(255, 82, 109, 216),
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // const _GoogleLogoBadge(),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Daftar Akun',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: const Color.fromARGB(
                                                  255,
                                                  82,
                                                  109,
                                                  216,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          //
                          // const SizedBox(height: 18),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF6D7385),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF246BDB),
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Masuk',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF246BDB),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _RegistrationField extends StatelessWidget {
  const _RegistrationField({
    this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFF6D7385),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF8A91A6),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF7D8498), size: 20),
            filled: true,
            fillColor: const Color(0xFFF2F3FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF246BDB),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
