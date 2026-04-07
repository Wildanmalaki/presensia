import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:presensia/services/auth_service.dart';
import 'package:presensia/view/attendancehomepage.dart';
import 'package:presensia/view/widgets/navbar.dart';
import 'package:presensia/view/widgets/app_drawer.dart';
import 'package:presensia/view/widgets/attendance_tab.dart';
import 'package:presensia/view/widgets/formizin.dart';
import 'package:presensia/view/widgets/history_tab.dart';
import 'package:presensia/view/widgets/profile_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _ppkdLatitude = -6.2108808;
  static const double _ppkdLongitude = 106.8129424;
  static const double _attendanceRadiusMeters = 400;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  late DateTime _now;
  Timer? _clockTimer;
  StreamSubscription<Position>? _locationSubscription;
  String _userName = 'Pengguna';
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _todayData;
  bool _isLoadingData = true;
  bool _isAttendanceLoading = false;
  bool _isLeaveLoading = false;
  bool _isWithinAttendanceZone = false;
  double? _distanceToPpkdMeters;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadUserName();
    _refreshData();
    _initializeAttendanceLocation();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final savedName = await AuthService.getUserName();
    if (!mounted) return;

    final normalizedName = savedName?.trim();
    if (normalizedName == null || normalizedName.isEmpty) return;

    setState(() {
      _userName = normalizedName;
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
    });

    Map<String, dynamic>? latestProfile = _profileData;
    Map<String, dynamic>? latestStats = _statsData;
    Map<String, dynamic>? latestToday = _todayData;
    final errors = <String>[];

    final results = await Future.wait<_RefreshResult>([
      _loadRefreshSection(AuthService.fetchProfile),
      _loadRefreshSection(AuthService.fetchAttendanceStats),
      _loadRefreshSection(AuthService.fetchAttendanceToday),
    ]);

    if (results[0].data != null) {
      latestProfile = results[0].data;
    }
    if (results[1].data != null) {
      latestStats = results[1].data;
    }
    if (results[2].data != null) {
      latestToday = results[2].data;
    }

    for (final result in results) {
      if (result.errorMessage != null) {
        errors.add(result.errorMessage!);
      }
    }

    if (!mounted) return;

    setState(() {
      _profileData = latestProfile;
      _statsData = latestStats;
      _todayData = latestToday;
      final profileName = _extractProfileName(latestProfile);
      if (profileName != null) {
        _userName = profileName;
      }
      _isLoadingData = false;
    });

    if (errors.isNotEmpty) {
      _showMessage(context, errors.first);
    }
  }

  String? _extractProfileName(Map<String, dynamic>? profileResponse) {
    final data = profileResponse?['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final directName = data['name']?.toString().trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }

    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final nestedName = user['name']?.toString().trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        return nestedName;
      }
    }

    return null;
  }

  Future<void> _initializeAttendanceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isWithinAttendanceZone = false;
          _distanceToPpkdMeters = null;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        _updateAttendanceZone(position.latitude, position.longitude);
      }

      _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        _updateAttendanceZone(position.latitude, position.longitude);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isWithinAttendanceZone = false;
        _distanceToPpkdMeters = null;
      });
    }
  }

  String? _extractProfileEmail(Map<String, dynamic>? profileResponse) {
    final data = profileResponse?['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final directEmail = data['email']?.toString().trim();
    if (directEmail != null && directEmail.isNotEmpty) {
      return directEmail;
    }

    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final nestedEmail = user['email']?.toString().trim();
      if (nestedEmail != null && nestedEmail.isNotEmpty) {
        return nestedEmail;
      }
    }

    return null;
  }

  Future<void> _handleCheckIn() async {
    if (_isAttendanceLoading) return;
    if (!_isWithinAttendanceZone) {
      _showMessage(
        context,
        'Anda di luar radius 400 meter dari PPKD. Absen tidak tersedia.',
      );
      return;
    }

    setState(() {
      _isAttendanceLoading = true;
    });

    final location = await _resolveAttendanceLocation();
    final result = await AuthService.checkIn(
      lat: location.lat,
      lng: location.lng,
      address: location.address,
    );

    if (!mounted) return;
    setState(() {
      _isAttendanceLoading = false;
    });

    _showMessage(context, result.message ?? 'Proses absen selesai.');
    if (result.success) {
      await _refreshData();
    }
  }

  Future<void> _handleCheckOut() async {
    if (_isAttendanceLoading) return;
    if (!_isWithinAttendanceZone) {
      _showMessage(
        context,
        'Anda di luar radius 400 meter dari PPKD. Absen tidak tersedia.',
      );
      return;
    }

    setState(() {
      _isAttendanceLoading = true;
    });

    final location = await _resolveAttendanceLocation();
    final result = await AuthService.checkOut(
      lat: location.lat,
      lng: location.lng,
      address: location.address,
    );

    if (!mounted) return;
    setState(() {
      _isAttendanceLoading = false;
    });

    _showMessage(context, result.message ?? 'Proses absen keluar selesai.');
    if (result.success) {
      await _refreshData();
    }
  }

  Future<void> _handleLeave() async {
    if (_isLeaveLoading) return;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const FormIzinPage()),
    );
    if (!mounted || submitted != true) {
      return;
    }

    setState(() {
      _isLeaveLoading = true;
    });

    if (!mounted) return;
    setState(() {
      _isLeaveLoading = false;
    });

    await _refreshData();
    _showMessage(context, 'Permintaan izin telah dikirim.');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _attendanceActionLabel {
    final status = _todayData?['data']?['status']?.toString().toLowerCase();
    final hasCheckOut =
        (_todayData?['data']?['check_out_time']?.toString().trim().isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      if (!_isWithinAttendanceZone) {
        return 'Di Luar Radius PPKD';
      }
      return 'Absen Masuk';
    }
    if (status == 'masuk' && !hasCheckOut) {
      if (!_isWithinAttendanceZone) {
        return 'Di Luar Radius PPKD';
      }
      return 'Absen Keluar';
    }
    if (status == 'izin') {
      return 'Sudah Izin';
    }
    return 'Absen Hari Ini';
  }

  String get _attendanceActionSubtitle {
    final status = _todayData?['data']?['status']?.toString().toLowerCase();
    final hasCheckOut =
        (_todayData?['data']?['check_out_time']?.toString().trim().isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      if (!_isWithinAttendanceZone) {
        return 'Absen hanya bisa dilakukan dalam radius 400 meter dari PPKD.';
      }
      return 'Tap untuk melakukan absen masuk.';
    }
    if (status == 'masuk' && !hasCheckOut) {
      if (!_isWithinAttendanceZone) {
        return 'Absen hanya bisa dilakukan dalam radius 400 meter dari PPKD.';
      }
      return 'Tap untuk melakukan absen keluar.';
    }
    if (status == 'izin') {
      return 'Anda telah mengajukan izin hari ini.';
    }
    return 'Absen sudah selesai hari ini.';
  }

  VoidCallback? get _attendanceActionCallback {
    final status = _todayData?['data']?['status']?.toString().toLowerCase();
    final hasCheckOut =
        (_todayData?['data']?['check_out_time']?.toString().trim().isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      if (!_isWithinAttendanceZone) {
        return null;
      }
      return _handleCheckIn;
    }
    if (status == 'masuk' && !hasCheckOut) {
      if (!_isWithinAttendanceZone) {
        return null;
      }
      return _handleCheckOut;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        name: _userName,
        email: _extractProfileEmail(_profileData) ?? 'email belum tersedia',
        currentIndex: _selectedIndex,
        onSelectTab: (index) {
          if (!mounted) return;
          setState(() {
            _selectedIndex = index;
          });
        },
        onLogout: () async {
          await AuthService.clearToken();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const AttendanceHomepage(),
            ),
            (route) => false,
          );
        },
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedIndex == 1) {
      return AttendanceTab(
        statsData: _statsData,
        todayData: _todayData,
        onRefresh: _refreshData,
      );
    }

    if (_selectedIndex == 2) {
      return HistoryTab(
        statsData: _statsData,
        todayData: _todayData,
        onRefresh: _refreshData,
      );
    }

    if (_selectedIndex == 3) {
      return ProfileTab(
        profileData: _profileData,
        currentUserName: _userName,
        onRefresh: _refreshData,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            onNotificationTap: () {
              _showMessage(context, 'Tidak ada notifikasi baru.');
            },
          ),
          const SizedBox(height: 22),
          Text(
            _greetingForHour(_now.hour),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8B93A7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF21242C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _CurrentTimeCard(now: _now),
          const SizedBox(height: 18),
          _AttendanceActionCard(
            label: _attendanceActionLabel,
            subtitle: _attendanceActionSubtitle,
            onTap: _attendanceActionCallback,
            isLoading: _isAttendanceLoading,
          ),
          const SizedBox(height: 12),
          _LeaveActionCard(
            onTap: _handleLeave,
            isLoading: _isLeaveLoading,
          ),
          const SizedBox(height: 18),
          _LocationCard(
            isWithinZone: _isWithinAttendanceZone,
            distanceMeters: _distanceToPpkdMeters,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kehadiran Minggu Ini',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF20232B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7BEF),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Lihat Detail',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF2E7BEF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _AttendanceWeekRow(),
          const SizedBox(height: 18),
          _ProductivityCard(statsData: _statsData),
        ],
      ),
    );
  }

  String _greetingForHour(int hour) {
    if (hour < 11) {
      return 'Selamat Pagi,';
    }
    if (hour < 15) {
      return 'Selamat Siang,';
    }
    if (hour < 18) {
      return 'Selamat Sore,';
    }
    return 'Selamat Malam,';
  }

  Future<_AttendanceLocation> _resolveAttendanceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const _AttendanceLocation(
          lat: -6.200000,
          lng: 106.816666,
          address: 'Jakarta',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return _AttendanceLocation(
        lat: position.latitude,
        lng: position.longitude,
        address:
            '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
      );
    } catch (_) {
      return const _AttendanceLocation(
        lat: -6.200000,
        lng: 106.816666,
        address: 'Jakarta',
      );
    }
  }

  void _updateAttendanceZone(double latitude, double longitude) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      _ppkdLatitude,
      _ppkdLongitude,
    );

    setState(() {
      _distanceToPpkdMeters = distance;
      _isWithinAttendanceZone = distance <= _attendanceRadiusMeters;
    });
  }

  Future<_RefreshResult> _loadRefreshSection(
    Future<Map<String, dynamic>> Function() loader,
  ) async {
    try {
      final data = await loader();
      return _RefreshResult(data: data);
    } catch (error) {
      return _RefreshResult(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class _RefreshResult {
  const _RefreshResult({this.data, this.errorMessage});

  final Map<String, dynamic>? data;
  final String? errorMessage;
}

class _AttendanceLocation {
  const _AttendanceLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });

  final double lat;
  final double lng;
  final String address;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenuTap, required this.onNotificationTap});

  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _HeaderIconButton(icon: Icons.menu_rounded, onTap: onMenuTap),
        const SizedBox(width: 10),
        Text(
          'Presensia',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF2E7BEF),
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: onNotificationTap,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8A4C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF5E667A), size: 20),
        ),
      ),
    );
  }
}

