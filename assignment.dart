import 'dart:io';

class Subject {
  final String _name;
  final bool _likesSubject;
  final List<String> _assignmentTypes;

  double _totalEstimatedTime = 0;
  double _totalActualTime = 0;
  int _completedAssignments = 0;

  Subject(this._name, this._likesSubject, this._assignmentTypes);

  String get name => _name;

  void recordCompletion(double estimate, double actual) {
    _totalEstimatedTime += estimate;
    _totalActualTime += actual;
    _completedAssignments++;
  }

  double get efficiencyFactor {
    if (_completedAssignments == 0) return 1.0;
    return _totalActualTime / _totalEstimatedTime;
  }
}

class Assignment {
  final String _title;
  final Subject _subject;
  final double _estimatedTime;
  final double _baselineEfficiency;
  double? _actualTime;

  Assignment(this._title, this._subject, double estimatedTime)
    : _estimatedTime = estimatedTime.abs(),
      _baselineEfficiency = _subject.efficiencyFactor;

  double get estimatedTime => _estimatedTime;

  String get subjectName => _subject.name;

  double get adjustedEstimate {
    return _estimatedTime * _baselineEfficiency;
  }

  void complete(double actual) {
    _actualTime = actual.abs();
    _subject.recordCompletion(_estimatedTime, _actualTime!);
  }

  double? get actualTime => _actualTime;
  bool get isCompleted => _actualTime != null;
  String get title => _title;
}

class AssignmentTracker {
  final List<Assignment> assignments = [];
  final Map<String, Subject> _subjects = {};
  final List<String> allowedSubjects = [];

  AssignmentTracker();

  AssignmentTracker.fromJson(Map<String, dynamic> json) {
    final list = json['assignments'] as List<dynamic>? ?? [];
    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map);
      final subjectName = (map['subject'] as String?) ?? 'Unknown';
      final subjectKey = subjectName.toLowerCase();
      final subject = _subjects.putIfAbsent(
        subjectKey,
        () => Subject(subjectName, true, []),
      );

      final title = (map['title'] as String?) ?? 'Untitled';
      final estimated = (map['estimated'] as num?)?.toDouble() ?? 0.0;

      final assignment = Assignment(title, subject, estimated);
      if (map.containsKey('actual') && map['actual'] != null) {
        assignment.complete((map['actual'] as num).toDouble());
      }

      assignments.add(assignment);
    }

    final savedSubjects = json['allowedSubjects'] as List<dynamic>?;
    if (savedSubjects != null) {
      for (final subject in savedSubjects) {
        if (subject is String && subject.trim().isNotEmpty) {
          allowedSubjects.add(subject.trim());
        }
      }
    }

    if (allowedSubjects.isEmpty) {
      allowedSubjects.addAll(
        _subjects.values.map((subject) => subject.name).toSet(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'assignments': assignments.map((a) {
        return {
          'title': a.title,
          'subject': a.subjectName,
          'estimated': a.estimatedTime,
          'actual': a.actualTime,
        };
      }).toList(),
      'allowedSubjects': allowedSubjects,
    };
  }

  Assignment completeAssignment(
    String title,
    String subjectName,
    double estimate,
    double actual,
  ) {
    addSubjectIfMissing(subjectName);
    final key = subjectName.toLowerCase();
    final subject = _subjects.putIfAbsent(
      key,
      () => Subject(subjectName, true, []),
    );
    final assignment = Assignment(title, subject, estimate);
    assignment.complete(actual);
    assignments.add(assignment);
    return assignment;
  }

  Assignment addAssignment(String title, String subjectName, double estimate) {
    addSubjectIfMissing(subjectName);
    final key = subjectName.toLowerCase();
    final subject = _subjects.putIfAbsent(
      key,
      () => Subject(subjectName, true, []),
    );
    final assignment = Assignment(title, subject, estimate);
    assignments.add(assignment);
    return assignment;
  }

  void updateAllowedSubjects(List<String> subjects) {
    allowedSubjects
      ..clear()
      ..addAll(subjects.where((subject) => subject.trim().isNotEmpty));
  }

  void addSubjectIfMissing(String subjectName) {
    final normalized = subjectName.trim();
    if (normalized.isEmpty) {
      return;
    }
    final exists = allowedSubjects.any(
      (saved) => saved.toLowerCase() == normalized.toLowerCase(),
    );
    if (!exists) {
      allowedSubjects.add(normalized);
    }
  }

  List<Assignment> get pendingAssignments =>
      assignments.where((a) => a.actualTime == null).toList();

  Assignment completePendingAssignment(Assignment assignment, double actual) {
    assignment.complete(actual);
    return assignment;
  }
}

double readTimeMinutes(String prompt) {
  while (true) {
    stdout.write(prompt);
    final input = stdin.readLineSync();
    final parsed = double.tryParse(input ?? '');
    if (parsed != null) {
      return parsed.abs();
    }
    print("Invalid input. Enter a valid number.");
  }
}

Map<String, Object>? parseAssignmentLine(String line) {
  final trimmed = line.trim();
  final firstComma = trimmed.indexOf(',');
  final secondComma = firstComma >= 0
      ? trimmed.indexOf(',', firstComma + 1)
      : -1;

  if (firstComma < 0 || secondComma < 0) {
    return null;
  }

  final title = trimmed.substring(0, firstComma).trim();
  final estimateString = trimmed.substring(firstComma + 1, secondComma).trim();
  final subjectName = trimmed.substring(secondComma + 1).trim();

  final estimate = double.tryParse(estimateString);
  if (title.isEmpty || subjectName.isEmpty || estimate == null) {
    return null;
  }

  return {'title': title, 'estimate': estimate.abs(), 'subject': subjectName};
}

double measureActualTimeMinutes() {
  stdout.write("Press Enter to start the timer...");
  stdin.readLineSync();
  final start = DateTime.now();
  stdout.write(
    "Timer started. Press Enter again when assignment is finished...",
  );
  stdin.readLineSync();
  final end = DateTime.now();
  final elapsedSeconds = end.difference(start).inSeconds;
  return elapsedSeconds / 60.0;
}
