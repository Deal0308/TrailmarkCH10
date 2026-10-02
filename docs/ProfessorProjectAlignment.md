# Alignment with the professor's TrailMark project

This review uses the professor's [TrailMark repository at commit `1c4ebd6`](https://github.com/bryangarciad/TrailMark/tree/1c4ebd6890727c52ff469c75ca0db4ef451afae0/TrailMark) as a reference. The changes here are in the **existing** `/Users/michaeldeal/Desktop/TrailmarkCH10` project. No second app, target, or copied core module was added.

## Structure

| Professor project | This project | Shared responsibility |
| --- | --- | --- |
| `TrailmarkCore/Sources/TrailmarkCore/Models` | `TrailMarkCH10Core/Sources/TrailMarkCH10Core/Models` | Framework-independent activity, journey, memo, workout, and sensor values. |
| `Health` | `Health` | HealthKit authorization, Today/Recovery reads, and sample writes. |
| `Media` | `Media` | Capture, playback, relative-filename metadata, and the memo store. |
| `Location` | `Location` | Permission and route collection. |
| `Motion` | `Motion` | Sensor acquisition and movement signal. |
| `Connectivity` | `Connectivity` | `WCSession` activation and phone/watch payload transport. |
| `Workout` | `Workout` | Live HealthKit workout session, builder, and mirroring. |
| `Persistence` | `Persistence` | Journey checkpoints and pending sync transfers. |
| `Support` | `Support` | Date-window calculations and Settings navigation. |
| App and watch `Views` | Separate iPhone and watch `Views` | Platform-specific presentation. |

Our package also has `ViewModels` and `Presentation`: the view models own observable state and user actions, while the rendering adapters hold map, camera, picker, and player framework integration. This preserves the existing MVVM boundary and outdoor editorial UI. The package and product remain named **TrailMarkCH10Core** so both current Xcode targets keep their shared dependency. The professor's `MediaMemo`/`MediaStore` correspond to our `JournalMedia`/`JournalMediaStore`; they are equivalent roles, not duplicate schemas.

## Logic carried forward

- **Journeys:** A shared journey model stores route and health summary. Each memo stores an optional journey ID, which the Journey detail uses to gather associated media. The package owns route recording and persistence; iPhone views show the combined detail. Our existing GPS accuracy, freshness, and route-gap checks remain.
- **Media:** Both apps save through the same package model and store. A memo index holds a relative filename, not an absolute URL. Deleting a memo removes its indexed record and disk file; the existing interrupted-delete recovery remains.
- **Health and workout:** The package owns HealthKit reads/writes, live watch workout sessions, and the finished `HKWorkout`. The phone and watch render shared `WorkoutMetrics`. Health access remains optional for launching and navigating the watch app.
- **Connectivity:** A replaceable summary uses application context, each completed activity uses user info, and a memo uses file transfer. The phone imports watch activities into Journeys and audio into Journal. Existing queued-transfer persistence and retry remain.
- **Motion:** The sensor and derived signal live in the package. Our one-second rolling wrist-movement RMS is a useful Course 2 motion signal; the professor's pedometer cadence and motion-activity classification are additional approaches, not silently claimed as present here.

The professor's later complication and AR work are outside the assignments implemented in this build. The iPhone and watch layouts remain our own; matching the reference's source organization does not require matching its screen design.

This change relocates Swift source files within the package. It does **not** rename models, alter stored JSON, move on-device data, or change the app's bundle identifiers. Existing data stays under `Application Support/TrailmarkCore` (including `Media`, `Journeys`, and `PocketSync`). Compilation checks cover the source move; actual microphone, Health, GPS, connectivity, and physical-watch behavior still need device demonstration for course submission.