class _CurrentTimeCard extends StatelessWidget {
  const _CurrentTimeCard({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedTime = _formatTime(now);
    final formattedDate = _formatDate(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT TIME',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6BA0F5),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formattedTime,
            style: theme.textTheme.displaySmall?.copyWith(
              color: const Color(0xFF242833),
              fontWeight: FontWeight.w800,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              formattedDate,
              key: ValueKey<String>(formattedDate),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A92A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEB5757),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Belum Absen',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF657089),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatDate(DateTime value) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[value.weekday - 1];
    final monthName = months[value.month - 1];
    return '$dayName, ${value.day} $monthName ${value.year}';
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.isWithinZone, this.distanceMeters});

  final bool isWithinZone;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Color(0xFF2E7BEF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Radius Kehadiran',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF232833),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isWithinZone
                      ? 'Anda berada dalam radius absensi PPKD.'
                      : 'Anda di luar radius 400 meter dari PPKD.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A92A6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (distanceMeters != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Jarak ke PPKD: ${distanceMeters!.round()} meter',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A92A6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isWithinZone
                  ? const Color(0xFFE8F8EE)
                  : const Color(0xFFFFEFEF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isWithinZone ? 'BISA ABSEN' : 'DI LUAR AREA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isWithinZone
                    ? const Color(0xFF35A867)
                    : const Color(0xFFE8515B),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceActionCard extends StatelessWidget {
  const _AttendanceActionCard({
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.isLoading,
  });

  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF2E7BEF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7BEF),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0x332E7BEF),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                isLoading ? 'Sedang memproses...' : subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveActionCard extends StatelessWidget {
  const _LeaveActionCard({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFF2E7BEF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajukan Izin',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF232833),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading
                          ? 'Mengirim permintaan...'
                          : 'Ajukan izin apabila tidak hadir hari ini.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A92A6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF2E7BEF),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceWeekRow extends StatelessWidget {
  const _AttendanceWeekRow();

  static const List<_AttendanceDay> _days = [
    _AttendanceDay('MON', Color(0xFFEDF4FF), Color(0xFF2E7BEF), true),
    _AttendanceDay('TUE', Color(0xFFEAF8EF), Color(0xFF29A35A), false),
    _AttendanceDay('WED', Color(0xFFFFEFF0), Color(0xFFE8515B), false),
    _AttendanceDay('THU', Color(0xFFEAF8EF), Color(0xFF29A35A), false),
    _AttendanceDay('FRI', Color(0xFFF5F7FB), Color(0xFFD6DCE8), false),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days
          .map(
            (day) => Column(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: day.isSelected
                        ? Border.all(color: const Color(0xFFB8D3FF), width: 1.6)
                        : day.label == 'FRI'
                        ? Border.all(
                            color: const Color(0xFFD9DFEA),
                            width: 1.2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: day.background,
                        shape: BoxShape.circle,
                      ),
                      child: day.label == 'FRI'
                          ? null
                          : Icon(
                              day.isSelected
                                  ? Icons.circle_outlined
                                  : Icons.check_rounded,
                              size: 14,
                              color: day.foreground,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  day.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF838CA1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _ProductivityCard extends StatelessWidget {
  const _ProductivityCard({this.statsData});

  final Map<String, dynamic>? statsData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const barHeights = [44.0, 50.0, 30.0, 60.0, 24.0, 72.0];
    final effectiveness =
        statsData?['data']?['total_absen'] is int &&
            statsData?['data']?['total_absen'] > 0
        ? ((statsData!['data']['total_masuk'] ?? 0) *
              100 ~/
              (statsData!['data']['total_absen'] ?? 1))
        : 88;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(barHeights.length, (index) {
                final isActive = index == barHeights.length - 1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: barHeights[index],
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF2E7BEF)
                            : const Color(0xFFE7EEF8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7BEF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Efektivitas Kerja',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF738097),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$effectiveness%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF232833),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceDay {
  const _AttendanceDay(
    this.label,
    this.background,
    this.foreground,
    this.isSelected,
  );

  final String label;
  final Color background;
  final Color foreground;
  final bool isSelected;
}
