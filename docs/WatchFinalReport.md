# Course 2 Final Report — “TrailMark on the wrist”

## Overview and delivery status

TrailMark is one continuous iPhone/watch project. The existing **TrailMarkWatchCh10 Watch App** brings four focused tasks to the wrist: check today's steps, record and replay a voice memo, view Health vitals, and measure recent wrist movement. Its existing walking-workout screen also shows current/average heart rate and energy and mirrors workout state to iPhone. Both targets link the same local **TrailMarkCH10Core** package, which fulfills the assignment's TrailmarkCore role.

Health access is optional for opening and navigating the app. Home, saved memos, and Motion remain accessible before Health authorization or when no Health samples are readable. On a physical watch, **Enable Health** is an explicit, session-only choice; a new launch starts with Health disabled in the app. In the watch simulator, the Health services skip Health-store creation and authorization entirely and show an explanation. Missing measurements remain unavailable; the app does not insert simulated heart rate, step counts, calories, or motion readings.

**Source implementation and physical-device evidence are separate deliverables.** The four features are implemented in this project. The required physical Apple Watch recording, real screenshots, and course upload are still outstanding. A successful compilation or an accessible simulator screen does not establish live-sensor rubric credit.

The redesigned app passed generic **watchOS device and watchOS Simulator builds** on **September 22, 2026**, including the iPhone companion target. No app or simulator was launched for this visual revision. An earlier Apple Watch Series 11 (46mm), watchOS 26.5 simulator check confirmed all four pages were reachable without a Health prompt **before the redesign**. That navigation check does not validate the new interface. Current visual runtime review, microphone capture/playback, and physical-sensor evidence remain pending; no automated tests were run.

## Feature checklist and rubric

| Requirement | Source status | Evidence still required |
| --- | --- | --- |
| Wrist Home (2.1) | Implemented: one large daily step headline, one workout action, and independent navigation. | Show the home on a watch; check readability and the action. |
| Wrist Memo (2.2) | Implemented: short audio recording, shared metadata/store, saved list, and playback. | Record, save, reopen, and audibly play a memo on the watch. |
| Live Vitals (2.3) | Implemented: explicit Health access, latest saved heart rate or a newer active-workout sample, and today's live-updating steps/active energy. | Show genuine updates on a physical Apple Watch. |
| Motion (2.4) | Implemented: on-demand Core Motion capture and a rolling movement signal independent of HealthKit. | Show a still wrist, deliberate movement, and stopped sampling on a physical watch. |
| Shared core / MVVM | Implemented: one package; app target contains views and composition/navigation glue. | Show the package link and a shared call path in Xcode. |
| Wrist design and reflection | Included below. | Check fit, Dynamic Type, VoiceOver, and the brief-glance goal on the chosen watch. |
| Written report | This document includes reuse analysis, design rationale, sampling costs, and limitations. | Add the real images and demo link before submission. |
| Recording and source hand-in | Source is in the existing project. | Record the device demonstration and upload the project/report/video. |

The supplied rubric allocates **35 points** to all four working device features, **25** to reuse, **20** to wrist design, **10** to this report, and **10** to the recording/source. This table maps the work; it does not claim an awarded score or completed device verification.

## Architecture and quantified reuse

The direction of dependency is **View → ViewModel → Service → Model**. A service returns shared model values; a view model owns observable state and commands; a view formats the wrist layout and forwards taps/lifecycle changes. Models and view models do not own HealthKit, AVFoundation, or Core Motion objects.

| Layer | Location and responsibility |
| --- | --- |
| Model | Package `Models/`: activity totals, memo metadata, workout metrics, vitals snapshots, and motion state/results. Values can cross a platform boundary without bringing a sensor or player with them. |
| Service | Package `Services/`: Health authorization/queries/workouts, microphone/audio playback, local persistence, and Core Motion session ownership. |
| ViewModel | Package `ViewModels/`: loading/unavailable/error states; start, stop, record, save, and playback commands; lifecycle policy. |
| View | Watch target `Views/`: Home, Memo list/detail, Vitals, Motion, and Workout presentation. Views import SwiftUI and the shared package. |
| Shared presentation | Package `Presentation/Design/TrailmarkTheme.swift`: phone/watch colors and visual components. Watch `Views/Components/WatchDesign.swift` adapts them to a black wrist canvas and compact controls; neither file owns sensor or persistence logic. |
| Composition | Watch target `App/`: constructs dependencies once, shares one `ActivityHealthService` between Home and Vitals, and selects the four vertical pages. |

