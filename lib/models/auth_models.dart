List<Map<String, dynamic>> _extractJsonList(
  Map<String, dynamic> source,
  List<String> keys,
) {
  for (final key in keys) {
    final value = source[key];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is Map<String, dynamic>) {
      final nestedList = value['data'];
      if (nestedList is List) {
        return nestedList.whereType<Map<String, dynamic>>().toList();
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

String _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
  }
  return '';
}

int _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

List<TrainingOption> _deduplicateTrainings(List<TrainingOption> trainings) {
  final seenKeys = <String>{};
  final result = <TrainingOption>[];

  for (final training in trainings) {
    final normalizedTitle = training.title.trim().toLowerCase();
    final key = training.id > 0
        ? 'id:${training.id}'
        : 'title:$normalizedTitle';
    if (normalizedTitle.isEmpty || seenKeys.contains(key)) {
      continue;
    }
    seenKeys.add(key);
    result.add(training);
  }

  return result;
}

class TrainingOption {
  const TrainingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory TrainingOption.fromJson(Map<String, dynamic> json) {
    final resolvedTitle = _readString(json, const [
      'title',
      'name',
      'training_name',
      'nama',
    ]);

    return TrainingOption(
      id: _readInt(json, const ['id', 'training_id']),
      title: resolvedTitle.isEmpty ? 'Jurusan tanpa nama' : resolvedTitle,
    );
  }
}

class BatchOption {
  const BatchOption({
    required this.id,
    required this.label,
    required this.trainings,
  });

  final int id;
  final String label;
  final List<TrainingOption> trainings;

  factory BatchOption.fromJson(Map<String, dynamic> json) {
    final rawTrainings = _extractJsonList(json, const [
      'trainings',
      'training',
      'jurusans',
      'majors',
    ]);
    final parsedTrainings = rawTrainings.map(TrainingOption.fromJson).toList();
    final trainings = _deduplicateTrainings(parsedTrainings);
    final batchLabel = _readString(json, const [
      'label',
      'name',
      'title',
      'batch_name',
    ]);
    final batchNumber = _readString(json, const ['batch_ke', 'batch']);

    return BatchOption(
      id: _readInt(json, const ['id', 'batch_id']),
      label: batchLabel.isNotEmpty
          ? batchLabel
          : batchNumber.isNotEmpty
          ? 'Batch $batchNumber'
          : 'Batch',
      trainings: trainings,
    );
  }
}

class AuthResponse {
  const AuthResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? user;
}
