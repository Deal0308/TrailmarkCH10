# Course 3 · Class 2 — Assignment 2: Go for a walk

Trailmark extends its existing walking workout in the same Desktop project, watch target, and `TrailMarkCH10Core` package. Start a real outdoor walk on Apple Watch, follow heart rate, elapsed time, and active energy, then finish and save it to Health. The iPhone Workout tab remains its companion; Pocket Sync still delivers completed activity records to Journeys.

**Device evidence is pending.** Source implementation and compilation cannot prove heart-rate collection, background execution, or a workout appearing in Apple Health. This assignment requires a recording made with a physical Apple Watch and its paired iPhone. The Recovery tab's explicitly synthetic sample workout does not satisfy this assignment.

## What the implementation does

### Start and collect

From Wrist Home, open **Start Workout**, then tap **Start Walk**. The shared service requests Health access only after this action. Workout authorization covers the workout and collected walking quantities; completing an authorization prompt does not prove every read permission was granted. Missing readings remain unavailable.

`WorkoutSessionService` creates an outdoor walking `HKWorkoutSession`, obtains its associated `HKLiveWorkoutBuilder`, and installs an `HKLiveWorkoutDataSource`. The session and builder share the start date. The builder's delegate publishes current and average heart rate and accumulated active energy into `WorkoutMetrics`; the view model exposes those values to both apps. Elapsed time comes from the builder, including pause events, rather than a counter owned by the screen. The heart-rate measurement timestamp identifies the age of the latest sample. See Apple's [live workout builder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder).

### Continue while backgrounded

The existing watch target enables **Background Modes → Workout Processing**. Its checked-in `TrailMarkWatchCh10-Info.plist` contains:

```xml
<key>WKBackgroundModes</key>
<array>
    <string>workout-processing</string>
</array>
```

Its entitlements also enable HealthKit. An active workout session uses this background mode to continue receiving sensor data after the wrist lowers or another watch screen opens. The composition root retains the service; leaving the workout view does not dispose of the session. Ordinary Live Vitals queries and Motion sampling have separate foreground lifecycles. See Apple's [`WKBackgroundModes`](https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes).

Background execution supports the active workout; it is not an always-on permission for unrelated work. The implementation reads sensor statistics when the builder reports data and uses a small elapsed-time refresh. It does not promise one heart-rate sample per second. Battery cost still needs measurement on hardware.

### Finish and save

**End → Finish & Save** stops the activity, completes the builder's collection, and calls `finishWorkout`. The session ends after the save sequence. This preserves the session's runtime while the builder finishes. The current Apple sequence is described in [Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions).

A successful returned `HKWorkout` supplies the saved record's identity and dates for the completion receipt. The shared `WorkoutSaveReceipt` carries the workout ID when available, start/end dates, duration, and save time. Completion feedback distinguishes saving, a returned saved record, and a save whose record cannot yet be inspected. Apple documents that `finishWorkout` can return no workout and no error when the device is locked even though the save succeeded; that case records the successful callback and builder timing without inventing a Health ID, and directs the user to check Health. A real error remains visible. See [`finishWorkout(completion:)`](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:)).

Final mirrored confirmation gets up to three seconds before the watch releases its session; iPhone connectivity cannot prevent the local save. If the phone learns that the session ended but never receives its receipt, it stops showing a busy state after eight seconds and says **Check Health**, without claiming the save failed. A late receipt can still replace that state. Overlapping start requests and callbacks from an older session are ignored.

The Health save and Pocket Sync are separate operations. A Journey arriving on the phone proves the activity transfer, not that its Health record has been visually verified. A phone connection is not needed to start, collect, or save the watch workout locally.

## MVVM and package boundary

| Layer | Existing location | Responsibility |
| --- | --- | --- |
| Models | `TrailMarkCH10Core/…/Models/WorkoutMetrics.swift` and `WorkoutSaveReceipt.swift` | Framework-independent lifecycle, optional measurements, sample time, and completion receipt. |
| Service | `TrailMarkCH10Core/…/Workout/WorkoutSessionService.swift` | Health permissions, configuration, session/builder delegates, background-owned collection, save lifecycle, and iPhone mirroring. |
| ViewModel | `TrailMarkCH10Core/…/ViewModels/WorkoutViewModel.swift` | Observable state, user actions, errors, and completion/sync presentation. |
| Watch View | `TrailMarkWatchCh10 Watch App/Views/WatchWorkoutView.swift` | Glanceable readings, Pause/Resume, finish confirmation, and save feedback. |
| iPhone View | `TrailmarkCH10/Views/Workout/WorkoutView.swift` | The same shared measurements and controls, plus Health verification guidance. |
| Composition | Both targets' existing `App` folders | Retain and inject the package services/view models. |

