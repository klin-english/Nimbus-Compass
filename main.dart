import 'dart:convert';
import 'dart:io';
import 'assignment.dart';

String get stateFilePath() {
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

  return {
    'title': title,
    'estimate': estimate.abs(),
    'subject': subjectName,
  };
}

double measureActualTimeMinutes() {
  stdout.write('Press Enter to start the timer...');
  stdin.readLineSync();

  final start = DateTime.now();

  stdout.write('Timer started. Press Enter again when the assignment is finished...');
  stdin.readLineSync();

  final end = DateTime.now();
  final elapsedSeconds = end.difference(start).inSeconds;
  return (elapsedSeconds / 60.0).abs();
}

void main() {
  final tracker = loadTracker();
  final pendingAssignments = <Map<String, Object>>[];

  print('Loaded ${tracker.assignments.length} previous assignment(s).');
  print('Storage file: ${stateFilePath()}');

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

    pendingAssignments.add(parsed);
    print('Queued assignment: ${parsed['title']}');
  }

  for (int i = 0; i < pendingAssignments.length; i++) {
    final data = pendingAssignments[i];
    final title = data['title'] as String;
    final estimate = data['estimate'] as double;
    final subjectName = data['subject'] as String;

    print('\nTiming assignment #${i + 1}: $title');
    final actual = measureActualTimeMinutes();

    final assignment = tracker.completeAssignment(
      title,
      subjectName,
      estimate,
      actual,
    );

    saveTracker(tracker);

    print('Saved assignment to file.');
    print('Title: ${assignment.title}');
    print('Original Estimate: ${assignment.estimatedTime.toStringAsFixed(2)} min');
    print('Adjusted Estimate: ${assignment.adjustedEstimate.toStringAsFixed(2)} min');
    print('Actual Time: ${assignment.actualTime.toStringAsFixed(2)} min');
    print('Subject: ${assignment.subjectName}');
  }

  print('\nAll assignments completed.');
}