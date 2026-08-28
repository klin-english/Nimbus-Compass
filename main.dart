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
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final url = 'http://localhost:${server.port}';

  server.listen((request) async {
    if (request.method == 'GET') {
      request.response
        ..headers.contentType = ContentType.html
        ..write(phoneAppHtml(tracker.toJson()))
        ..close();
    } else if (request.method == 'POST' && request.uri.path == '/add') {
      final body = await utf8.decoder.bind(request).join();
      final data = Uri.parse('?$body').queryParameters;
      final title = data['title'] ?? 'Assignment';
      final subject = data['subject'] ?? 'Study';
      final estimated = double.tryParse(data['estimated'] ?? '0') ?? 0;
      tracker.addAssignment(title, subject, estimated);
      saveTracker(tracker);
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}')
        ..close();
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
</style></head><body><main class="phone"><section class="screen"><div class="status"><span>9:41</span><span>● ● ▰</span></div><div class="top"><div><div class="eyebrow">Thursday, August 20</div><div class="brand">Nimbus Compass</div></div><div class="avatar">KL</div></div><article class="hero fade"><h1>Keep your momentum.</h1><p>A calmer study plan, built around your energy and your deadlines.</p><div class="progress"><i></i></div><small>3 of 5 focus sessions completed</small></article><div class="section-head"><h2>This week</h2><span>August 2026</span></div><div class="week fade"><div class="day"><span>Mon</span><b>17</b></div><div class="day"><span>Tue</span><b>18</b></div><div class="day"><span>Wed</span><b>19</b></div><div class="day active"><span>Thu</span><b>20</b></div><div class="day"><span>Fri</span><b>21</b></div><div class="day"><span>Sat</span><b>22</b></div><div class="day"><span>Sun</span><b>23</b></div></div><div class="section-head"><h2>Today</h2><span>View calendar</span></div><div id="tasks"></div><button class="add" aria-label="Add assignment" id="addBtn">+</button><div class="modal" id="addModal"><div class="modal-box"><h2>New Assignment</h2><input type="text" id="titleInput" placeholder="Assignment name" autocomplete="off"><input type="text" id="subjectInput" placeholder="Subject" autocomplete="off"><input type="number" id="timeInput" placeholder="Time (minutes)" min="0" autocomplete="off"><div class="modal-buttons"><button class="btn-cancel" id="cancelBtn">Cancel</button><button class="btn-add" id="submitBtn">Add</button></div></div></div><nav class="bottom"><button class="nav selected"><span class="ico">⌂</span>Today</button><button class="nav"><span class="ico">▦</span>Calendar</button><button class="nav"><span class="ico">◷</span>Focus</button><button class="nav"><span class="ico">◌</span>Profile</button></nav></section></main><script>
const state=$encodedState;
const tasks=document.getElementById('tasks');
const modal=document.getElementById('addModal');
const addBtn=document.getElementById('addBtn');
const cancelBtn=document.getElementById('cancelBtn');
const submitBtn=document.getElementById('submitBtn');
const titleInput=document.getElementById('titleInput');
const subjectInput=document.getElementById('subjectInput');
const timeInput=document.getElementById('timeInput');
const saved=(state.assignments||[]).filter(a=>!a.actual).slice(0,3);
saved.forEach((a,i)=>{const row=document.createElement('div');row.className='task fade';row.style.animationDelay=(i*80)+'ms';row.innerHTML='<span class="dot"></span><div><h3>'+escapeHtml(a.title||'Assignment')+'</h3><p>'+escapeHtml(a.subject||'Study')+' · '+Math.round(a.estimated||0)+' min</p></div><span class="time">'+(a.dueDate?formatDate(a.dueDate):'Soon')+'</span>';tasks.appendChild(row)});
addBtn.addEventListener('click',()=>modal.classList.add('open'));
cancelBtn.addEventListener('click',()=>{modal.classList.remove('open');titleInput.value='';subjectInput.value='';timeInput.value=''});
submitBtn.addEventListener('click',async()=>{const title=titleInput.value.trim();const subject=subjectInput.value.trim();const estimated=timeInput.value.trim();if(!title||!subject||!estimated){alert('Please fill in all fields');return}const params=new URLSearchParams({title,subject,estimated});try{const res=await fetch('/add',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:params});if(res.ok){modal.classList.remove('open');titleInput.value='';subjectInput.value='';timeInput.value='';location.reload()}}catch(e){alert('Error adding assignment')}});
function escapeHtml(v){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}function formatDate(v){const d=new Date(v);return (d.getMonth()+1)+'/'+d.getDate()}
</script></body></html>''';
}