Neither workout view imports HealthKit. No model or manager is copied into the watch target. The watch owns the real session; the phone displays its mirrored state and forwards commands.

## Acceptance criteria and rubric mapping

| Criterion | Points supplied | Implemented evidence | Evidence still needed |
| --- | ---: | --- | --- |
| Live session streams metrics | 30 | Watch `HKWorkoutSession` plus associated live builder/data source; heart rate, sample time, builder elapsed time, and active energy in the existing workout screens. | Film a physical walk with readings changing. |
| Keeps updating while backgrounded | 25 | Workout Processing is configured; a retained package service owns the session independently of view visibility. | Film before/after measurements around a background interval and inspect the resulting samples. |
| Saves a real `HKWorkout`, verified in Health | 25 | Builder finish/save lifecycle, completion receipt from the returned workout, visible failure/unavailable-receipt states. | Open the actual walking record in Apple Health and show its time, duration, and source. |
| Reflection explains background runtime | 10 | Reflection below names the capability, active-session requirement, and confirmation steps. | Complete the evidence record after the device demo. |

The supplied rubric totals 90 points. This report preserves those rows and does not invent an additional scored criterion.

## Reflection

**What capability keeps the session alive while backgrounded, and how did you confirm the workout actually saved?**

I enabled the watch target's **Workout Processing** background mode, represented by `WKBackgroundModes` with `workout-processing`, and keep an active `HKWorkoutSession` in the shared service. The session continues the workout after the screen leaves the foreground. A view timer alone would not provide that runtime. The builder remains the source of elapsed time and collected measurements, so opening the screen again renders the ongoing workout rather than starting over.

The app waits for `finishWorkout` after completing collection. When it returns the saved `HKWorkout`, its identity and dates form the receipt. A locked-device success without a returned object is labeled separately and contains no invented Health ID. I still need to demonstrate the external confirmation required by the rubric: after the watch and phone synchronize Health data, open the corresponding walking workout in the iPhone Health app and compare its date, start time, duration, and source with Trailmark. A successful build or a Journey list entry is insufficient evidence. **The physical-device/Health-app confirmation has not been recorded yet.**

## Physical-device demo checklist

1. Open this same `TrailmarkCH10.xcodeproj`, sign the existing targets, and install on the paired iPhone and physical Apple Watch. Show **HealthKit** and **Background Modes → Workout Processing** in the watch target's capabilities.
2. Wear/unlock the watch. Open Trailmark → **Start Workout → Start Walk**. Respond to the watch's Health request and allow the workout and relevant quantities. Begin an actual walk.
3. Record elapsed time, heart rate with its measurement time, and active energy changing. Briefly Pause/Resume to show that paused time is handled correctly if desired.
4. Note the current time and metrics. Press the Digital Crown to return to the watch face or open another app, and keep walking for at least a minute. Do not end the workout or force-quit Trailmark.
5. Return to Trailmark and film the later elapsed time, a newer heart-rate measurement time, and accumulated energy. The timer alone is weak evidence; compare sensor data across the background interval as well.
6. Choose **End → Finish & Save**. Film the save progress and receipt. If a receipt is unavailable, unlock the watch and check Health before creating another record.
7. On the paired iPhone, open **Health**, find **Workouts** using Health's search or Activity category, and open its saved records. Menu wording can vary by iOS version. Select the walk matching this demonstration. Film the date/start time, duration, and Trailmark source; also inspect the heart-rate/energy data where available. Allow time for Health synchronization.
8. Record the device models, OS versions, demo date, and recording filename below. Include the clip, this report, and the complete continuous source project in the submission. A simulator recording cannot replace this device evidence.

| Evidence | Status / fill after recording |
| --- | --- |
| Physical Apple Watch model and watchOS | Pending |
| Paired iPhone model and iOS | Pending |
| Demonstration date and workout start time | Pending |
| Background interval and before/after readings | Pending |
| Matching workout visible in Apple Health | Pending |
| Demo filename or submission link | Pending |

## Verification and limits

Generic watchOS and iOS device builds passed on September 27, 2026 with code signing disabled, without compiler warnings or errors. The project/plist syntax and diff whitespace checks also passed; workout views import only SwiftUI and the shared package. No tests, app launches, or simulator runs were performed. Hardware collection, background behavior, Health synchronization, and the finished Health record remain unverified until the checklist is completed.

Heart-rate cadence and active-energy estimates are controlled by HealthKit/watchOS and can vary with fit, movement, and data availability. The app does not invent readings. Ending a walk and subsequently syncing its Journey are independent steps. The current workout screen's receipt is not a historical Health browser; use Apple Health for the persisted record and the existing Journey list for synced activity summaries.
