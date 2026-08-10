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

  Assignment(this._title, this._subject, double estimatedTime)
    : _estimatedTime = estimatedTime.abs(),
      _baselineEfficiency = _subject.efficiencyFactor;

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

      final assignment = Assignment(title, subject, estimated);
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
    double actual,
  ) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(title, subject, estimate);
    assignment.complete(actual);
    assignments.add(assignment);
    return assignment;
  }

  Assignment addAssignment(String title, String subjectName, double estimate) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(title, subject, estimate);
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

  Subject getOrCreateSubject(String subjectName) {
    final normalized = subjectName.trim();
    final key = normalized.toLowerCase();
    return _subjects.putIfAbsent(key, () => Subject(normalized, true));
  }

  List<Assignment> scheduleAssignments(List<Assignment> pending) {
    final liked = pending.where((assignment) => assignment.likesSubject).toList();
    final disliked = pending.where((assignment) => !assignment.likesSubject).toList();

    liked.sort((a, b) => b.estimatedTime.compareTo(a.estimatedTime));
    disliked.sort((a, b) => b.estimatedTime.compareTo(a.estimatedTime));

    final schedule = <Assignment>[];
    var nextLike = liked.length >= disliked.length;
    var likeIndex = 0;
    var dislikeIndex = 0;

    while (likeIndex < liked.length || dislikeIndex < disliked.length) {
      if (nextLike) {
        if (likeIndex < liked.length) {
          schedule.add(liked[likeIndex++]);
        } else if (dislikeIndex < disliked.length) {
          schedule.add(disliked[dislikeIndex++]);
        }
      } else {
        if (dislikeIndex < disliked.length) {
          schedule.add(disliked[dislikeIndex++]);
        } else if (likeIndex < liked.length) {
          schedule.add(liked[likeIndex++]);
        }
      }
      nextLike = !nextLike;
    }

    return schedule;
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
