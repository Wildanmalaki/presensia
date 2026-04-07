import 'package:flutter/material.dart';
import 'package:presensia/services/auth_service.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.statsData,
    required this.todayData,
    required this.onRefresh,
  });

  final Map<String, dynamic>? statsData;
  final Map<String, dynamic>? todayData;
  final Future<void> Function() onRefresh;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Map<String, dynamic>> _historyItems = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final start = _formatApiDate(DateTime(now.year, now.month, 1));
      final end = _formatApiDate(now);
      final response = await AuthService.fetchAttendanceHistory(
        start: start,
        end: end,
      );
      final rawData = response['data'];
      final items = rawData is List
          ? rawData.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _historyItems = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = widget.todayData?['data'] as Map<String, dynamic>?;
    final stats = widget.statsData?['data'] as Map<String, dynamic>?;
    final status = today?['status']?.toString().trim();
    final checkIn = today?['check_in_time']?.toString().trim();
    final checkOut = today?['check_out_time']?.toString().trim();
    final totalAttend = _readCount(stats?['total_absen']);
    final totalPresent = _readCount(stats?['total_masuk']);
    final totalLeave = _readCount(stats?['total_izin']);

    return Container(
      color: const Color(0xFFF7F9FF),
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF2E7BEF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              'Riwayat Absensi',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF20232B),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ringkasan kehadiran terbaru Anda.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8A92A6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E64F0), Color(0xFF58A1FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7BEF).withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS TERAKHIR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatStatus(status),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HistoryHighlight(
                          label: 'Check In',
                          value: _displayTime(checkIn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HistoryHighlight(
                          label: 'Check Out',
                          value: _displayTime(checkOut),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Absen',
                    value: '$totalAttend',
                    accent: const Color(0xFFEAF2FF),
                    valueColor: const Color(0xFF2E7BEF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Hadir',
                    value: '$totalPresent',
                    accent: const Color(0xFFEAF8F0),
                    valueColor: const Color(0xFF2FA95E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Izin',
              value: '$totalLeave',
              accent: const Color(0xFFFFF4ED),
              valueColor: const Color(0xFFE98942),
            ),
            const SizedBox(height: 20),
            Text(
              'Daftar Riwayat',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF20232B),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _HistoryStateCard(
                title: 'Riwayat belum bisa dimuat',
                message: _errorMessage!,
              )
            else if (_historyItems.isEmpty)
              const _HistoryStateCard(
                title: 'Belum ada riwayat',
                message: 'Data riwayat absensi belum tersedia pada periode ini.',
              )
            else
              ..._historyItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryListItem(item: item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatApiDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _readCount(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatStatus(String? value) {
    if (value == null || value.isEmpty) {
      return 'Belum ada data hari ini';
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _displayTime(String? value) {
    if (value == null || value.isEmpty) {
      return '--:--';
    }
    return value;
  }
}

class _HistoryStateCard extends StatelessWidget {
  const _HistoryStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF20232B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8A92A6),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item['status']?.toString().trim().toLowerCase() ?? '';
    final attendanceDate = item['attendance_date']?.toString().trim() ?? '-';
    final checkIn = item['check_in_time']?.toString().trim();
    final checkOut = item['check_out_time']?.toString().trim();
    final reason = item['alasan_izin']?.toString().trim();
    final address = item['check_in_address']?.toString().trim();
    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatReadableDate(attendanceDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF20232B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatStatusLabel(status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryMeta(
                  label: 'Check In',
                  value: _displayValue(checkIn),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HistoryMeta(
                  label: 'Check Out',
                  value: _displayValue(checkOut),
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Alasan: $reason',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A92A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              address,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A92A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'izin':
        return const Color(0xFFE98942);
      case 'masuk':
        return const Color(0xFF2FA95E);
      default:
        return const Color(0xFF5D73E6);
    }
  }

  static Color _statusBackground(String status) {
    switch (status) {
      case 'izin':
        return const Color(0xFFFFF4ED);
      case 'masuk':
        return const Color(0xFFEAF8F0);
      default:
        return const Color(0xFFF2F4FF);
    }
  }

  static String _formatStatusLabel(String status) {
    if (status.isEmpty) {
      return 'TIDAK DIKETAHUI';
    }
    return status.toUpperCase();
  }

  static String _displayValue(String? value) {
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return '--:--';
    }
    return value;
  }

  static String _formatReadableDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return value;
    }

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

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return value;
    }

    return '$day ${months[month - 1]} $year';
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8A92A6),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF20232B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryHighlight extends StatelessWidget {
  const _HistoryHighlight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A92A6),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