### What is actually reused

The following **18 package Swift files** are used directly or transitively by both the current iPhone and watch implementations: **17 model/service/state/support files plus one shared design file**. A file is counted once even if several features use it. The count excludes manifests, tests, generated/build files, assets, and unrelated iPhone-only features. It is a current dependency inventory, not a line-count or historical reuse percentage.

| Category | Count | Reused source files (without `.swift`) |
| --- | ---: | --- |
| Models | 8 | `ActivitySummary`, `ActivityHealthScope`, `TodayDateRange`, `Journey` (including `JourneyHealthSummary` and `GeoPoint`), `JournalMedia`, `CapturedMedia`, `AudioPlaybackState`, `WorkoutMetrics` |
| Services/contracts | 6 | `ActivityHealthProviding`, `ActivityHealthService`, `WorkoutSessionService`, `JournalMediaStore`, `AudioPlaybackService`, `MediaFileService` |
| View models | 2 | `TodayViewModel`, `WorkoutViewModel` |
| Date support | 1 | `TodayDateRangeProvider` |
| Shared design | 1 | `Presentation/Design/TrailmarkTheme` |

For example, watch recording calls **the same `JournalMediaStore.importMedia`** used by iOS and produces the same `JournalMedia` fields: ID, media type, date, duration, and relative filename. Playback uses the same `AudioPlaybackService`. The shared store also supplies index/file deletion and recovery, although the essentials-only watch UI does not expose a delete control. Home uses `TodayViewModel` with the shared health service configured for steps. The phone and watch also present the same `WorkoutMetrics` through `WorkoutViewModel`. This integration adds an optional heart-rate sample timestamp to that shared model so Vitals can choose a newer active-workout reading without creating a second session. There is no copied watch media schema, storage manager, or Health manager in the app target.

“Reused unchanged from Course 1” needs a precise boundary. The Course 1 capabilities above are reused by reference to their single current implementations. They have evolved during the continuous build. The available history has only an early `a1fddba` snapshot and a combined `659ed55` coursework commit; it does not preserve a complete pre-watch Course 1 baseline. `TodayDateRange` and `TodayDateRangeProvider` retain their early implementation definitions, now split into Model and Support files. `ActivitySummary` gained hydration/formatting/Codable support, and the original combined `HealthKitManager` was separated into `TodayViewModel` and `ActivityHealthService`. Claiming every manager is historically unchanged would be inaccurate.

The inventory also identifies **8 watch-focused package files**: `WatchAudioMemoService`, `ActivityHealthService+LiveVitals`, `WorkoutLaunchDelegate`, `WatchMemoViewModel`, `LiveVitalsViewModel`, `LiveVitalsSnapshot`, `LiveVitalsProviding`, and `TodayViewModel+StepHeadline`. They add recording, streaming, launch handling, or wrist presentation state to the shared core rather than copying its existing managers.

Motion adds **4 package files** because Course 1 did not supply motion sensing: `MotionSnapshot`, `MotionProviding`, `MotionService`, and `MotionViewModel`. The Core Motion adapter compiles for iOS and watchOS; its current screen is watch-specific. These 4 files are portable functionality, not counted among the 18 used by both apps. The listed watch dependency inventory therefore contains **30 package files: 18 shared by the current apps + 8 watch-focused + 4 motion files**. The new `RecoveryViewModel+Presentation` extension supplies derived values to iPhone Recovery and is excluded from this watch dependency count.

