# Stride

A native macOS app for tracking habits and home projects. Built for my own use,
because the tools I tried all assumed the thing you want to repeat happens on a
weekday — and most of what I actually needed to track happens every 90 days.

Local-first. Everything lives in JSON files on disk, no account, no sync, no server.

> **Not actively maintained.** Written in April 2026 and used since; it does what I
> needed, so I stopped. Published as-is rather than presented as an ongoing project.

## What it does

**Habits** with three completion shapes, because "did you do it" is not always a
yes/no question:

- `checkbox` — did it or didn't
- `tally` — count toward a target (glasses of water, sets)
- `checklist` — named subtasks that complete individually

**Two scheduling models:**

- *Weekly* — pick the days it recurs
- *Interval* — every N days from a start date

The interval mode is why this exists. Furnace filters, gutter clearing, water-heater
flushes, and deck sealing are all "every N months" tasks that a weekday-based
scheduler cannot represent without lying about them.

**Projects** group related work with per-project task lists and archiving.
**Quick tasks** cover one-offs that don't belong to a project, with optional
recurrence by day/week/month. **Workspaces** split personal from work so the
morning view isn't a blend of "replace furnace filter" and "prep 1:1 notes."
**Time-of-day buckets** (Before Work / Morning / Afternoon / Night / All Day)
organize the daily view.

Streaks, longest-streak, and completion rate are computed per habit.

## Structure

```
Stride/
  Models/          Habit, Project, QuickTask, HabitCompletion, Workspace,
                   TimeCategory, DayOfWeek — all Codable value types
  Services/
    HabitStore     @Observable store; scheduling, streaks, completion state
    StorageService JSON persistence to Application Support, atomic writes
  Views/
    Today/         daily view grouped by time category
    Projects/      project detail and completed-project history
    Unassigned/    tasks with no project
    Sidebar/       navigation and workspace switching
    Components/    confetti, completion-note sheet
project.yml        XcodeGen spec (no .xcodeproj in the repo)
```

## Two things worth pointing at

**Schema-compatible decoding.** `Habit` and `Project` have hand-written
`init(from:)` decoders that use `decodeIfPresent(...) ?? default` for every field
added after the first version. Adding workspaces and sort ordering later would
otherwise have made every existing `habits.json` unreadable. Data written by an
older build still loads.

**Notes as a completion requirement.** A habit can set `requiresNote`, which forces
a short note when you mark it done. Useful for anything where the *result* matters
more than the checkmark — a project step you want a record of, not just a tick.

## Building it

Requires macOS 14+, Xcode with Swift 6, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open Stride.xcodeproj
```

The project file is generated rather than committed, so `project.yml` is the source
of truth for build settings. Change the `DEVELOPMENT_TEAM` value there to your own
before signing.

## Data

Stored at `~/Library/Application Support/Stride/` as four JSON files —
`habits.json`, `completions.json`, `quicktasks.json`, `projects.json`. Pretty-printed
with sorted keys, so they diff cleanly and can be edited by hand or backed up with
anything that copies files.
