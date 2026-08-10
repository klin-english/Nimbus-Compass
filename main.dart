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

Map<String, Object>? parseAssignmentLine(String line) {
  final parts = line.split(',');
  if (parts.length != 3) {
    return null;
  }

  final title = parts[0].trim();
  final estimateText = parts[1].trim();
  final subjectName = parts[2].trim();

  final estimate = double.tryParse(estimateText);
  if (title.isEmpty || subjectName.isEmpty || estimate == null) {
    return null;
  }

  return {'title': title, 'estimate': estimate.abs(), 'subject': subjectName};
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
      "Enter assignment as 'Name, Time, Subject' or type 'start' or 'quit': ",
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
      print('Invalid format. Use: Name, Time, Subject');
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

    final newAssignment = tracker.addAssignment(
      parsed['title'] as String,
      normalizedSubject,
      parsed['estimate'] as double,
    );
    pendingAssignments.add(newAssignment);
    print('Queued assignment: ${parsed['title']}');
  }

  final scheduledAssignments = tracker.scheduleAssignments(pendingAssignments);

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