The watch-specific screens are `WatchHomeView`, `WatchWorkoutView`, `WatchMemoListView` (including playback detail), `WatchLiveVitalsView`, and `WatchMotionView`. Together with `Views/Components/WatchDesign.swift`, the watch target contains **six view/presentation files and one app-composition file**, with **zero model or manager implementation files**. Sharing the package means fixes to media persistence, date handling, workout values, and visual tokens apply to both apps. Shared source does not imply shared storage: watch memo files stay in the watch sandbox until a future transfer feature exists.

## Sensor behavior and permissions

**Health:** the watch requests its own read access to heart rate, steps, and active energy when the user enables the feature. Home and Vitals share the package manager. `HKStatisticsCollectionQuery` uses `.mostRecent` for heart rate and `.cumulativeSum` for the daily totals. Its initial handler loads available samples; `statisticsUpdateHandler` responds when matching HealthKit data changes. The date window starts at local midnight and the service rebuilds it when the day changes. This observes saved data; it does not force the optical sensor to measure on demand. The sample timestamp helps identify an older BPM reading. [Apple: Statistics update handler](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery/statisticsupdatehandler).

Apple Watch measures at the wrist; an iPhone can read synchronized Health records or receive data from an external sensor, but has no built-in wrist heart-rate sensor. Vitals links to the existing workout controls. An explicitly started walking workout uses the existing `HKLiveWorkoutBuilder`; while it runs, Vitals selects its heart-rate sample when its timestamp is at least as recent as the passive Health result. The screen labels the source **Workout heart rate** or **Latest Health sample**. Steps and energy stay daily Health totals, rather than being replaced with workout-only values. This reuses the same `WorkoutViewModel` as Home and iPhone and starts no extra workout session. [Apple: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession).

