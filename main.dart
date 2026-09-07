import 'dart:convert';
import 'dart:io';

// ============================================================
// Domain model (formerly assignment.dart)
// ============================================================

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
  final bool _spreadOut;

  Assignment(
    this._title,
    this._subject,
    double estimatedTime, [
    DateTime? dueDate,
    int parts = 0,
    bool spreadOut = false,
  ]) : _estimatedTime = estimatedTime.abs(),
       _baselineEfficiency = _subject.efficiencyFactor,
       _dueDate = dueDate,
       _parts = parts,
       _spreadOut = spreadOut;

  double get adjustedEstimate {
    return _estimatedTime * _baselineEfficiency;
  }

  double get estimatedTime => _estimatedTime;

  String get subjectName => _subject.name;
  bool get likesSubject => _subject.likesSubject;

  void complete(double actual) {
    _actualTime = actual.abs();
    _subject.recordCompletion(_estimatedTime, _actualTime!);
  }

  double? get actualTime => _actualTime;
  bool get isCompleted => _actualTime != null;
  String get title => _title;
  DateTime? get dueDate => _dueDate;
  int get parts => _parts;
  // When true, work sessions for a split assignment are spread evenly
  // across every available day instead of being crammed into as few days
  // as realistically possible.
  bool get spreadOut => _spreadOut;
}

class AssignmentTracker {
  final List<Assignment> assignments = [];
  final Map<String, Subject> _subjects = {};
  final List<Subject> allowedSubjects = [];

  // Hour of day (0-23, local time, 24h clock) after which same-day
  // assignments can no longer be added. Defaults to 22 (10:00 PM) and is
  // adjustable from the Profile tab.
  int sameDayCutoffHour = 22;

  AssignmentTracker();

