import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presensia/services/auth_service.dart';
import 'package:presensia/theme/app_theme.dart';
import 'package:presensia/view/widgets/profile/profile_view_utils.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
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
  File? _localProfilePhotoFile;
  Uint8List? _localProfilePhotoBytes;
  String? _cachedProfilePhotoUrl;
  String? _uploadedProfilePhotoUrl;
  int _photoRefreshSeed = 0;

  Map<String, dynamic>? get _profile =>
      widget.profileData?['data'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _loadCachedProfilePhoto();
  }

  Future<void> _loadCachedProfilePhoto() async {
    final cachedUrl = await AuthService.getProfilePhotoUrl();
    if (!mounted || cachedUrl == null || cachedUrl.trim().isEmpty) {
      return;
    }

    setState(() {
      _cachedProfilePhotoUrl = cachedUrl.trim();
    });
  }

  String get _name {
    final profile = _profile;
    final fallbackName = widget.currentUserName.trim().isNotEmpty
        ? widget.currentUserName.trim()
        : 'Pengguna Presensia';
    if (profile == null) {
      return fallbackName;
    }
    final value = readProfileString(profile, const ['name']);
    return value.isEmpty ? fallbackName : value;
  }

  String get _email {
    final profile = _profile;
    if (profile == null) {
      return 'email belum tersedia';
    }
    final value = readProfileString(profile, const ['email']);
    return value.isEmpty ? 'email belum tersedia' : value;
  }

  String? get _photoUrl {
    final profile = _profile;
    if (profile == null) {
      return _appendPhotoVersion(
        AuthService.resolveMediaUrl(_cachedProfilePhotoUrl),
      );
    }
    final directUrl = readProfileString(profile, const [
      'profile_photo',
      'profile_photo_url',
      'photo',
      'avatar',
    ]);
    String rawUrl = directUrl;
    final user = profile['user'];
    if (rawUrl.isEmpty && user is Map<String, dynamic>) {
      rawUrl = readProfileString(user, const [
        'profile_photo',
        'profile_photo_url',
        'photo',
        'avatar',
      ]);
    }

    final resolved = AuthService.resolveMediaUrl(rawUrl);
    return _appendPhotoVersion(
      resolved ??
          AuthService.resolveMediaUrl(_uploadedProfilePhotoUrl) ??
          AuthService.resolveMediaUrl(_cachedProfilePhotoUrl),
    );
  }

  String? _appendPhotoVersion(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'v': _photoRefreshSeed.toString(),
          },
        )
        .toString();
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
        builder: (context) =>
            _EditProfilePage(initialName: _name, email: _email),
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

    final editedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute<File>(
        builder: (context) =>
            _ProfilePhotoEditorPage(imageFile: File(pickedFile.path)),
      ),
    );

    if (!mounted || editedFile == null) {
      return;
    }

    final editedBytes = await editedFile.readAsBytes();
    if (!mounted) return;

    setState(() {
      _localProfilePhotoFile = editedFile;
      _localProfilePhotoBytes = editedBytes;
      _isUploadingPhoto = true;
    });

    try {
      final response = await AuthService.updateProfilePhoto(
        imageFile: editedFile,
      );

      if (!mounted) return;

      _showMessage(response.message ?? 'Proses upload foto selesai.');
      if (response.success) {
        final uploadedPhotoUrl = response.user?['profile_photo']
            ?.toString()
            .trim();
        setState(() {
          if (uploadedPhotoUrl != null && uploadedPhotoUrl.isNotEmpty) {
            _uploadedProfilePhotoUrl = uploadedPhotoUrl;
            _cachedProfilePhotoUrl = uploadedPhotoUrl;
          }
          _photoRefreshSeed = DateTime.now().millisecondsSinceEpoch;
        });
        await widget.onRefresh();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final profile = _profile;
    final name = _name;
    final email = _email;
    final employeeId = buildProfileId(profile);
    final department = buildProfileDepartment(profile);
    final roleLabel = buildProfileRoleLabel(profile, email);

    return Container(
      color: palette.backgroundSoft,
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
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profil Saya',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.primary,
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
                    localPhotoBytes: _localProfilePhotoBytes,
                    localPhotoFile: _localProfilePhotoFile,
                    photoUrl: _photoUrl,
                    isUploading: _isUploadingPhoto,
                    onChangePhoto: _changePhoto,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    roleLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.textSecondary,
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
                    label: 'ID Siswa',
                    value: employeeId,
                    accent: const Color(0xFFEAF1FF),
                    valueColor: const Color(0xFF2D68E6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _InfoCard(
                    label: 'Jurusan',
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
                color: palette.textSecondary,
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
                'PRESENSIA V1.0.0 - COPYRIGHT 2024 WMTECH.ID',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
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

class _ProfilePhotoEditorPage extends StatefulWidget {
  const _ProfilePhotoEditorPage({required this.imageFile});

  final File imageFile;

  @override
  State<_ProfilePhotoEditorPage> createState() =>
      _ProfilePhotoEditorPageState();
}

class _ProfilePhotoEditorPageState extends State<_ProfilePhotoEditorPage> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _cropKey = GlobalKey();

  double _scale = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _saveCroppedImage() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Area crop tidak ditemukan.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal memproses gambar.');
      }

      final bytes = byteData.buffer.asUint8List();
      final outputFile = File(
        '${Directory.systemTemp.path}\\profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop(outputFile);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto belum bisa diproses. Coba atur ulang lalu simpan.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateScale(double nextScale) {
    final currentMatrix = _transformationController.value.clone();
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final ratio = nextScale / currentScale;
    currentMatrix.scaleByDouble(ratio, ratio, 1, 1);
    _transformationController.value = currentMatrix;
    setState(() {
      _scale = nextScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.backgroundSoft,
      appBar: AppBar(
        backgroundColor: palette.backgroundSoft,
        elevation: 0,
        title: Text(
          'Atur Foto Profil',
          style: theme.textTheme.titleMedium?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Geser dan perbesar foto sampai posisinya pas, lalu simpan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _cropKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 280,
                        height: 280,
                        color: palette.surface,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1,
                          maxScale: 4,
                          boundaryMargin: const EdgeInsets.all(120),
                          child: Image.file(
                            widget.imageFile,
                            width: 280,
                            height: 280,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ukuran',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _scale,
                min: 1,
                max: 4,
                divisions: 12,
                activeColor: palette.primary,
                onChanged: _isSaving ? null : _updateScale,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveCroppedImage,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Foto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.localPhotoBytes,
    required this.localPhotoFile,
    required this.photoUrl,
    required this.isUploading,
    required this.onChangePhoto,
  });

  final String name;
  final Uint8List? localPhotoBytes;
  final File? localPhotoFile;
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final initials = extractInitials(name);
    final palette = context.appPalette;

    return SizedBox(
      width: 144,
      height: 126,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.surfaceAccent,
                    palette.isDark
                        ? const Color(0xFF182B42)
                        : const Color(0xFFF6F9FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: palette.border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox.expand(
                        child: localPhotoBytes != null
                            ? Image.memory(
                                localPhotoBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : localPhotoFile != null
                            ? Image.file(localPhotoFile!, fit: BoxFit.cover)
                            : photoUrl != null
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
                          color: palette.overlay,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUploading ? null : onChangePhoto,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: Color(0xFF2E7BEF),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        isUploading ? 'Upload...' : 'Ganti',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.primary,
            palette.isDark ? const Color(0xFF60A5FA) : const Color(0xFF6DB5FF),
          ],
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
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textSecondary,
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
    final palette = context.appPalette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
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
                        color: palette.textPrimary,
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
                          color: palette.textSecondary,
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
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: palette.dangerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.danger.withValues(alpha: 0.22)),
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
                color: palette.danger,
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
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.backgroundSoft,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: palette.backgroundSoft,
        elevation: 0,
        foregroundColor: palette.textPrimary,
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
                    fillColor: palette.surface,
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
                    fillColor: palette.surface,
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
