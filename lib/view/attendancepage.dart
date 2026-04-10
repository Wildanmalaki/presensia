import 'package:flutter/material.dart';
import 'package:presensia/services/auth_service.dart';
import 'package:presensia/view/widgets/formizin.dart';

class AttendancePage extends StatefulWidget {
  final Map<String, dynamic>? todayData;
  final Map<String, dynamic>? statsData;
  final Future<void> Function() onRefresh;

  const AttendancePage({
    super.key,
    this.todayData,
    this.statsData,
    required this.onRefresh,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _isAttendanceLoading = false;
  bool _isLeaveLoading = false;

  Future<void> _handleCheckIn() async {
    if (_isAttendanceLoading) return;

    setState(() {
      _isAttendanceLoading = true;
    });

    final result = await AuthService.checkIn(
      lat: -6.200000,
      lng: 106.816666,
      address: 'Jakarta',
    );

    if (!mounted) return;
    setState(() {
      _isAttendanceLoading = false;
    });

    _showMessage(result.message ?? 'Proses absen selesai.');
    if (result.success) {
      await widget.onRefresh();
    }
  }

  Future<void> _handleCheckOut() async {
    if (_isAttendanceLoading) return;

    setState(() {
      _isAttendanceLoading = true;
    });

    final result = await AuthService.checkOut(
      lat: -6.200000,
      lng: 106.816666,
      address: 'Jakarta',
    );

    if (!mounted) return;
    setState(() {
      _isAttendanceLoading = false;
    });

    _showMessage(result.message ?? 'Proses absen keluar selesai.');
    if (result.success) {
      await widget.onRefresh();
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

    await widget.onRefresh();
    _showMessage('Permintaan izin telah dikirim.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _attendanceActionLabel {
    final status = widget.todayData?['data']?['status']
        ?.toString()
        .toLowerCase();
    final hasCheckOut =
        (widget.todayData?['data']?['check_out_time']
            ?.toString()
            .trim()
            .isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      return 'Absen Masuk';
    }
    if (status == 'masuk' && !hasCheckOut) {
      return 'Absen Keluar';
    }
    if (status == 'izin') {
      return 'Absensi Hari Ini';
    }
    return 'Absen Hari Ini';
  }

  String get _attendanceActionSubtitle {
    final status = widget.todayData?['data']?['status']
        ?.toString()
        .toLowerCase();
    final hasCheckOut =
        (widget.todayData?['data']?['check_out_time']
            ?.toString()
            .trim()
            .isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      return 'Tap untuk melakukan absen masuk.';
    }
    if (status == 'masuk' && !hasCheckOut) {
      return 'Tap untuk melakukan absen keluar.';
    }
    if (status == 'izin') {
      return 'Absensi tidak tersedia karena Anda telah mengajukan izin hari ini.';
    }
    return 'Absen sudah selesai hari ini.';
  }

  VoidCallback? get _attendanceActionCallback {
    final status = widget.todayData?['data']?['status']
        ?.toString()
        .toLowerCase();
    final hasCheckOut =
        (widget.todayData?['data']?['check_out_time']
            ?.toString()
            .trim()
            .isNotEmpty ==
        true);

    if (status == null || status.isEmpty) {
      return _handleCheckIn;
    }
    if (status == 'masuk' && !hasCheckOut) {
      return _handleCheckOut;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Absensi Harian',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF21242C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          Text(
            'Kehadiran Minggu Ini',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF20232B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const _AttendanceWeekRow(),
          const SizedBox(height: 18),
          _ProductivityCard(statsData: widget.statsData),
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
