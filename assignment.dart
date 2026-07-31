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

  double get adjustedEstimate {
    return _estimatedTime * _baselineEfficiency;
  }

  void complete(double actual) {
    _actualTime = actual.abs();
    _subject.recordCompletion(_estimatedTime, _actualTime!);
  }

  double? get actualTime => _actualTime;
  String get title => _title;
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
  final secondComma = firstComma >= 0 ? trimmed.indexOf(',', firstComma + 1) : -1;

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

  return {
    'title': title,
    'estimate': estimate.abs(),
    'subject': subjectName,
  };
}

double measureActualTimeMinutes() {
  stdout.write("Press Enter to start the timer...");
  stdin.readLineSync();
  final start = DateTime.now();
  stdout.write("Timer started. Press Enter again when assignment is finished...");
  stdin.readLineSync();
  final end = DateTime.now();
  final elapsedSeconds = end.difference(start).inSeconds;
  return elapsedSeconds / 60.0;
}

void main() {
  final subjects = <String, Subject>{};
  final assignmentsToTime = <Map<String, Object>>[];

  print("--- Assignment Input Tracker ---");

  while (true) {
    stdout.write(
      "Enter assignment as 'Name, Original Estimate (minutes), Subject',\n"
      "or type 'start' to begin timing, 'quit' to exit:\n> ",
    );
    final input = stdin.readLineSync();
    if (input == null) {
      continue;
    }

    final trimmed = input.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'quit') {
      print("Exiting without starting timing.");
      return;
    }

    if (lower == 'start') {
      if (assignmentsToTime.isEmpty) {
        print("No assignments added yet. Add at least one assignment first.");
        continue;
      }
      break;
    }

    final assignmentData = parseAssignmentLine(trimmed);
    if (assignmentData == null) {
      print("Invalid format. Use: Name, Original Estimate (minutes), Subject");
      continue;
    }

    assignmentsToTime.add(assignmentData);
    print("Assignment added: ${assignmentData['title']} (${assignmentData['subject']})");
  }

  print("\nAll assignments entered. You can now start timing them one by one.");

  for (int i = 0; i < assignmentsToTime.length; i++) {
    final assignmentData = assignmentsToTime[i];
    final title = assignmentData['title'] as String;
    final estimate = assignmentData['estimate'] as double;
    final subjectName = assignmentData['subject'] as String;

    print("\nStarting timing for Assignment #${i + 1}: $title");
    final actual = measureActualTimeMinutes();

    final subjectKey = subjectName.toLowerCase();
    final subject = subjects.putIfAbsent(
      subjectKey,
      () => Subject(subjectName, true, []),
    );

    final task = Assignment(title, subject, estimate);
    task.complete(actual);

    print("\n--- Results for ${task.title} ---");
    print("Subject: ${subject.name}");
    print("  -> Original Estimate: ${estimate.toStringAsFixed(2)} min");
    print("  -> Adjusted Estimate (based on history): ${task.adjustedEstimate.toStringAsFixed(2)} min");
    print("  -> Actual Time Taken: ${actual.toStringAsFixed(2)} min");
    print("-" * 40);
  }

  print("\nProcessing complete.");
}