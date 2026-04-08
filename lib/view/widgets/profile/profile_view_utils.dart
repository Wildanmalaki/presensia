String buildProfileId(Map<String, dynamic>? profile) {
  if (profile == null) {
    return 'ID belum tersedia';
  }

  final rawId = readFlexibleProfileValue(profile, const ['id']);
  if (rawId.isNotEmpty) {
    return rawId;
  }

  return 'ID belum tersedia';
}

String buildProfileDepartment(Map<String, dynamic>? profile) {
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

String buildProfileRoleLabel(Map<String, dynamic>? profile, String email) {
  final role = profile?['role']?.toString().trim();
  if (role != null && role.isNotEmpty) {
    return role.toUpperCase();
  }

  if (email != 'email belum tersedia') {
    return 'PESERTA AKTIF';
  }

  return 'ANGGOTA PRESENSIA';
}

String readProfileString(Map<String, dynamic> source, List<String> keys) {
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

String readFlexibleProfileValue(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }

  final user = source['user'];
  if (user is Map<String, dynamic>) {
    for (final key in keys) {
      final value = user[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
  }

  for (final containerKey in const ['student', 'participant', 'member', 'profile']) {
    final nested = source[containerKey];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value is num) {
          return value.toString();
        }
      }
    }
  }

  return '';
}

String extractInitials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'PP';
  }

  final first = parts.first.substring(0, 1).toUpperCase();
  final second = parts.length > 1
      ? parts.last.substring(0, 1).toUpperCase()
      : '';
  return '$first$second';
}
