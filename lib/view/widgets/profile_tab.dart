import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presensia/services/auth_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    required this.profileData,
    required this.currentUserName,
    required this.onRefresh,
  });

  final Map<String, dynamic>? profileData;
  final String currentUserName;
  final Future<void> Function() onRefresh;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUpdatingProfile = false;
  bool _isUploadingPhoto = false;

  Map<String, dynamic>? get _profile =>
      widget.profileData?['data'] as Map<String, dynamic>?;

  String get _name {
    final profile = _profile;
    final fallbackName = widget.currentUserName.trim().isNotEmpty
        ? widget.currentUserName.trim()
        : 'Pengguna Presensia';
    if (profile == null) {
      return fallbackName;
    }
    final value = _readProfileString(profile, const ['name']);
    return value.isEmpty ? fallbackName : value;
  }

  String get _email {
    final profile = _profile;
    if (profile == null) {
      return 'email belum tersedia';
    }
    final value = _readProfileString(profile, const ['email']);
    return value.isEmpty ? 'email belum tersedia' : value;
  }

  String? get _photoUrl {
    final profile = _profile;
    if (profile == null) {
      return null;
    }
    final rawUrl = _readProfileString(profile, const [
      'profile_photo',
      'profile_photo_url',
      'photo',
      'avatar',
    ]);
    return AuthService.resolveMediaUrl(rawUrl);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEditProfileSheet() async {
    if (_isUpdatingProfile) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _EditProfilePage(
          initialName: _name,
          email: _email,
        ),
      ),
    );

    if (!mounted || result == null || result == _name) {
      return;
    }

    setState(() {
      _isUpdatingProfile = true;
    });

    final response = await AuthService.updateProfile(name: result);

    if (!mounted) return;

    setState(() {
      _isUpdatingProfile = false;
    });

    _showMessage(response.message ?? 'Proses edit profil selesai.');
    if (response.success) {
      await widget.onRefresh();
    }
  }

  Future<void> _changePhoto() async {
    if (_isUploadingPhoto) return;

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (!mounted || pickedFile == null) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    final response = await AuthService.updateProfilePhoto(
      imageFile: File(pickedFile.path),
    );

    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
    });

    _showMessage(response.message ?? 'Proses upload foto selesai.');
    if (response.success) {
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    final name = _name;
    final email = _email;
    final employeeId = _buildEmployeeId(profile);
    final department = _buildDepartment(profile);
    final roleLabel = _buildRoleLabel(profile, email);

    return Container(
      color: const Color(0xFFF7F9FF),
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: const Color(0xFF2E7BEF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF6E7691),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profil Saya',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2E7BEF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E64F0), Color(0xFF6DB5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7BEF).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  _ProfileAvatar(
                    name: name,
                    photoUrl: _photoUrl,
                    isUploading: _isUploadingPhoto,
                    onTap: _changePhoto,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isUploadingPhoto ? null : _changePhoto,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7BEF),
                    ),
                    icon: _isUploadingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(
                      _isUploadingPhoto
                          ? 'Mengunggah foto...'
                          : 'Ganti foto profil',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF20232E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    roleLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF8A90A7),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    label: 'ID KARYAWAN',
                    value: employeeId,
                    accent: const Color(0xFFEAF1FF),
                    valueColor: const Color(0xFF2D68E6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _InfoCard(
                    label: 'DEPARTEMEN',
                    value: department,
                    accent: const Color(0xFFF1F3FF),
                    valueColor: const Color(0xFF3D72EF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'PENGATURAN AKUN',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF8A90A7),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            _ActionTile(
              icon: Icons.edit_rounded,
              iconColor: const Color(0xFF2E7BEF),
              iconBackground: const Color(0xFFEAF2FF),
              title: 'Edit Profil',
              subtitle: _isUpdatingProfile ? 'Menyimpan perubahan...' : email,
              onTap: _showEditProfileSheet,
              trailing: _isUpdatingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            const _ActionTile(
              icon: Icons.history_rounded,
              iconColor: Color(0xFF7D89A9),
              iconBackground: Color(0xFFF0F3F9),
              title: 'Riwayat Absensi Lengkap',
            ),
            const SizedBox(height: 12),
            const _ActionTile(
              icon: Icons.notifications_active_rounded,
              iconColor: Color(0xFF2FA95E),
              iconBackground: Color(0xFFEAF8F0),
              title: 'Pengaturan Notifikasi',
            ),
            const SizedBox(height: 18),
            const _LogoutTile(),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'PRESENSIA V2.4.0 - BUILT FOR EXCELLENCE',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFC3C8D8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.photoUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _extractInitials(name);

    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEAF2FF), Color(0xFFF6F9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFD3E2FF), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7BEF).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _AvatarFallback(initials: initials),
                        )
                      : _AvatarFallback(initials: initials),
                ),
              ),
            ),
            if (isUploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7BEF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E64F0), Color(0xFF6DB5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color accent;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9AA2BA),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF303342),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9AA2BA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC0C6D8),
                    size: 24,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0DC)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFE0675F),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Keluar',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFE0675F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({required this.initialName, required this.email});

  final String initialName;
  final String email;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: const Color(0xFFF7F9FF),
        elevation: 0,
        foregroundColor: const Color(0xFF21242C),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E7BEF),
                        width: 1.2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) {
                      return 'Nama wajib diisi.';
                    }
                    if (name.length < 3) {
                      return 'Nama minimal 3 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.email,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      Navigator.of(context).pop(_nameController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7BEF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _buildEmployeeId(Map<String, dynamic>? profile) {
  final rawId = profile?['id']?.toString().trim();
  if (rawId != null && rawId.isNotEmpty) {
    return 'PRS-${rawId.padLeft(3, '0')}';
  }
  return 'PRS-001';
}

String _buildDepartment(Map<String, dynamic>? profile) {
  final batch = profile?['batch'];
  final training = profile?['training'];

  if (training is Map<String, dynamic>) {
    final trainingTitle = training['title']?.toString().trim();
    if (trainingTitle != null && trainingTitle.isNotEmpty) {
      return trainingTitle;
    }
  }

  if (batch is Map<String, dynamic>) {
    final batchLabel = batch['name']?.toString().trim();
    if (batchLabel != null && batchLabel.isNotEmpty) {
      return batchLabel;
    }
  }

  return 'Teknologi';
}

String _buildRoleLabel(Map<String, dynamic>? profile, String email) {
  final role = profile?['role']?.toString().trim();
  if (role != null && role.isNotEmpty) {
    return role.toUpperCase();
  }

  if (email != 'email belum tersedia') {
    return 'PESERTA AKTIF';
  }

  return 'ANGGOTA PRESENSIA';
}

String _readProfileString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  final user = source['user'];
  if (user is Map<String, dynamic>) {
    for (final key in keys) {
      final value = user[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  }

  return '';
}

String _extractInitials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'P';
  }

  final first = parts.first.characters.first.toUpperCase();
  final second = parts.length > 1
      ? parts.last.characters.first.toUpperCase()
      : '';
  return '$first$second';
}
