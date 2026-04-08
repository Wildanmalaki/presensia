import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presensia/services/auth_service.dart';

class FormIzinPage extends StatefulWidget {
  const FormIzinPage({super.key});

  @override
  State<FormIzinPage> createState() => _FormIzinPageState();
}

class _FormIzinPageState extends State<FormIzinPage> {
  static const List<String> _leaveTypes = [
    'Cuti Sakit',
    'Cuti Keluarga',
    'Cuti Darurat',
    'Cuti Lainnya',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _proofImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );

    if (!mounted || pickedFile == null) {
      return;
    }

    setState(() {
      _proofImage = File(pickedFile.path);
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (!mounted || pickedDate == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = pickedDate;
        if (_endDate != null && _endDate!.isBefore(pickedDate)) {
          _endDate = pickedDate;
        }
      } else {
        _endDate = pickedDate;
      }
    });
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Ambil dari Kamera',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickProofImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                _SourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Pilih dari Galeri',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickProofImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final response = await AuthService.requestLeave(
      reason: _reasonController.text.trim(),
      leaveType: _selectedLeaveType,
      startDate: _startDate,
      endDate: _endDate,
      proofImage: _proofImage,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(response.message ?? 'Proses selesai.')));

    if (response.success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FF),
        elevation: 0,
        foregroundColor: const Color(0xFF21242C),
        title: const Text('Form Izin Cuti'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E64F0), Color(0xFF59A4FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7BEF).withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajukan Izin / Cuti',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lengkapi jenis cuti, alasan, dan unggah bukti pendukung bila tersedia.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Jenis Cuti',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF20232B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLeaveType,
                  items: _leaveTypes
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLeaveType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Jenis cuti wajib dipilih.';
                    }
                    return null;
                  },
                  decoration: _inputDecoration('Pilih jenis cuti'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Periode Cuti',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF20232B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DateFieldCard(
                        label: 'Tanggal Mulai',
                        value: _formatDateLabel(_startDate),
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateFieldCard(
                        label: 'Tanggal Selesai',
                        value: _formatDateLabel(_endDate),
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Alasan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF20232B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 5,
                  validator: (value) {
                    final reason = value?.trim() ?? '';
                    if (reason.isEmpty) {
                      return 'Alasan izin wajib diisi.';
                    }
                    if (reason.length < 8) {
                      return 'Alasan terlalu singkat.';
                    }
                    return null;
                  },
                  decoration: _inputDecoration('Tuliskan alasan izin/cuti'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Bukti Pendukung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF20232B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _isSubmitting ? null : _showImageSourceSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD9E4FA),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_proofImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _proofImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              color: Color(0xFF2E7BEF),
                              size: 30,
                            ),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          _proofImage != null
                              ? 'Bukti berhasil dipilih'
                              : 'Unggah bukti surat dokter / dokumen pendukung',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF20232B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _proofImage != null
                              ? _proofImage!.path.split('\\').last
                              : 'Format gambar JPG atau PNG',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A92A6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7BEF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(
                            'Kirim Pengajuan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: Color(0xFF2E7BEF), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8515B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8515B), width: 1.2),
      ),
    );
  }

  String _formatDateLabel(DateTime? value) {
    if (value == null) {
      return 'Pilih tanggal';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _DateFieldCard extends StatelessWidget {
  const _DateFieldCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E4FA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF8A92A6),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF20232B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFFF7F9FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2E7BEF)),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF20232B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