  AssignmentTracker.fromJson(Map<String, dynamic> json) {
    final cutoff = json['sameDayCutoffHour'];
    if (cutoff is num) {
      final hour = cutoff.toInt();
      if (hour >= 0 && hour <= 23) {
        sameDayCutoffHour = hour;
      }
    }

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
      final spreadOut = map['spreadOut'] is bool
          ? map['spreadOut'] as bool
          : false;

      final assignment = Assignment(
        title,
        subject,
        estimated,
        due,
        parts,
        spreadOut,
      );
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

  void updateSameDayCutoffHour(int hour) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Cutoff hour must be between 0 and 23');
    }
    sameDayCutoffHour = hour;
  }

  Map<String, dynamic> toJson() {
    return {
      'sameDayCutoffHour': sameDayCutoffHour,
      'assignments': assignments.map((a) {
        return {
          'title': a.title,
          'subject': a.subjectName,
          'estimated': a.estimatedTime,
          'actual': a.actualTime,
          'dueDate': a.dueDate?.toIso8601String(),
          'parts': a.parts,
          'spreadOut': a.spreadOut,
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
    bool spreadOut = false,
  ]) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(
      title,
      subject,
      estimate,
      dueDate,
      parts,
      spreadOut,
    );
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
    bool spreadOut = false,
  ]) {
    final subject = getOrCreateSubject(subjectName);
    final assignment = Assignment(
      title,
      subject,
      estimate,
      dueDate,
      parts,
      spreadOut,
    );
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
    final today = DateTime(now.year, now.month, now.day);
    final expanded = <Assignment>[];

    for (final a in pending) {
      if (a.parts > 1 && a.dueDate != null) {
        final parts = a.parts;

        // `dueDate` is the actual deadline instant (defaults to 12:00 AM /
        // midnight of the chosen due day, but can carry a later time if the
        // person customized it). Work must be *finished before* that
        // instant, so the last day it can land on is the day before the
        // deadline's calendar day -- unless the deadline has a later
        // time-of-day that leaves room earlier that same day.
        final deadline = a.dueDate!;
        final oneMinuteBeforeDeadline = deadline.subtract(
          const Duration(minutes: 1),
        );
        var lastSchedulableDay = DateTime(
          oneMinuteBeforeDeadline.year,
          oneMinuteBeforeDeadline.month,
          oneMinuteBeforeDeadline.day,
        );
        if (lastSchedulableDay.isBefore(today)) {
          // The deadline has already passed; do the best we can today.
          lastSchedulableDay = today;
        }

        // The first day work can land on: today, if we're still before the
        // configured same-day cutoff, otherwise tomorrow. If that would push
        // past the last schedulable day, fall back to it so we never
        // schedule anything past the deadline.
        var startDay = now.hour < sameDayCutoffHour
            ? today
            : today.add(const Duration(days: 1));
        if (startDay.isAfter(lastSchedulableDay)) {
          startDay = lastSchedulableDay;
        }

        final availableDays =
            lastSchedulableDay.difference(startDay).inDays + 1;

        // compute integer-minute durations for parts that sum to original estimate
        final totalMinutes = a.estimatedTime.round();
        final partMinutesList = <int>[];
        {
          final base = totalMinutes ~/ parts;
          var remainder = totalMinutes % parts;
          for (var i = 0; i < parts; i++) {
            var partMinutes = base;
            if (remainder > 0) {
              partMinutes += 1;
              remainder -= 1;
            }
            partMinutesList.add(partMinutes);
          }
        }

        // Cram as much work as realistically fits on one day before
        // spilling onto the next (default), or spread it evenly across
        // every available day if the person explicitly asked for that via
        // the "spread out" option when adding the assignment.
        final dayOffsets = <int>[];
        if (a.spreadOut) {
          if (availableDays >= parts) {
            for (var i = 0; i < parts; i++) {
              final offset = parts == 1
                  ? 0
                  : (i * (availableDays - 1)) ~/ (parts - 1);
              dayOffsets.add(offset);
            }
          } else {
            final base = parts ~/ availableDays;
            final remainder = parts % availableDays;
            for (var d = 0; d < availableDays; d++) {
              final countForDay = base + (d < remainder ? 1 : 0);
              for (var c = 0; c < countForDay; c++) {
                dayOffsets.add(d);
              }
            }
          }
        } else {
          const maxRealisticDailyMinutes = 180; // ~3 hours/day cap
          var dayOffset = 0;
          var minutesUsedToday = 0;
          for (var i = 0; i < parts; i++) {
            final partMinutes = partMinutesList[i];
            final wouldOverflowDay =
                minutesUsedToday > 0 &&
                minutesUsedToday + partMinutes > maxRealisticDailyMinutes;
            if (wouldOverflowDay && dayOffset < availableDays - 1) {
              dayOffset += 1;
              minutesUsedToday = 0;
            }
            dayOffsets.add(dayOffset);
            minutesUsedToday += partMinutes;
          }
        }

        // For every day that ends up with sessions, work out a start time
        // and a safe spacing so that sessions stacked on the same day never
        // spill past that day's cutoff (23:59, or the exact deadline time if
        // this is the deadline's own calendar day) into the next day.
        final countsByOffset = <int, int>{};
        for (final offset in dayOffsets) {
          countsByOffset[offset] = (countsByOffset[offset] ?? 0) + 1;
        }
        final dayStart = <int, DateTime>{};
        final dayIntervalMinutes = <int, int>{};
        countsByOffset.forEach((offset, count) {
          final sessionDay = startDay.add(Duration(days: offset));
          final start = isSameLocalDate(sessionDay, now)
              ? now
              : DateTime(sessionDay.year, sessionDay.month, sessionDay.day, 9);
          final windowEnd = isSameLocalDate(sessionDay, deadline)
              ? deadline
              : DateTime(
                  sessionDay.year,
                  sessionDay.month,
                  sessionDay.day,
                  23,
                  59,
                );
          final availableMinutes = windowEnd.isAfter(start)
              ? windowEnd.difference(start).inMinutes
              : 0;
          final interval = count <= 1
              ? 0
              : (availableMinutes ~/ (count - 1)).clamp(0, 60);
          dayStart[offset] = start;
          dayIntervalMinutes[offset] = interval;
        });

        // replace the original assignment with its parts in the tracker's list
        try {
          assignments.remove(a);
        } catch (_) {}

        final sessionsOnDay = <int, int>{};
        for (var i = 0; i < parts; i++) {
          final partMinutes = partMinutesList[i];

          final offsetForPart = dayOffsets[i];
          final sessionIndex = sessionsOnDay.update(
            offsetForPart,
            (v) => v + 1,
            ifAbsent: () => 0,
          );
          final partDue = dayStart[offsetForPart]!.add(
            Duration(
              minutes: dayIntervalMinutes[offsetForPart]! * sessionIndex,
            ),
          );

          final partTitle = '${a.title} (Part ${i + 1}/$parts)';
          final partEst = partMinutes.toDouble();
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

// ============================================================
// App logic (formerly main.dart)
// ============================================================

String stateFilePath() {
  final scriptPath = Platform.script.toFilePath();
  final dir = File(scriptPath).parent.path;
  return '$dir/assignment_state.json';
}

AssignmentTracker loadTracker() {
  final file = File(stateFilePath());

  if (!file.existsSync()) {
    return AssignmentTracker();
  }

  final text = file.readAsStringSync();
  if (text.trim().isEmpty) {
    return AssignmentTracker();
  }

  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) {
    return AssignmentTracker.fromJson(decoded);
  }

  return AssignmentTracker();
}

void saveTracker(AssignmentTracker tracker) {
  final file = File(stateFilePath());
  file.writeAsStringSync(jsonEncode(tracker.toJson()), flush: true);
}

class ActiveTimer {
  DateTime? startedAt;
  double elapsedMinutes = 0;
}

bool isSameLocalDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool isAllowedDueDate(DateTime dueDate, DateTime now, [int cutoffHour = 22]) {
  if (dueDate.isBefore(DateTime(now.year, now.month, now.day))) {
    return false;
  }
  return !isSameLocalDate(dueDate, now) || now.hour < cutoffHour;
}

/// Formats an hour (0-23) as a friendly 12-hour clock label, e.g. 22 -> "10:00 PM".
String formatHourLabel(int hour) {
  final normalized = hour % 24;
  final period = normalized >= 12 ? 'PM' : 'AM';
  var displayHour = normalized % 12;
  if (displayHour == 0) displayHour = 12;
  return '$displayHour:00 $period';
}

DateTime? parseFlexibleDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;

  // Accept M/D/YY or M/D/YYYY (e.g. 8/9/26 => 2026-08-09)
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

List<String>? parseSubjectsLine(String line) {
  final subjects = line
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList();

  return subjects.isEmpty ? null : subjects;
}

bool promptSubjectLike(String subjectName) {
  while (true) {
    stdout.write('Do you like "$subjectName"? (y/n): ');
    final input = stdin.readLineSync();
    if (input == null) {
      continue;
    }
    final value = input.trim().toLowerCase();
    if (value == 'y' || value == 'yes') {
      return true;
    }
    if (value == 'n' || value == 'no') {
      return false;
    }
    print('Please answer "y" or "n".');
  }
}

List<Subject> promptSubjects() {
  while (true) {
    stdout.write(
      "Enter allowed subjects as comma-separated values (e.g. Math, English): ",
    );
    final input = stdin.readLineSync();
    final subjectNames = input == null ? null : parseSubjectsLine(input);
    if (subjectNames == null || subjectNames.isEmpty) {
      print('Enter at least one valid subject.');
      continue;
    }

    return subjectNames.map((subjectName) {
      final likes = promptSubjectLike(subjectName);
      return Subject(subjectName, likes);
    }).toList();
  }
}

Map<String, dynamic>? parseAssignmentLine(String line) {
  final parts = line.split(',');
  if (parts.length != 4) {
    return null;
  }

  final title = parts[0].trim();
  final estimateText = parts[1].trim();
  final subjectName = parts[2].trim();
  final dueText = parts[3].trim();

  final estimate = double.tryParse(estimateText);
  if (title.isEmpty || subjectName.isEmpty || estimate == null) {
    return null;
  }

  DateTime? dueDate;
  if (dueText.isNotEmpty) {
    dueDate = parseFlexibleDate(dueText);
    if (dueDate == null) return null;
  }

  return {
    'title': title,
    'estimate': estimate.abs(),
    'subject': subjectName,
    'dueDate': dueDate,
  };
}

double measureActualTimeMinutes() {
  stdout.write('Press Enter to start the timer...');
  stdin.readLineSync();

  final start = DateTime.now();

  stdout.write(
    'Timer started. Press Enter again when the assignment is finished...',
  );
  stdin.readLineSync();

  final end = DateTime.now();
  final elapsedSeconds = end.difference(start).inSeconds;
  return (elapsedSeconds / 60.0).abs();
}

String? normalizeSubject(String subject, List<Subject> allowedSubjects) {
  final normalized = subject.trim().toLowerCase();
  for (final allowed in allowedSubjects) {
    if (allowed.name.toLowerCase() == normalized) {
      return allowed.name;
    }
  }
  return null;
}

void cliMain() {
  final tracker = loadTracker();
  final allowedSubjects = tracker.allowedSubjects.isNotEmpty
      ? tracker.allowedSubjects
      : promptSubjects();

  if (tracker.allowedSubjects.isEmpty) {
    tracker.updateAllowedSubjects(allowedSubjects);
    saveTracker(tracker);
  }

  final pendingAssignments = tracker.pendingAssignments;

  print('Storage file: ${stateFilePath()}');
  print(
    'Allowed subjects: ${allowedSubjects.map((subject) => '${subject.name} (${subject.likesSubject ? 'liked' : 'not liked'})').join(', ')}',
  );
  if (pendingAssignments.isNotEmpty) {
    print('Found ${pendingAssignments.length} unfinished assignment(s).');
  }

  while (true) {
    stdout.write(
      "Enter assignment as 'Name, Time, Subject, DueDate(YYYY-MM-DD or ISO)' or type 'start' or 'quit': ",
    );
    final input = stdin.readLineSync();
    if (input == null) {
      continue;
    }

    final value = input.trim();
    final lower = value.toLowerCase();

    if (lower == 'quit') {
      saveTracker(tracker);
      print('Saved state and exited.');
      return;
    }

    if (lower == 'start') {
      if (pendingAssignments.isEmpty) {
        print('No assignments entered yet.');
        continue;
      }
      break;
    }

    final parsed = parseAssignmentLine(value);
    if (parsed == null) {
      print(
        'Invalid format. Use: Name, Time, Subject, DueDate(YYYY-MM-DD or ISO)',
      );
      continue;
    }

    final normalizedSubject = normalizeSubject(
      parsed['subject'] as String,
      allowedSubjects,
    );
    if (normalizedSubject == null) {
      print(
        'Subject must match one of: ${allowedSubjects.map((subject) => subject.name).join(', ')}',
      );
      continue;
    }

    // Compute default parts: split into ~45-minute parts if estimated >= 90 minutes
    int parts = 0;
    final est = (parsed['estimate'] as double).abs();
    if (est >= 90.0) {
      final ratio = est / 45.0;
      parts = ratio.round();
      if (parts < 2) parts = 2;
    }

    final newAssignment = tracker.addAssignment(
      parsed['title'] as String,
      normalizedSubject,
      parsed['estimate'] as double,
      parsed['dueDate'] as DateTime?,
      parts,
    );
    pendingAssignments.add(newAssignment);
    print('Queued assignment: ${parsed['title']}');
  }

  final scheduledAssignments = tracker.scheduleAssignments(pendingAssignments);

  exportToIcs(scheduledAssignments);

  for (int i = 0; i < scheduledAssignments.length; i++) {
    final assignment = scheduledAssignments[i];
    final title = assignment.title;

    print('\nTiming assignment #${i + 1}: $title');
    final actual = measureActualTimeMinutes();

    tracker.completePendingAssignment(assignment, actual);

    saveTracker(tracker);

    print('Saved assignment to file.');
    print('Title: ${assignment.title}');
    print(
      'Original Estimate: ${assignment.estimatedTime.toStringAsFixed(2)} min',
    );
    print(
      'Adjusted Estimate: ${assignment.adjustedEstimate.toStringAsFixed(2)} min',
    );
    final actualText = assignment.actualTime != null
        ? assignment.actualTime!.toStringAsFixed(2)
        : 'N/A';
    print('Actual Time: $actualText min');
    print('Subject: ${assignment.subjectName}');
  }

  print('\nAll assignments completed.');
}

String _formatICalDate(DateTime dt) {
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

void exportToIcs(List<Assignment> assignments) {
  final filePath = stateFilePath();
  final dir = File(filePath).parent.path;
  final out = StringBuffer();
  out.writeln('BEGIN:VCALENDAR');
  out.writeln('VERSION:2.0');
  out.writeln('PRODID:-//Fatigue Scheduler//EN');

  for (var i = 0; i < assignments.length; i++) {
    final a = assignments[i];
    if (a.dueDate == null) continue;
    final start = a.dueDate!;
    final durationMinutes = a.estimatedTime.round();
    final end = start.add(Duration(minutes: durationMinutes));
    final uid = 'assign-${i}-${start.millisecondsSinceEpoch}@fatigue-scheduler';

    out.writeln('BEGIN:VEVENT');
    out.writeln('UID:$uid');
    out.writeln('DTSTAMP:${_formatICalDate(DateTime.now())}');
    out.writeln('DTSTART:${_formatICalDate(start)}');
    out.writeln('DTEND:${_formatICalDate(end)}');
    out.writeln('SUMMARY:${a.title}');
    out.writeln('DESCRIPTION:Subject=${a.subjectName}');
    out.writeln('END:VEVENT');
  }

  out.writeln('END:VCALENDAR');

  final file = File('$dir/assignments_calendar.ics');
  try {
    file.writeAsStringSync(out.toString(), flush: true);
    print('Exported calendar to ${file.path}');
  } catch (e) {
    print('Failed to write calendar file: $e');
  }
}

Future<void> main(List<String> args) async {
  if (args.contains('--cli')) {
    cliMain();
    return;
  }

  final tracker = loadTracker();
  final activeTimers = <String, ActiveTimer>{};
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final url = 'http://localhost:${server.port}';

  server.listen((request) async {
    if (request.method == 'GET') {
      request.response
        ..headers.contentType = ContentType.html
        ..write(phoneAppHtml(tracker.toJson()))
        ..close();
    } else if (request.method == 'POST' && request.uri.path == '/subjects') {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final likedNames = (data['likes'] ?? '')
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      final dislikedNames = (data['dislikes'] ?? '')
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (likedNames.isEmpty && dislikedNames.isEmpty) {
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write('{"ok":false,"error":"Enter at least one subject"}')
          ..close();
        return;
      }

      tracker.updateAllowedSubjects([
        ...likedNames.map((name) => Subject(name, true)),
        ...dislikedNames.map((name) => Subject(name, false)),
      ]);
      saveTracker(tracker);
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}')
        ..close();
    } else if (request.method == 'POST' && request.uri.path == '/settings') {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final hour = int.tryParse(data['sameDayCutoffHour'] ?? '');

      if (hour == null || hour < 0 || hour > 23) {
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write('{"ok":false,"error":"Enter an hour between 0 and 23"}')
          ..close();
        return;
      }

      tracker.updateSameDayCutoffHour(hour);
      saveTracker(tracker);
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}')
        ..close();
    } else if (request.method == 'POST' &&
        request.uri.path == '/delete-subject') {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final subjectName = (data['subject'] ?? '').trim();
      final subjectKey = subjectName.toLowerCase();
      final subjectExists = tracker.allowedSubjects.any(
        (subject) => subject.name.toLowerCase() == subjectKey,
      );

      if (!subjectExists) {
        request.response
          ..statusCode = 404
          ..headers.contentType = ContentType.json
          ..write('{"ok":false,"error":"Subject not found"}')
          ..close();
        return;
      }

      final remainingSubjects = tracker.allowedSubjects
          .where((subject) => subject.name.toLowerCase() != subjectKey)
          .toList();
      final assignmentsRemoved = tracker.assignments
          .where(
            (assignment) => assignment.subjectName.toLowerCase() == subjectKey,
          )
          .length;
      tracker.assignments.removeWhere(
        (assignment) => assignment.subjectName.toLowerCase() == subjectKey,
      );
      tracker.updateAllowedSubjects(remainingSubjects);
      saveTracker(tracker);
      exportToIcs(tracker.pendingAssignments);
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({'ok': true, 'assignmentsRemoved': assignmentsRemoved}),
        )
        ..close();
    } else if (request.method == 'POST' && request.uri.path == '/add') {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final title = data['title'] ?? 'Assignment';
      final subject = data['subject'] ?? 'Study';
      final estimated = double.tryParse(data['estimated'] ?? '0') ?? 0;
      final subjectExists = tracker.allowedSubjects.any(
        (saved) => saved.name.toLowerCase() == subject.trim().toLowerCase(),
      );
      if (!subjectExists) {
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write('{"ok":false,"error":"Subject does not exist"}')
          ..close();
        return;
      }
      final dueDate = data['dueDate'] == null || data['dueDate']!.isEmpty
          ? null
          : DateTime.tryParse(data['dueDate']!);
      if (dueDate == null ||
          !isAllowedDueDate(
            dueDate,
            DateTime.now(),
            tracker.sameDayCutoffHour,
          )) {
        final cutoffLabel = formatHourLabel(tracker.sameDayCutoffHour);
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'ok': false,
              'error':
                  "Today's tasks must be added before $cutoffLabel local time, and the date cannot be in the past",
            }),
          )
          ..close();
        return;
      }
      final parts = estimated >= 90
          ? (estimated / 45).round().clamp(2, 100)
          : 0;
      final spreadOut = data['spreadOut'] == '1' || data['spreadOut'] == 'true';
      tracker.addAssignment(
        title,
        subject,
        estimated,
        dueDate,
        parts,
        spreadOut,
      );
      tracker.scheduleAssignments(tracker.pendingAssignments);
      saveTracker(tracker);
      exportToIcs(tracker.pendingAssignments);
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}')
        ..close();
    } else if (request.method == 'POST' &&
        (request.uri.path == '/start' ||
            request.uri.path == '/pause' ||
            request.uri.path == '/complete')) {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final title = data['title'] ?? '';
      final dueDate = data['dueDate'] ?? '';
      final key = '$title|$dueDate';
      final assignment = tracker.assignments.cast<Assignment?>().firstWhere(
        (item) =>
            item!.actualTime == null &&
            item.title == title &&
            (item.dueDate?.toIso8601String() ?? '') == dueDate,
        orElse: () => null,
      );

      if (assignment == null) {
        request.response
          ..statusCode = 404
          ..headers.contentType = ContentType.json
          ..write('{"ok":false,"error":"Assignment not found"}')
          ..close();
        return;
      }

      if (request.uri.path == '/start') {
        final timer = activeTimers.putIfAbsent(key, ActiveTimer.new);
        timer.startedAt = DateTime.now();
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}')
          ..close();
      } else if (request.uri.path == '/pause') {
        final timer = activeTimers[key];
        if (timer == null || timer.startedAt == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write('{"ok":false,"error":"Timer is not running"}')
            ..close();
          return;
        }
        timer.elapsedMinutes +=
            DateTime.now().difference(timer.startedAt!).inSeconds / 60.0;
        timer.startedAt = null;
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true, 'elapsed': timer.elapsedMinutes}))
          ..close();
      } else {
        final timer = activeTimers.remove(key);
        if (timer == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write('{"ok":false,"error":"Timer was not started"}')
            ..close();
          return;
        }
        var elapsedMinutes = timer.elapsedMinutes;
        if (timer.startedAt != null) {
          elapsedMinutes +=
              DateTime.now().difference(timer.startedAt!).inSeconds / 60.0;
        }
        tracker.completePendingAssignment(assignment, elapsedMinutes);
        tracker.assignments.remove(assignment);
        saveTracker(tracker);
        exportToIcs(tracker.pendingAssignments);
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true, 'actual': elapsedMinutes}))
          ..close();
      }
    } else {
      request.response.statusCode = 404;
      request.response.close();
    }
  });

  print('Nimbus Compass is running at $url');
  try {
    await Process.run('open', ['-a', 'Google Chrome', url]);
  } catch (_) {
    print('Open $url in Chrome.');
  }
}

