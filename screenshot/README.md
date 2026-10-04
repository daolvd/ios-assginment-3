# Screenshots

Screenshots taken while running HerLift on the iOS Simulator (iPhone 17 Pro, iOS 26.5) on 3 October 2026. There is one
folder per feature, and the pictures in each are numbered `screen-evidence-1`, `-2`, and so on. They show that each
system integration works end to end, for the Required Document and for the marker.

## onboarding — the questions and the first plan

Taken on a fresh install (the database set aside, then restored), with the same answers as the test profile.

| File | What it shows |
|---|---|
| `screen-evidence-1.png` | **About you**, page 1 of 2: age, height and weight (the prompts are the suggested values), and experience (Beginner or Some). "Stays on your phone." |
| `screen-evidence-2.png` | The same page filled in: 29, 166 cm, 70 kg, Beginner. |
| `screen-evidence-3.png` | **Your training**, page 2 of 2: training days (2–7), minutes per workout and the optional health note, which leads to a question about a doctor's clearance when filled in. |
| `screen-evidence-4.png` | **Your goal**: Lose fat, Build muscle, Get stronger, Feel confident in the gym. |
| `screen-evidence-5.png` | **Your plan**, built by the planner: three workouts (Legs · Glutes, Back · Arms, Chest · Shoulders · Core), the forecast, **Accept plan** and **Start over**. |
| `screen-evidence-6.png` | **My Plan** after accepting: the week, today's workout with **Start**, and the goal. |

## home-screen-widget — WidgetKit widget, medium size

| File | What it shows |
|---|---|
| `screen-evidence-1.png` | The Workout widget while a workout is in progress: "Exercise 1 of 3 · Set 1 of 4", the exercise photo and name, "Target 10 kg × 10–12" (the starting weight from the plan), "12 reps" and **Complete set**. |
| `screen-evidence-2.png` | The widget gallery when adding the widget: the schedule with "TODAY · 6:00 PM", **Start workout** and the week strip, the screen shown before a workout. |
| `screen-evidence-3.png` | The widget placed on the Home Screen, in the Log a set state (Set 2 of 4). |
| `screen-evidence-4.png` | After tapping **Complete set** on the widget: the set is logged and the widget runs the rest, "Rest 1:27", "Next: Machine Chest Press · Set 2 of 4", with **Skip rest**. The button is an App Intent run by the widget. |
| `screen-evidence-5.png` | The app opened right after: it is on its own Rest screen, counting down the same rest (1:12), with the set from the widget already logged. The widget and the app share one workout through the App Group. |

## lock-screen-widget — the same widget in the Lock Screen family (`accessoryRectangular`)

| File | What it shows |
|---|---|
| `screen-evidence-1.png` | The widget on the Lock Screen while customising it: "TODAY · 6:00 PM", the muscle groups "Chest · Shoulders · Core" and "About 43 min", read from the same App Group snapshot. |

## notification-reminder — workout reminder and its Notification Content Extension

| File | What it shows |
|---|---|
| `screen-evidence-1.png` | The reminder banner "Workout in 30 minutes" ("Legs · Glutes · about 37 min", with the first exercises), sent by the **Send test reminder** button on the Profile screen. |
| `screen-evidence-2.png` | The extension's own view after pressing and holding the reminder: "STARTS IN 29:54 min" (a live countdown), "Chest · Shoulders · Core", "Today at 11:17 PM · About 43 min", and the notification's **Start workout** button. |
| `screen-evidence-3.png` | After tapping **Start workout** in the reminder: the app opens on today's workout, straight to the Log a set screen (Set 2 of 4), where the weight (10 kg) and the reps (12) are shown, not typed. |

## icloud-backup — CloudKit

| File | What it shows |
|---|---|
| `screen-evidence-1.png` | The `Profile` record in the private CloudKit database of container `iCloud.com.van.assignment3.HerLift` (age 29, 166 cm, 70 kg, Beginner, training weekdays 1, 3 and 6, 45 minutes), written by the app. |
| `screen-evidence-2.png` | The Profile screen after the backup: "Backed up to iCloud at 10:26 PM.", with the Back up now button. |

## Still to add

- The widget on the Lock Screen while a set is being done and while resting (live countdown).
- The `Plan` record in CloudKit, before and after Apply changes a target weight.
- The widget after **Skip rest**, and the all sets done and workout done states.

## A bug found while taking these pictures

Tapping the reminder or its **Start workout** button made the app crash: the notification delegate finished the tap on a
background thread and the system requires the main thread. The delegate now runs on the main actor, and the tap opens
the workout (see `notification-reminder/screen-evidence-3.png`).
