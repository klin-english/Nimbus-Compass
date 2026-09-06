# Nimbus Compass

A personal assignment scheduler and time-tracking tool written in Dart. It helps you queue up schoolwork, automatically splits large assignments into manageable study sessions, schedules them around your deadlines, tracks how long tasks actually take, and exports everything to a calendar (`.ics`) file. It can run either as a command-line tool or as a local web app with a phone-style UI.

## Features

- **Subject preferences** — Define which subjects you like or dislike; this affects scheduling priority.
- **Smart estimates** — Learns your personal "efficiency factor" per subject over time (actual time vs. estimated time) and adjusts future estimates accordingly.
- **Automatic task splitting** — Assignments estimated at 90+ minutes are automatically broken into multiple parts (~45 minutes each), spaced across different days leading up to the due date.
- **Scheduling** — Pending assignments are ordered by due date, then by subject preference (liked subjects first), then by size.
- **Calendar export** — Generates an `assignments_calendar.ics` file compatible with standard calendar apps.
- **Persistent state** — All assignments and subjects are saved to `assignment_state.json` next to the script.
- **Two interfaces:**
  - A guided **command-line** flow for entering and timing assignments.
  - A local **web app** ("Nimbus Compass") with a phone-shaped UI for adding tasks, running timers, and browsing a monthly calendar.

## Getting Started

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) installed and available on your `PATH`.

### Running the CLI

```bash
dart run main.dart --cli
```

You'll be prompted to:
1. Enter your subjects (comma-separated) and say whether you like each one.
2. Add assignments in the format:
   ```
   Name, Time (minutes), Subject, DueDate (YYYY-MM-DD or ISO)
   ```
3. Type `start` once you're done queuing assignments to begin timing them one by one, or `quit` to save and exit.

### Running the Web App

```bash
dart run main.dart
```

This starts a local HTTP server and attempts to open Nimbus Compass in Google Chrome automatically. If it doesn't open, the terminal will print a `localhost` URL you can open manually.

From the web app you can:
- Set up or edit your liked/disliked subjects.
- Add new assignments (must be scheduled for today or later, and today's tasks must be added before 10:00 PM local time).
- Start, pause, and complete timers for each assignment.
- Browse a monthly calendar view of due dates.
- Delete a subject (this also removes all assignments under that subject).

## Data & Files

| File | Purpose |
|---|---|
| `assignment_state.json` | Persisted subjects and assignments (created automatically next to the script). |
| `assignments_calendar.ics` | Exported calendar of pending assignments, regenerated whenever assignments change. |

## Project Structure

Everything lives in a single `main.dart` file:

- **`Subject`** — Tracks a subject's name, like/dislike status, and running efficiency factor.
- **`Assignment`** — Represents a single task: title, subject, estimated/actual time, due date, and part number (if split).
- **`AssignmentTracker`** — Owns the list of assignments and subjects; handles persistence (`toJson`/`fromJson`), scheduling, and splitting logic.
- **CLI functions** (`cliMain`, `promptSubjects`, `parseAssignmentLine`, `measureActualTimeMinutes`, etc.) — Power the terminal-based flow.
- **Web server (`main`)** — Serves the phone-style UI and exposes endpoints for subjects, adding assignments, and timer control (`/start`, `/pause`, `/complete`).
- **`phoneAppHtml`** — Generates the self-contained HTML/CSS/JS front end.

## Notes

- Dates can be entered as ISO strings (`2026-08-09`) or `M/D/YY` / `M/D/YYYY` format.
- Assignments without a due date are scheduled last, after all dated assignments.
