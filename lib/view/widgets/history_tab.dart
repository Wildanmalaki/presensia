import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:presensia/services/auth_service.dart';
import 'package:presensia/theme/app_theme.dart';

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
  bool _isMutatingLeave = false;
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
      final ranges = [
        (
          start: _formatApiDate(DateTime(now.year, now.month - 3, now.day)),
          end: _formatApiDate(now),
        ),
        (
          start: _formatApiDate(now),
          end: _formatApiDate(DateTime(now.year, now.month + 6, now.day)),
        ),
      ];

      final responses = await Future.wait(
        ranges.map(
          (range) => AuthService.fetchAttendanceHistory(
            start: range.start,
            end: range.end,
          ),
        ),
      );

      final items = <Map<String, dynamic>>[];
      for (final response in responses) {
        final rawData = response['data'];
        if (rawData is List) {
          items.addAll(rawData.whereType<Map<String, dynamic>>());
        }
      }

      final cachedLeaveItems = await AuthService.getCachedLeaveHistoryEntries();
      final mergedItems = _mergeHistoryItems(
        serverItems: items,
        cachedLeaveItems: cachedLeaveItems,
      );
      mergedItems.sort((a, b) {
        final first = a['attendance_date']?.toString() ?? '';
        final second = b['attendance_date']?.toString() ?? '';
        return second.compareTo(first);
      });

      if (!mounted) return;
      setState(() {
        _historyItems = mergedItems;
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

  List<Map<String, dynamic>> _mergeHistoryItems({
    required List<Map<String, dynamic>> serverItems,
    required List<Map<String, dynamic>> cachedLeaveItems,
  }) {
    final merged = serverItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    for (final cachedItem in cachedLeaveItems) {
      final date = cachedItem['attendance_date']?.toString();
      final status = cachedItem['status']?.toString();
      final index = merged.indexWhere(
        (item) =>
            _readItemId(item) != null &&
                _readItemId(item) == _readItemId(cachedItem) ||
            item['attendance_date']?.toString() == date &&
                item['status']?.toString() == status,
      );

      if (index >= 0) {
        merged[index] = {
          ...cachedItem,
          ...merged[index],
          'alasan_izin':
              (merged[index]['alasan_izin']?.toString().trim().isNotEmpty ==
                  true)
              ? merged[index]['alasan_izin']
              : cachedItem['alasan_izin'],
          'proof_image_path':
              cachedItem['proof_image_path'] ??
              merged[index]['proof_image_path'],
          'proof_image_base64':
              cachedItem['proof_image_base64'] ??
              merged[index]['proof_image_base64'],
        };
      } else {
        merged.add(Map<String, dynamic>.from(cachedItem));
      }
    }

    final unique = <String, Map<String, dynamic>>{};
    for (final item in merged) {
      final id = _readItemId(item);
      final key = id != null
          ? 'id_$id'
          : '${item['attendance_date']?.toString() ?? ''}_${item['status']?.toString() ?? ''}';
      unique[key] = item;
    }

    return unique.values.toList();
  }

  Future<void> _handleEditLeave(Map<String, dynamic> item) async {
    final leaveId = _readItemId(item);
    if (leaveId == null) {
      _showMessage('Data izin ini belum punya id, jadi belum bisa diedit.');
      return;
    }

    final result = await showModalBottomSheet<_LeaveEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveEditSheet(item: item),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isMutatingLeave = true;
    });

    final response = await AuthService.updateLeaveRequest(
      id: leaveId,
      previousAttendanceDate: item['attendance_date']?.toString() ?? '',
      reason: result.reason,
      attendanceDate: result.attendanceDate,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isMutatingLeave = false;
    });

    _showMessage(response.message ?? 'Proses selesai.');
    if (response.success) {
      await _loadHistory();
      await widget.onRefresh();
    }
  }

  Future<void> _handleDeleteLeave(Map<String, dynamic> item) async {
    final leaveId = _readItemId(item);
    if (leaveId == null) {
      _showMessage('Data izin ini belum punya id, jadi belum bisa dihapus.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Hapus Izin'),
          content: Text(
            'Yakin ingin menghapus izin pada ${_HistoryListItem.formatReadableDate(item['attendance_date']?.toString() ?? '-')}?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isMutatingLeave = true;
    });

    final response = await AuthService.deleteLeaveRequest(
      id: leaveId,
      attendanceDate: item['attendance_date']?.toString() ?? '',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isMutatingLeave = false;
    });

    _showMessage(response.message ?? 'Proses selesai.');
    if (response.success) {
      await _loadHistory();
      await widget.onRefresh();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static int? _readItemId(Map<String, dynamic> item) {
    final raw = item['id'];
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final today = widget.todayData?['data'] as Map<String, dynamic>?;
    final stats = widget.statsData?['data'] as Map<String, dynamic>?;
    final status = today?['status']?.toString().trim();
    final checkIn = today?['check_in_time']?.toString().trim();
    final checkOut = today?['check_out_time']?.toString().trim();
    final totalAttend = _readCount(stats?['total_absen']);
    final totalPresent = _readCount(stats?['total_masuk']);
    final totalLeave = _readCount(stats?['total_izin']);

    return Container(
      color: palette.backgroundSoft,
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
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ringkasan kehadiran terbaru Anda.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
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
                    accent: palette.surfaceAccent,
                    valueColor: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Hadir',
                    value: '$totalPresent',
                    accent: palette.successSurface,
                    valueColor: palette.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Izin',
              value: '$totalLeave',
              accent: palette.warningSurface,
              valueColor: palette.warning,
            ),
            const SizedBox(height: 20),
            Text(
              'Daftar Riwayat',
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isMutatingLeave)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 4),
              )
            else if (_errorMessage != null)
              _HistoryStateCard(
                title: 'Riwayat belum bisa dimuat',
                message: _errorMessage!,
              )
            else if (_historyItems.isEmpty)
              const _HistoryStateCard(
                title: 'Belum ada riwayat',
                message:
                    'Data riwayat absensi, izin, atau cuti belum tersedia pada periode ini.',
              )
            else
              ..._historyItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryListItem(
                    item: item,
                    onEditLeave: () => _handleEditLeave(item),
                    onDeleteLeave: () => _handleDeleteLeave(item),
                  ),
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
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
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
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
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
  const _HistoryListItem({
    required this.item,
    this.onEditLeave,
    this.onDeleteLeave,
  });

  final Map<String, dynamic> item;
  final VoidCallback? onEditLeave;
  final VoidCallback? onDeleteLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final status = item['status']?.toString().trim().toLowerCase() ?? '';
    final attendanceDate = item['attendance_date']?.toString().trim() ?? '-';
    final checkIn = item['check_in_time']?.toString().trim();
    final checkOut = item['check_out_time']?.toString().trim();
    final reason = item['alasan_izin']?.toString().trim();
    final address = item['check_in_address']?.toString().trim();
    final proofImageUrl = _extractProofImageUrl(item);
    final proofImagePath = item['proof_image_path']?.toString().trim();
    final proofImageBase64 = item['proof_image_base64']?.toString().trim();
    final hasProofImage =
        proofImageUrl != null ||
        (proofImagePath?.isNotEmpty == true) ||
        (proofImageBase64?.isNotEmpty == true);
    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status, palette);
    final canManageLeave =
        status == 'izin' && onEditLeave != null && onDeleteLeave != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
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
                  formatReadableDate(attendanceDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
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
          if (canManageLeave) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEditLeave,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDeleteLeave,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE8515B),
                  ),
                ),
              ],
            ),
          ],
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
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (hasProofImage) ...[
            const SizedBox(height: 12),
            Text(
              'Bukti pendukung',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (proofImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    proofImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: palette.surfaceMuted,
                      alignment: Alignment.center,
                      child: Text(
                        'Gambar bukti tidak dapat dimuat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (proofImagePath != null && proofImagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    File(proofImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: palette.surfaceMuted,
                      alignment: Alignment.center,
                      child: Text(
                        'Gambar bukti tidak dapat dimuat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (proofImageBase64 != null && proofImageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    base64Decode(proofImageBase64),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: palette.surfaceMuted,
                      alignment: Alignment.center,
                      child: Text(
                        'Gambar bukti tidak dapat dimuat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ] else if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              address,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
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

  static Color _statusBackground(String status, AppPalette palette) {
    switch (status) {
      case 'izin':
        return palette.warningSurface;
      case 'masuk':
        return palette.successSurface;
      default:
        return palette.surfaceAccent;
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

  static String formatReadableDate(String value) {
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

  static String? _extractProofImageUrl(Map<String, dynamic> item) {
    const candidateKeys = [
      'proof_image',
      'proof_image_url',
      'bukti_image',
      'bukti_image_url',
      'bukti',
      'lampiran',
      'attachment',
      'attachment_url',
      'image',
      'image_url',
      'photo',
      'photo_url',
    ];

    for (final key in candidateKeys) {
      final rawValue = item[key]?.toString().trim();
      if (rawValue != null &&
          rawValue.isNotEmpty &&
          rawValue.toLowerCase() != 'null') {
        return AuthService.resolveMediaUrl(rawValue);
      }
    }

    return null;
  }
}

class _LeaveEditResult {
  const _LeaveEditResult({required this.attendanceDate, required this.reason});

  final DateTime attendanceDate;
  final String reason;
}

class _LeaveEditSheet extends StatefulWidget {
  const _LeaveEditSheet({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_LeaveEditSheet> createState() => _LeaveEditSheetState();
}

class _LeaveEditSheetState extends State<_LeaveEditSheet> {
  late final TextEditingController _reasonController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.item['alasan_izin']?.toString().trim() ?? '',
    );
    _selectedDate = _parseAttendanceDate(
      widget.item['attendance_date']?.toString(),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alasan izin wajib diisi.')));
      return;
    }

    Navigator.of(
      context,
    ).pop(_LeaveEditResult(attendanceDate: _selectedDate, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 24, 12, bottomInset + 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Izin',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tanggal',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD9E4FA)),
                  ),
                  child: Text(
                    _HistoryListItem.formatReadableDate(
                      _formatDate(_selectedDate),
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF20232B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Alasan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Perbarui alasan izin',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFD9E4FA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E7BEF),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7BEF),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _parseAttendanceDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _HistoryMeta extends StatelessWidget {
  const _HistoryMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
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