HealthKit does not reveal whether a person denied read access. Empty results therefore mean no readable data, not proven denial or zero activity. Health purpose strings and the capability remain configured. Microphone permission is requested when recording begins; a refusal affects recording without blocking the other pages. Motion checks available hardware and returns an unavailable state when sensor input is absent. [Apple: Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

**Motion:** the package uses Core Motion's gravity-separated `userAcceleration` to derive a movement intensity in **g**. For samples in the recent window, the signal is `sqrt(mean(x² + y² + z²))`. This rolling root-mean-square magnitude reduces axis/orientation dependence and smooths individual impulses. After a one-second warmup, **Moving** begins at `0.08 g` and **Still** returns at `0.04 g`; values between those thresholds retain the previous label to reduce flicker. These are uncalibrated wrist-movement heuristics, not a step counter, distance estimate, calorie estimate, or medical measurement. Core Motion supplies the acceleration components after separating gravity. [Apple: CMMotionManager](https://developer.apple.com/documentation/coremotion/cmmotionmanager), [Apple: Gravity and user acceleration](https://developer.apple.com/documentation/coremotion/cmdevicemotion/gravity).

## Design reflection: glanceability and focused interactions

I chose **one large headline and one primary action per task**, with separate vertically paged Home, Memos, Vitals, and Motion screens. Home emphasizes today's steps; each other task has its own page. Memo capture leaves out video, thumbnails, waveform editing, and route management. Motion shows the derived signal instead of three raw-axis traces. Standard scrolling keeps larger text reachable with the Digital Crown.

The current redesign gives these pages a black background, cream numbers, lime actions, and restrained coral/gold metric accents. The iPhone uses the same shared palette with lighter editorial surfaces and serif section headings. On the watch, numeric hierarchy and compact controls take priority over phone-style detail. Decorative contour lines and the original peak-and-trail [app icon](design/trailmark-mark.svg) establish identity without presenting invented routes or sensor readings. The redesign changes presentation while retaining the same shared models and lifecycle actions; its visual fit and accessibility still need runtime review.

This follows Apple's **Designing for watchOS** Human Interface Guidelines, especially glanceability and brief, focused interactions. Apple's *Meet watchOS 10* design session explains the same principles: each screen should support a short interaction with clear controls. The choice preserves a readable hierarchy on the wrist while leaving detailed analysis and media/route management to iPhone. The roughly two-second home glance is a design target, not a measured usability result. [Apple: Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [Apple: Meet watchOS 10](https://developer.apple.com/videos/play/wwdc2023/10026/).

## Sampling cost and the next course

Motion requests **10 samples per second**, calculates over roughly **one second**, and publishes display changes at roughly **2 per second**. Sensor delivery and screen updates are separate: reducing UI redraws reduces app work without pretending the sensor is off. The requested interval is not a guarantee; actual sample timestamps determine elapsed sampling time. Apple documents hardware limits and recommends inspecting delivered timestamps when timing matters. [Apple: Device-motion update interval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval).

Sampling begins only after the user's action and stops when it is no longer needed. The service stops Core Motion when the task ends or the page/app becomes inactive; returning requires another Start. A missing-samples watchdog reports failure after eight seconds without an initial sample or three seconds of later silence. Live Vitals likewise stops its passive queries off-page; it does not create an unrequested workout to obtain frequent BPM. The 60-second memo limit also bounds microphone activity and local file growth. These are implementation choices, not measured battery-life improvements. Apple recommends limiting sensor collection and disabling it promptly when unused. [Apple: Device sensors](https://developer.apple.com/documentation/technologyoverviews/device-sensors).

The next step is to measure the same short motion task on one physical watch at different requested rates, comparing actual sample timing, signal response, CPU work, and energy use. A lower rate may be sufficient for a broad movement signal but miss short impulses; a higher rate produces more callbacks and computation. No battery savings percentage is claimed before that comparison.

## Biggest challenge and limitations

The biggest integration challenge was separating **permission/data readiness from app readiness**. Automatically waiting for Health at startup made unrelated wrist tasks hard to reach, particularly in the simulator. Explicit feature-level Health activation, independent page state, and package-owned lifecycle methods allow navigation and local media to stay available while real measurements remain optional. The same separation ensures stopping Motion or leaving Vitals releases its own work without stopping an explicitly running workout.

Current limits are: sensor/microphone/audio-route behavior still needs physical-watch evidence; passive Health updates depend on saved samples and may arrive late; Motion is foreground/on-demand with no saved history or activity classification; its requested sampling rate and RMS signal have not been calibrated on-device; watch memos do not sync to the phone; and wrist fit/accessibility have not been measured for every watch size. These are the next implementation and demonstration priorities.

## Screenshots and device recording — still to supply

Add **five real screenshots** under `docs/screenshots/` and embed them here before hand-in. These planned captions are not substitute screenshots.

| File to supply | Subject / caption |
| --- | --- |
| `watch-01-home.png` | “Wrist Home presents one step headline and one workout action.” |
| `watch-02-memos.png` | “Voice memos saved through the shared media store show their duration.” |
| `watch-03-vitals.png` | “Live Vitals displays readable watch Health metrics with measurement context.” |
| `watch-04-motion.png` | “Motion displays recent gravity-separated wrist movement during capture.” |
| `watch-05-shared-core.png` | “The iPhone and watch targets link one TrailMarkCH10Core package.” |

For the required **physical Apple Watch** recording:

1. Identify the watch model/watchOS and build used. Open the app and navigate all four pages before enabling Health to demonstrate independence.
2. Enable Health access, show Home, and demonstrate genuine heart-rate, step, and energy changes with their timestamps. Use Vitals' walking-workout control to explicitly start the existing workout, return to Vitals, and show its **Workout heart rate** source updating. Allow time for daily step/energy samples to update; a static screenshot does not prove live updates.
3. Record a short wrist memo, stop/save it, show its duration, open the resulting row, and play it audibly.
4. Start Motion, keep the wrist still, move it deliberately, and show the signal responding. Stop it and show the inactive state. Repeat after navigating away to demonstrate lifecycle handling.
5. Show both targets' package dependency and the shared store/health call paths in Xcode. End any workout started for the demonstration.

**Device model / watchOS / build:** pending. **Demo link:** pending. **Screenshots:** pending. Submit the existing project folder with its adjacent package, this completed report, and the recording; do not create a separate assignment app. See also [Wrist Home](WatchHomeAssignment.md), [Wrist Memo](WatchMemoAssignment.md), and [Live Vitals](WatchVitalsAssignment.md).