String phoneAppHtml(Map<String, dynamic> state) {
  final encodedState = jsonEncode(state).replaceAll('<', r'\u003c');
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Nimbus Compass</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap');
:root{--ink:#182334;--muted:#758196;--blue:#4777ee;--pale:#edf3ff;--mint:#d9f5ed;--coral:#ff876e;--line:#e9edf3;--paper:#fbfcff}
*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 20% 10%,#dce8ff 0,transparent 32%),linear-gradient(135deg,#eaf0fa,#f8efe8);font-family:'DM Sans',sans-serif;color:var(--ink);display:grid;place-items:center;padding:32px}
.phone{width:min(100%,390px);height:min(820px,calc(100vh - 40px));min-height:680px;background:var(--paper);border:9px solid #141c2c;border-radius:42px;box-shadow:0 26px 70px #34415c38,0 0 0 2px #fff;overflow:hidden;position:relative}
.phone:before{content:'';position:absolute;z-index:5;top:8px;left:50%;transform:translateX(-50%);width:92px;height:22px;border-radius:0 0 16px 16px;background:#141c2c}.screen{height:100%;overflow:auto;padding:38px 21px 22px;scrollbar-width:none}.screen::-webkit-scrollbar{display:none}
.status{display:flex;justify-content:space-between;font-size:11px;font-weight:700;margin:0 3px 19px}.top{display:flex;justify-content:space-between;align-items:center;margin-bottom:22px}.eyebrow{font-size:12px;color:var(--muted);font-weight:600}.brand{font:700 25px 'Space Grotesk';letter-spacing:-.8px;margin-top:3px}.avatar{width:39px;height:39px;border-radius:50%;background:#ffcdb8;display:grid;place-items:center;font-weight:700;color:#a14d3b}.hero{background:linear-gradient(135deg,#4b7bf1,#6f95f7);border-radius:24px;padding:21px;color:white;position:relative;overflow:hidden;box-shadow:0 12px 24px #4777ee31}.hero:after{content:'';position:absolute;width:145px;height:145px;border:22px solid #ffffff20;border-radius:50%;right:-42px;top:-48px}.hero h1{font:600 21px 'Space Grotesk';margin:0 0 8px}.hero p{font-size:13px;line-height:1.5;margin:0;width:73%;color:#e9efff}.progress{margin-top:19px;background:#ffffff35;height:7px;border-radius:8px;overflow:hidden}.progress i{display:block;width:64%;height:100%;background:white;border-radius:8px}.hero small{display:block;margin-top:8px;color:#dbe5ff;font-size:11px}.section-head{display:flex;justify-content:space-between;align-items:center;margin:25px 2px 13px}.section-head h2{font:600 17px 'Space Grotesk';margin:0}.section-head span{color:var(--blue);font-size:12px;font-weight:700}.task{display:flex;gap:12px;padding:14px 12px;background:white;border:1px solid var(--line);border-radius:17px;margin-bottom:10px;box-shadow:0 4px 12px #384b7410}.dot{width:11px;height:11px;border-radius:50%;background:var(--coral);margin-top:4px;flex:none}.dot.green{background:#53c59f}.task h3{font-size:14px;margin:0 0 5px}.task p{margin:0;color:var(--muted);font-size:11px}.time{margin-left:auto;white-space:nowrap;font-size:11px;color:var(--muted);font-weight:600}.week{display:grid;grid-template-columns:repeat(7,1fr);gap:6px}.day{height:54px;border-radius:13px;background:#f4f6fa;text-align:center;padding-top:8px;font-size:10px;color:var(--muted)}.day b{display:block;color:var(--ink);font-size:15px;margin-top:5px}.day.active{background:var(--ink);color:white}.day.active b{color:white}.bottom{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;background:white;border-top:1px solid var(--line);padding:13px 4px 4px;margin:23px -21px -22px;position:sticky;bottom:-22px}.nav{border:0;background:transparent;color:#9aa5b7;font:600 10px 'DM Sans';display:grid;gap:5px;justify-items:center;padding:5px;cursor:pointer}.nav .ico{font-size:19px;line-height:1}.nav.selected{color:var(--blue)}.add{position:absolute;right:23px;bottom:74px;width:52px;height:52px;border:0;border-radius:18px;background:var(--coral);color:white;font-size:27px;box-shadow:0 10px 20px #ff876e55;cursor:pointer}.fade{animation:rise .65s both}@keyframes rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}.modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.4);z-index:100;align-items:center;justify-content:center}.modal.open{display:flex}.modal-box{background:var(--paper);border-radius:24px;padding:24px;width:min(340px,90%);box-shadow:0 20px 60px rgba(0,0,0,.3)}.modal h2{font:600 18px 'Space Grotesk';margin:0 0 18px}.modal input{width:100%;padding:11px 13px;margin-bottom:12px;border:1px solid var(--line);border-radius:12px;font:14px 'DM Sans';color:var(--ink)}.modal input:focus{outline:none;border-color:var(--blue)}.modal-buttons{display:flex;gap:10px}.modal-buttons button{flex:1;padding:11px;border:1px solid var(--line);border-radius:10px;font:600 13px 'DM Sans';cursor:pointer}.modal-buttons .btn-cancel{background:white;color:var(--ink)}.modal-buttons .btn-add{background:var(--coral);border-color:var(--coral);color:white}
<style>.day-header{height:20px;text-align:center;font-size:10px;font-weight:700;color:var(--muted)}.calendar-day{height:62px;padding:7px 3px;overflow:hidden}.calendar-day span{display:block;font-weight:700;color:var(--ink)}.calendar-day small{display:block;margin-top:4px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;font-size:8px;color:var(--blue)}.calendar-day.has-event{background:var(--pale)}.calendar-day.active{background:var(--ink)}.calendar-day.active span,.calendar-day.active small{color:white}.blank{visibility:hidden}</style></head><body><main class="phone"><section class="screen"><div class="status"><span>9:41</span><span>● ● ▰</span></div><div class="top"><div><div class="eyebrow">Thursday, August 20</div><div class="brand">Nimbus Compass</div></div><div class="avatar">KL</div></div><article class="hero fade"><h1>Keep your momentum.</h1><p>A calmer study plan, built around your energy and your deadlines.</p><div class="progress"><i></i></div><small>3 of 5 focus sessions completed</small></article><div class="section-head"><h2>This week</h2><span>August 2026</span></div><div class="week fade" id="calendarGrid"></div><div class="section-head"><h2>Today</h2><span>View calendar</span></div><div id="tasks"></div><button class="add" aria-label="Add assignment" id="addBtn">+</button><div class="modal" id="addModal"><div class="modal-box"><h2>New Assignment</h2><input type="text" id="titleInput" placeholder="Assignment name" autocomplete="off"><input type="text" id="subjectInput" placeholder="Subject" autocomplete="off"><input type="number" id="timeInput" placeholder="Time (minutes)" min="0" autocomplete="off"><div class="modal-buttons"><button class="btn-cancel" id="cancelBtn">Cancel</button><button class="btn-add" id="submitBtn">Add</button></div></div></div><nav class="bottom"><button class="nav selected"><span class="ico">⌂</span>Today</button><button class="nav"><span class="ico">▦</span>Calendar</button><button class="nav"><span class="ico">◷</span>Focus</button><button class="nav"><span class="ico">◌</span>Profile</button></nav></section></main><script>
const state=$encodedState;
if(!(state.allowedSubjects||[]).length){
  const overlay=document.createElement('div');
  overlay.style='position:fixed;inset:0;background:rgba(24,35,52,.55);z-index:200;display:grid;place-items:center;padding:24px';
  overlay.innerHTML='<div style="background:#fbfcff;border-radius:24px;padding:24px;width:min(340px,100%);box-shadow:0 20px 60px rgba(0,0,0,.3)"><h2 style="font:600 20px Space Grotesk;margin:0 0 8px;color:#182334">Set up your subjects</h2><p style="font:13px DM Sans;margin:0 0 14px;color:#758196;line-height:1.5">Enter subjects as comma-separated values.</p><label style="display:block;font:600 12px DM Sans;color:#182334;margin-bottom:6px">Likes</label><input id="likesCsv" placeholder="Math, English" autofocus style="width:100%;padding:12px;border:1px solid #e9edf3;border-radius:12px;font:14px DM Sans"><label style="display:block;font:600 12px DM Sans;color:#182334;margin:14px 0 6px">Dislikes</label><input id="dislikesCsv" placeholder="History, Chemistry" style="width:100%;padding:12px;border:1px solid #e9edf3;border-radius:12px;font:14px DM Sans"><button id="saveSubjects" style="width:100%;margin-top:16px;padding:12px;border:0;border-radius:12px;background:#4777ee;color:white;font:600 13px DM Sans;cursor:pointer">Save subjects</button><p id="subjectError" style="color:#c84f45;font:12px DM Sans;margin:10px 0 0"></p></div>';
  document.body.appendChild(overlay);
  const likesCsv=document.getElementById('likesCsv');
  const dislikesCsv=document.getElementById('dislikesCsv');
  const saveSubjects=document.getElementById('saveSubjects');
  const subjectError=document.getElementById('subjectError');
  saveSubjects.addEventListener('click',async()=>{
    const likes=likesCsv.value.trim();
    const dislikes=dislikesCsv.value.trim();
    if(!likes&&!dislikes){subjectError.textContent='Enter at least one subject.';return}
    saveSubjects.disabled=true;
    try{
      const response=await fetch('/subjects',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({likes,dislikes})});
      const result=await response.json();
      if(!response.ok||!result.ok)throw new Error(result.error||'Could not save subjects');
      location.reload();
    }catch(error){subjectError.textContent=error.message;saveSubjects.disabled=false}
  });
}
const tasks=document.getElementById('tasks');
const tomorrowHeading=document.createElement('div');
tomorrowHeading.className='section-head';
tomorrowHeading.innerHTML='<h2>Tomorrow</h2>';
const tomorrowTasks=document.createElement('div');
tomorrowTasks.id='tomorrowTasks';
const workListHeading=document.createElement('div');
workListHeading.className='section-head';
workListHeading.innerHTML='<h2>Work List</h2>';
const workTasks=document.createElement('div');
workTasks.id='workTasks';
tasks.after(tomorrowHeading,tomorrowTasks,workListHeading,workTasks);
const profileSubjectsHeading=document.createElement('div');
profileSubjectsHeading.className='section-head';
profileSubjectsHeading.innerHTML='<h2>Subjects</h2>';
const profileSubjects=document.createElement('div');
profileSubjects.id='profileSubjects';
profileSubjects.innerHTML='<p style="color:#c84f45;font:12px DM Sans;margin:0 0 12px">Deleting a subject also deletes every assignment with that subject.</p>'+(state.allowedSubjects||[]).map(subject=>'<div class="task"><span class="dot '+(subject.likes?'green':'')+'"></span><div><h3>'+escapeHtml(subject.name)+'</h3><p>'+(subject.likes?'Like':'Dislike')+'</p></div><button class="delete-subject" data-subject="'+escapeHtml(subject.name)+'" style="margin-left:auto;border:0;border-radius:9px;background:#fff0ee;color:#c84f45;font:600 11px DM Sans;padding:7px 9px;cursor:pointer">Delete</button></div>').join('');
workTasks.after(profileSubjectsHeading,profileSubjects);
function cutoffHourLabel(hour){const normalized=((hour%24)+24)%24;const period=normalized>=12?'PM':'AM';let displayHour=normalized%12;if(displayHour===0)displayHour=12;return displayHour+':00 '+period}
const profileSchedulingHeading=document.createElement('div');
profileSchedulingHeading.className='section-head';
profileSchedulingHeading.innerHTML='<h2>Scheduling</h2>';
const profileScheduling=document.createElement('div');
profileScheduling.id='profileScheduling';
const currentCutoffHour=Number.isFinite(state.sameDayCutoffHour)?state.sameDayCutoffHour:22;
const cutoffOptions=Array.from({length:24},(_,hour)=>'<option value="'+hour+'"'+(hour===currentCutoffHour?' selected':'')+'>'+cutoffHourLabel(hour)+'</option>').join('');
profileScheduling.innerHTML='<div class="task" style="align-items:flex-start"><div style="width:100%"><h3>Same-day cutoff</h3><p style="margin-bottom:10px">Latest local time you can still add a task due today.</p><select id="cutoffSelect" style="width:100%;padding:11px 13px;border:1px solid #e9edf3;border-radius:12px;font:14px DM Sans;color:#182334">'+cutoffOptions+'</select><button id="saveCutoff" style="width:100%;margin-top:10px;padding:11px;border:0;border-radius:10px;background:#4777ee;color:white;font:600 13px DM Sans;cursor:pointer">Save</button><p id="cutoffError" style="color:#c84f45;font:12px DM Sans;margin:8px 0 0"></p></div></div>';
profileSubjects.after(profileSchedulingHeading,profileScheduling);
document.getElementById('saveCutoff').addEventListener('click',async()=>{
  const select=document.getElementById('cutoffSelect');
  const errorEl=document.getElementById('cutoffError');
  const saveBtn=document.getElementById('saveCutoff');
  errorEl.textContent='';
  saveBtn.disabled=true;
  try{
    const response=await fetch('/settings',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({sameDayCutoffHour:select.value})});
    const result=await response.json();
    if(!response.ok||!result.ok)throw new Error(result.error||'Could not save setting');
    location.reload();
  }catch(error){errorEl.textContent=error.message;saveBtn.disabled=false}
});
document.querySelectorAll('.delete-subject').forEach(button=>button.addEventListener('click',async()=>{
  const subject=button.dataset.subject;
  if(!confirm('Delete '+subject+' and all assignments with this subject?'))return;
  button.disabled=true;
  try{
    const response=await fetch('/delete-subject',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({subject})});
    const result=await response.json();
    if(!response.ok||!result.ok)throw new Error(result.error||'Could not delete subject');
    location.reload();
  }catch(error){alert(error.message);button.disabled=false}
}));
const modal=document.getElementById('addModal');
const addBtn=document.getElementById('addBtn');
const cancelBtn=document.getElementById('cancelBtn');
const submitBtn=document.getElementById('submitBtn');
const titleInput=document.getElementById('titleInput');
const subjectInput=document.getElementById('subjectInput');
const timeInput=document.getElementById('timeInput');
const subjectError=document.createElement('div');
subjectError.id='subjectError';
subjectError.style='display:none;color:#c84f45;font:12px DM Sans;margin:-6px 0 10px';
subjectInput.insertAdjacentElement('afterend',subjectError);
const dueDateInput=document.createElement('input');
dueDateInput.type='date';
dueDateInput.id='dueDateInput';
dueDateInput.setAttribute('aria-label','Deadline date');
const localToday=new Date();
const localTodayValue=localToday.getFullYear()+'-'+String(localToday.getMonth()+1).padStart(2,'0')+'-'+String(localToday.getDate()).padStart(2,'0');
dueDateInput.min=localTodayValue;
dueDateInput.value=localTodayValue;
const deadlineLabel=document.createElement('div');
deadlineLabel.textContent='Deadline';
deadlineLabel.style='font:600 12px DM Sans;color:#182334;margin:4px 0 4px';
timeInput.insertAdjacentElement('afterend',deadlineLabel);
deadlineLabel.insertAdjacentElement('afterend',dueDateInput);
const deadlineTimeInput=document.createElement('input');
deadlineTimeInput.type='time';
deadlineTimeInput.id='deadlineTimeInput';
deadlineTimeInput.setAttribute('aria-label','Deadline time');
deadlineTimeInput.value='23:59';
deadlineTimeInput.style='margin-top:8px';
dueDateInput.insertAdjacentElement('afterend',deadlineTimeInput);
const deadlineHint=document.createElement('p');
deadlineHint.textContent='Defaults to 12:00 AM on the date above — work must be finished by the end of the previous day. Adjust the time if this task can run later that day instead.';
deadlineHint.style='font:11px DM Sans;color:#758196;margin:6px 0 12px;line-height:1.4';
deadlineTimeInput.insertAdjacentElement('afterend',deadlineHint);
const spreadOutLabel=document.createElement('label');
spreadOutLabel.style='display:flex;align-items:center;gap:8px;margin:2px 0 14px;font:13px DM Sans;color:#182334;cursor:pointer';
const spreadOutInput=document.createElement('input');
spreadOutInput.type='checkbox';
spreadOutInput.id='spreadOutInput';
spreadOutInput.style='width:auto;margin:0';
spreadOutLabel.appendChild(spreadOutInput);
spreadOutLabel.appendChild(document.createTextNode('Spread out instead of cramming into one day'));
deadlineHint.insertAdjacentElement('afterend',spreadOutLabel);
submitBtn.addEventListener('click',async()=>{const title=titleInput.value.trim();const subject=subjectInput.value.trim();const estimated=timeInput.value.trim();const dueDate=dueDateInput.value;const deadlineTime=deadlineTimeInput.value||'00:00';const spreadOut=spreadOutInput.checked;const knownSubjects=(state.allowedSubjects||[]).map(item=>String(item.name).toLowerCase());subjectError.style.display='none';if(!knownSubjects.includes(subject.toLowerCase())){subjectError.textContent='Subject does not exist. Choose one of your saved subjects.';subjectError.style.display='block';return}if(!title||!subject||!estimated||!dueDate){alert('Please fill in all fields');return}const now=new Date();const todayValue=now.getFullYear()+'-'+String(now.getMonth()+1).padStart(2,'0')+'-'+String(now.getDate()).padStart(2,'0');const cutoffHour=Number.isFinite(state.sameDayCutoffHour)?state.sameDayCutoffHour:22;if(dueDate<todayValue){alert('The due date cannot be in the past.');return}if(dueDate===todayValue&&now.getHours()>=cutoffHour){alert('Tasks for today must be added before '+cutoffHourLabel(cutoffHour)+' local time.');return}const deadline=dueDate+'T'+deadlineTime+':00';const params=new URLSearchParams({title,subject,estimated,dueDate:deadline,spreadOut:spreadOut?'1':'0'});try{const res=await fetch('/add',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:params});const result=await res.json();if(!res.ok||!result.ok)throw new Error(result.error||'Could not add assignment');modal.classList.remove('open');titleInput.value='';subjectInput.value='';timeInput.value='';dueDateInput.value=localTodayValue;deadlineTimeInput.value='00:00';spreadOutInput.checked=false;location.reload()}catch(e){subjectError.textContent=e.message;subjectError.style.display='block'}});
const calendarGrid=document.getElementById('calendarGrid');
const sectionHeads=[...document.querySelectorAll('.section-head')];
const listContent=[tasks,tomorrowTasks,workTasks,sectionHeads[1],tomorrowHeading,workListHeading];
const homeContent=[...document.querySelectorAll('.top,.hero'),...listContent];
const profileContent=[...listContent,profileSubjectsHeading,profileSubjects,profileSchedulingHeading,profileScheduling];
const calendarContent=[sectionHeads[0],calendarGrid];
const addButton=document.getElementById('addBtn');
calendarContent.forEach(item=>item.hidden=true);
sectionHeads[0].style.display='none';
calendarGrid.style.display='none';
sectionHeads[1].style.display='flex';
tomorrowHeading.style.display='flex';
workListHeading.style.display='flex';
profileSubjectsHeading.style.display='none';
profileSubjects.style.display='none';
profileSchedulingHeading.style.display='none';
profileScheduling.style.display='none';
document.querySelectorAll('.nav').forEach(nav=>nav.addEventListener('click',()=>{
  const label=nav.textContent.trim();
  const isToday=label.includes('Today');
  const isCalendar=label.includes('Calendar');
  const isProfile=label.includes('Profile');
  document.querySelectorAll('.nav').forEach(item=>item.classList.remove('selected'));
  nav.classList.add('selected');
  homeContent.forEach(item=>item.hidden=!isToday);
  listContent.forEach(item=>item.hidden=!(isToday||isProfile));
  profileContent.forEach(item=>item.hidden=!isProfile);
  calendarContent.forEach(item=>item.hidden=!isCalendar);
  sectionHeads[1].style.display=(isToday||isProfile)?'flex':'none';
  tomorrowHeading.style.display=(isToday||isProfile)?'flex':'none';
  workListHeading.style.display=(isToday||isProfile)?'flex':'none';
  profileSubjectsHeading.style.display=isProfile?'flex':'none';
  profileSubjects.style.display=isProfile?'block':'none';
  profileSchedulingHeading.style.display=isProfile?'flex':'none';
  profileScheduling.style.display=isProfile?'block':'none';
  sectionHeads[0].style.display=isCalendar?'flex':'none';
  calendarGrid.style.display=isCalendar?'grid':'none';
  addButton.hidden=!isToday;
}));
const saved=(state.assignments||[]).filter(a=>!a.actual);
function assignmentRoot(title){const value=String(title||'');const marker=' (Part ';const index=value.indexOf(marker);return index<0?value:value.slice(0,index)}
function assignmentOrder(a,b){
  const aDate=a.dueDate?new Date(a.dueDate).getTime():Number.MAX_SAFE_INTEGER;
  const bDate=b.dueDate?new Date(b.dueDate).getTime():Number.MAX_SAFE_INTEGER;
  if(aDate!==bDate)return aDate-bDate;
  const rootCompare=assignmentRoot(a.title).localeCompare(assignmentRoot(b.title));
  if(rootCompare!==0)return rootCompare;
  return String(a.title||'').localeCompare(String(b.title||''));
}
saved.sort(assignmentOrder);
const now=new Date();
function localDateKey(d){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
const todayKey=localDateKey(now);
const tomorrowDate=new Date(now.getFullYear(),now.getMonth(),now.getDate()+1);
const tomorrowKey=localDateKey(tomorrowDate);
const todayTasks=[];
const tomorrowTasksList=[];
const workList=[];
saved.forEach(a=>{
  const due=a.dueDate?new Date(a.dueDate):null;
  const dueKey=due?localDateKey(due):null;
  if(dueKey===todayKey){todayTasks.push(a)}
  else if(dueKey===tomorrowKey){tomorrowTasksList.push(a)}
  else{workList.push(a)}
});
todayTasks.sort(assignmentOrder);
tomorrowTasksList.sort(assignmentOrder);
workList.sort(assignmentOrder);
function renderTasks(list,target){list.forEach((a,i)=>{const row=document.createElement('div');row.className='task fade';row.style.animationDelay=(i*80)+'ms';row.innerHTML='<span class="dot"></span><div><h3>'+escapeHtml(a.title||'Assignment')+'</h3><p>'+escapeHtml(a.subject||'Study')+' · '+Math.round(a.estimated||0)+' min</p></div><span class="time">'+(a.dueDate?formatDate(a.dueDate):'Soon')+'</span><div class="timer-controls"><button class="start-task" data-action="start">Start</button></div>';row.dataset.title=a.title||'Assignment';row.dataset.due=a.dueDate||'';target.appendChild(row)})}
renderTasks(todayTasks,tasks);
renderTasks(tomorrowTasksList,tomorrowTasks);
renderTasks(workList,workTasks);
function setTimerControls(row,mode){
  const controls=row.querySelector('.timer-controls');
  if(mode==='start'){controls.innerHTML='<button class="start-task" data-action="start">Start</button>';}
  if(mode==='running'){controls.innerHTML='<button class="start-task" data-action="pause">Pause</button><button class="complete-task" data-action="complete">Complete</button>';}
  if(mode==='paused'){controls.innerHTML='<button class="start-task" data-action="start">Resume</button><button class="complete-task" data-action="complete">Complete</button>';}
  controls.querySelectorAll('button').forEach(bindTimerButton);
}
async function bindTimerButton(button){button.onclick=async()=>{
  const row=button.closest('.task');
  const action=button.dataset.action;
  const endpoint=action==='complete'?'/complete':(action==='pause'?'/pause':'/start');
  button.disabled=true;
  const body=new URLSearchParams({title:row.dataset.title,dueDate:row.dataset.due||''});
  try{
    const response=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body});
    const result=await response.json();
    if(!response.ok||!result.ok) throw new Error(result.error||'Timer request failed');
    if(action==='complete'){location.reload();return}
    setTimerControls(row,action==='pause'?'paused':'running');
  }catch(error){alert(error.message);button.disabled=false}
}}
document.querySelectorAll('.start-task').forEach(bindTimerButton);
const calendarDate=new Date();
function renderCalendar(){
  const year=calendarDate.getFullYear(), month=calendarDate.getMonth();
  const firstDay=new Date(year,month,1).getDay();
  const daysInMonth=new Date(year,month+1,0).getDate();
  calendarGrid.innerHTML='';
  ['S','M','T','W','T','F','S'].forEach(day=>{const header=document.createElement('div');header.className='day-header';header.textContent=day;calendarGrid.appendChild(header)});
  for(let i=0;i<firstDay;i++){const blank=document.createElement('div');blank.className='day blank';calendarGrid.appendChild(blank)}
  for(let day=1;day<=daysInMonth;day++){
    const cell=document.createElement('div');cell.className='day calendar-day';
    const dateKey=year+'-'+String(month+1).padStart(2,'0')+'-'+String(day).padStart(2,'0');
    const matches=saved.filter(a=>a.dueDate&&a.dueDate.startsWith(dateKey));
    cell.innerHTML='<span>'+day+'</span>'+matches.slice(0,2).map(a=>'<small title="'+escapeHtml(a.title||'Assignment')+'">'+escapeHtml((a.title||'Assignment').slice(0,9))+'</small>').join('');
    if(matches.length)cell.classList.add('has-event');
    if(day===new Date().getDate()&&month===new Date().getMonth()&&year===new Date().getFullYear())cell.classList.add('active');
    calendarGrid.appendChild(cell);
  }
}
renderCalendar();
addBtn.addEventListener('click',()=>modal.classList.add('open'));
cancelBtn.addEventListener('click',()=>{modal.classList.remove('open');titleInput.value='';subjectInput.value='';timeInput.value=''});
function escapeHtml(v){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}function formatDate(v){const d=new Date(v);return (d.getMonth()+1)+'/'+d.getDate()}
</script></body></html>''';
}
