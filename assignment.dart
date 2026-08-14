import 'dart:io';

class Subject {
  final String _name;
  final bool _likesSubject;

  double _totalEstimatedTime = 0;
  double _totalActualTime = 0;
  int _completedAssignments = 0;

  Subject(this._name, this._likesSubject);

  String get name => _name;
  bool get likesSubject => _likesSubject;

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
  final DateTime? _dueDate;
  final int _parts;

  Assignment(
    this._title,
    this._subject,
    double estimatedTime, [
    DateTime? dueDate,
    int parts = 0,
  ]) : _estimatedTime = estimatedTime.abs(),
       _baselineEfficiency = _subject.efficiencyFactor,
       _dueDate = dueDate,
       _parts = parts;

  double get estimatedTime => _estimatedTime;

  String get subjectName => _subject.name;
  bool get likesSubject => _subject.likesSubject;

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
  DateTime? get dueDate => _dueDate;
  int get parts => _parts;
}

class AssignmentTracker {
  final List<Assignment> assignments = [];
  final Map<String, Subject> _subjects = {};
  final List<Subject> allowedSubjects = [];

  AssignmentTracker();

  AssignmentTracker.fromJson(Map<String, dynamic> json) {
    final savedSubjects = json['allowedSubjects'] as List<dynamic>?;
    if (savedSubjects != null) {
      for (final subject in savedSubjects) {
        if (subject is Map<String, dynamic>) {
          final name = (subject['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            final likes = subject['likes'] is bool
                ? subject['likes'] as bool
                : true;
            final subjectObj = Subject(name, likes);
            allowedSubjects.add(subjectObj);
            _subjects[name.toLowerCase()] = subjectObj;
          }
        }
      }
    }

    final list = json['assignments'] as List<dynamic>? ?? [];
    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map);
      final subjectName = (map['subject'] as String?) ?? 'Unknown';
      final subjectKey = subjectName.toLowerCase();
      final subject = _subjects.putIfAbsent(
        subjectKey,
        () => Subject(subjectName, true),
      );

      final title = (map['title'] as String?) ?? 'Untitled';
      final estimated = (map['estimated'] as num?)?.toDouble() ?? 0.0;
      DateTime? due;
      if (map.containsKey('dueDate') && map['dueDate'] != null) {
        try {
          due = DateTime.tryParse(map['dueDate'] as String);
        } catch (_) {
          due = null;
        }
      }

      final parts = (map['parts'] is int)
          ? (map['parts'] as int)
          : (map['parts'] is num ? (map['parts'] as num).toInt() : 0);

      final assignment = Assignment(title, subject, estimated, due, parts);
      if (map.containsKey('actual') && map['actual'] != null) {
        assignment.complete((map['actual'] as num).toDouble());
      }

      assignments.add(assignment);
    }

