class LeaveHistoryEntry {
  const LeaveHistoryEntry({
    this.id,
    required this.attendanceDate,
    required this.status,
    required this.reason,
    this.proofImagePath,
    this.proofImageBase64,
  });

  final int? id;
  final String attendanceDate;
  final String status;
  final String reason;
  final String? proofImagePath;
  final String? proofImageBase64;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attendance_date': attendanceDate,
      'status': status,
      'alasan_izin': reason,
      'proof_image_path': proofImagePath,
      'proof_image_base64': proofImageBase64,
    };
  }

  factory LeaveHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LeaveHistoryEntry(
      id: _readInt(json['id']),
      attendanceDate: json['attendance_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'izin',
      reason: json['alasan_izin']?.toString() ?? '',
      proofImagePath: json['proof_image_path']?.toString(),
      proofImageBase64: json['proof_image_base64']?.toString(),
    );
  }

  LeaveHistoryEntry copyWith({
    int? id,
    String? attendanceDate,
    String? status,
    String? reason,
    String? proofImagePath,
    String? proofImageBase64,
  }) {
    return LeaveHistoryEntry(
      id: id ?? this.id,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      proofImageBase64: proofImageBase64 ?? this.proofImageBase64,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
