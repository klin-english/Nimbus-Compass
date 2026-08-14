import 'dart:convert';
import 'dart:io';
import 'assignment.dart';

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

void main() {
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

    int parts = 0;
    final due = parsed['dueDate'] as DateTime?;
    if (due != null) {
      final now = DateTime.now();
      final diff = due.difference(now).inDays;
      if (diff >= 3) {
        stdout.write(
          'Due in $diff days — split into how many parts? (blank = 0): ',
        );
        final pinput = stdin.readLineSync();
        if (pinput != null && pinput.trim().isNotEmpty) {
          final parsedInt = int.tryParse(pinput.trim());
          if (parsedInt != null && parsedInt > 0) parts = parsedInt;
        }
      }
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