    if (allowedSubjects.isEmpty) {
      final names = <String>{};
      for (final subject in _subjects.values) {
        if (!names.contains(subject.name.toLowerCase())) {
          names.add(subject.name.toLowerCase());
          allowedSubjects.add(subject);
        }
      }
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
          'dueDate': a.dueDate?.toIso8601String(),
          'parts': a.parts,
        };
      }).toList(),
      'allowedSubjects': allowedSubjects.map((subject) {
        return {'name': subject.name, 'likes': subject.likesSubject};
      }).toList(),
    };
  }

  Assignment completeAssignment(
    String title,
    String subjectName,
    double estimate,
    double actual, [
    DateTime? dueDate,
    int parts = 0,
  ]) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(title, subject, estimate, dueDate, parts);
    assignment.complete(actual);
    assignments.add(assignment);
    return assignment;
  }

  Assignment addAssignment(
    String title,
    String subjectName,
    double estimate, [
    DateTime? dueDate,
    int parts = 0,
  ]) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(title, subject, estimate, dueDate, parts);
    assignments.add(assignment);
    return assignment;
  }

  void updateAllowedSubjects(List<Subject> subjects) {
    allowedSubjects
      ..clear()
      ..addAll(subjects.where((subject) => subject.name.trim().isNotEmpty));

    for (final subject in allowedSubjects) {
      _subjects[subject.name.toLowerCase()] = subject;
    }
  }

  void addSubjectIfMissing(String subjectName) {
    final normalized = subjectName.trim();
    if (normalized.isEmpty) {
      return;
    }
    final key = normalized.toLowerCase();
    if (!_subjects.containsKey(key)) {
      final subject = Subject(normalized, true);
      _subjects[key] = subject;
    }
    final exists = allowedSubjects.any(
      (saved) => saved.name.toLowerCase() == key,
    );
    if (!exists) {
      allowedSubjects.add(_subjects[key]!);
    }
  }

  DateTime? parseFlexibleDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;

    final parts = t.split('/');
    if (parts.length == 3) {
      final m = int.tryParse(parts[0].trim());
      final d = int.tryParse(parts[1].trim());
      var y = int.tryParse(parts[2].trim());
      if (m == null || d == null || y == null) return null;
      if (y < 100) y += 2000;
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Subject getOrCreateSubject(String subjectName) {
    final normalized = subjectName.trim();
    final key = normalized.toLowerCase();
    return _subjects.putIfAbsent(key, () => Subject(normalized, true));
  }

  List<Assignment> scheduleAssignments(List<Assignment> pending) {
    final now = DateTime.now();
    final expanded = <Assignment>[];

    for (final a in pending) {
      if (a.parts > 1 && a.dueDate != null) {
        final parts = a.parts;
        var totalDays = a.dueDate!.difference(now).inDays;
        if (totalDays < 1) totalDays = 1;

        // compute base spacing; prefer at least one-day gap when there's room
        var gapDays = totalDays ~/ parts;
        if (gapDays < 1) gapDays = 1;

        // If there's enough room to avoid consecutive-day sessions (needs 2*parts-1 days),
        // prefer a gap of at least 2 days when base gap is 1
        if (gapDays == 1 && totalDays >= (2 * parts - 1)) {
          gapDays = 2;
        }

        // replace the original assignment with its parts in the tracker's list
        try {
          assignments.remove(a);
        } catch (_) {}

        // create part dates, ensuring each part lands on a different day
        var lastDayOffset = 0;
        for (var i = 0; i < parts; i++) {
          // schedule each part at now + offset days
          final offset = lastDayOffset + gapDays;
          final partDue = now.add(Duration(days: offset));
          lastDayOffset = offset;

          final partTitle = '${a.title} (Part ${i + 1}/$parts)';
          final partEst = a.estimatedTime / parts;
          final part = addAssignment(
            partTitle,
            a.subjectName,
            partEst,
            partDue,
            0,
          );
          expanded.add(part);
        }
      } else {
        expanded.add(a);
      }
    }

    expanded.sort((a, b) {
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) {
        if (a.likesSubject != b.likesSubject) return a.likesSubject ? -1 : 1;
        return b.estimatedTime.compareTo(a.estimatedTime);
      } else if (aDue == null) {
        return 1;
      } else if (bDue == null) {
        return -1;
      }

      final cmp = aDue.compareTo(bDue);
      if (cmp != 0) return cmp;

      if (a.likesSubject != b.likesSubject) return a.likesSubject ? -1 : 1;
      return b.estimatedTime.compareTo(a.estimatedTime);
    });

    return expanded;
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

Map<String, dynamic>? parseAssignmentLine(String line) {
  final parts = line.split(',');
  if (parts.length != 4) return null;

  final title = parts[0].trim();
  final estimateString = parts[1].trim();
  final subjectName = parts[2].trim();
  final dueText = parts[3].trim();

  final estimate = double.tryParse(estimateString);
  if (title.isEmpty || subjectName.isEmpty || estimate == null) return null;

  DateTime? dueDate = parseFlexibleDate(dueText);
  if (dueDate == null) return null;

  return {
    'title': title,
    'estimate': estimate.abs(),
    'subject': subjectName,
    'dueDate': dueDate,
  };
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

// Top-level flexible date parser matching the one in main.dart
DateTime? parseFlexibleDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;

  final parts = t.split('/');
  if (parts.length == 3) {
    final m = int.tryParse(parts[0].trim());
    final d = int.tryParse(parts[1].trim());
    var y = int.tryParse(parts[2].trim());
    if (m == null || d == null || y == null) return null;
    if (y < 100) y += 2000;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  return null;
}
