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

void main() {
  final tracker = loadTracker();
  final pendingAssignments = tracker.pendingAssignments;

  print('Storage file: ${stateFilePath()}');
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

    final newAssignment = tracker.addAssignment(
      parsed['title'] as String,
      parsed['subject'] as String,
      parsed['estimate'] as double,
    );
    pendingAssignments.add(newAssignment);
    print('Queued assignment: ${parsed['title']}');
  }

  for (int i = 0; i < pendingAssignments.length; i++) {
    final assignment = pendingAssignments[i];
    final title = assignment.title;
    final estimate = assignment.estimatedTime;
    final subjectName = assignment.subjectName;

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
