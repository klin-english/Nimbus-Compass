# Nimbus Compass

A personal assignment scheduler and time-tracking tool written in Dart. It helps you queue up schoolwork, automatically breaks big assignments into realistic work sessions, schedules them around your deadlines without ever running past them, tracks how long tasks actually take, and exports everything to a calendar (`.ics`) file. It can run either as a command-line tool or as a local web app with a phone-style UI.

## Features

- **Subject preferences** — Define which subjects you like or dislike; scheduling alternates liked and disliked work within the same day instead of grouping all of one before the other.
- **Smart estimates** — Learns your personal "efficiency factor" per subject over time (actual time vs. estimated time) and adjusts future estimates accordingly.
- **Deadline-aware scheduling** — Every assignment has a real deadline (defaulting to 11:59 PM on its due date, customizable to any time). Work is never scheduled past that instant, and sessions stacked on the same day are kept within that day's remaining time so nothing spills into the next day by accident.
- **Automatic session splitting** — Assignments are broken into work sessions using one of two strategies:
  - **Cram (default)** — packs as much work as realistically fits into a single day (~3 hours) before spilling onto the next, so small-to-medium assignments don't get needlessly spread out.
  - **Spread out** (optional, toggled per assignment) — uses the smallest realistic chunk size (just over 15 minutes) to fill as many distinct days as possible before the deadline, growing the chunk size only if there isn't enough runway to keep one session per day.
- **Session separation** — Different assignments' sessions never land at the same time, and sessions from the *same* assignment are interleaved with other assignments' sessions on shared days whenever possible, instead of always sitting back-to-back.
- **Not permanently locked** — Once an assignment is split, its individual sessions aren't frozen in place. Any session whose scheduled day has passed without being completed automatically rolls forward, without disturbing sessions still scheduled for today or later.
- **Same-day cutoff** — A configurable cutoff hour (default 10:00 PM, adjustable from Profile) controls how late you can still add or schedule something for today.
- **Calendar export** — Generates an `assignments_calendar.ics` file compatible with standard calendar apps.
- **Persistent state** — All assignments and subjects are saved to `assignment_state.json` next to the script.
- **Two interfaces:**
  - A guided **command-line** flow for entering and timing assignments.
  - A local **web app** ("Nimbus Compass") with a phone-shaped UI for adding tasks, running timers, rescheduling, and browsing a monthly calendar.

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
- Set up or edit your liked/disliked subjects, and adjust the same-day cutoff hour, from **Profile**.
- Add new assignments with a title, subject, time estimate, deadline (date + time, defaulting to 11:59 PM), and an optional "spread out" toggle.
- Browse **Today**, **Tomorrow**, and **Work List** sections, and a monthly **Calendar** view.
- Start, pause, and complete timers for each assignment.
- Hit the **reschedule** button to force a full replan of everything still pending.
- Delete a subject (this also removes all assignments under that subject).

## Data & Files

| File | Purpose |
|---|---|
| `assignment_state.json` | Persisted subjects and assignments (created automatically next to the script). |
| `assignments_calendar.ics` | Exported calendar of pending assignments, regenerated whenever assignments change. |

## Project Structure

Everything lives in a single `main.dart` file:

- **`Subject`** — Tracks a subject's name, like/dislike status, and running efficiency factor.
- **`Assignment`** — Represents a single work session: title, subject, estimated/actual time, current scheduled day (`dueDate`), the true `deadline` (preserved separately so it never erodes as sessions move), and whether it should be spread out.
- **`AssignmentTracker`** — Owns the list of assignments and subjects; handles persistence (`toJson`/`fromJson`), the same-day cutoff setting, and the scheduling algorithm.
- **`scheduleAssignments`** — The core scheduler: figures out which sessions still need placing (new assignments, or ones whose day has passed), decides cram-vs-spread chunk sizing, interleaves different assignments' sessions to avoid collisions and back-to-back same-assignment sessions, and assigns concrete times without ever exceeding a deadline.
- **CLI functions** (`cliMain`, `promptSubjects`, `parseAssignmentLine`, `measureActualTimeMinutes`, etc.) — Power the terminal-based flow.
- **Web server (`main`)** — Serves the phone-style UI and exposes endpoints:
  - `GET /` — renders the app (and rolls forward any overdue-day sessions).
  - `POST /add` — add a new assignment.
  - `POST /reschedule` — force a full replan of all pending assignments.
  - `POST /settings` — update the same-day cutoff hour.
  - `POST /subjects` / `POST /delete-subject` — manage liked/disliked subjects.
  - `POST /start` / `POST /pause` / `POST /complete` — control an assignment's timer.
- **`phoneAppHtml`** — Generates the self-contained HTML/CSS/JS front end.

## Notes

- Dates can be entered as ISO strings (`2026-08-09`) or `M/D/YY` / `M/D/YYYY` format via the CLI; the web UI uses a date + time picker.
- Assignments without a due date are scheduled last, after all dated assignments.
- Session titles no longer carry a "(Part x/y)" suffix — each session is an independent, movable assignment sharing the original title.

## Future Updates
- Make the calendar days interactable
- Update the readme when closer to complete
- Use X/X for the date instead of just the date that it should be completed on
- Resolve bug of pushing everything onto one day for no reason (rare bug)
- Show Due Dates instead of showing the day it should be done on (duplicate occasion otherwise) in case app crashes
- Update the top date to be correct
- Change the logo to be accurate to the person
- Add step by step instruction (once complete) to installing the app including SDK
