# Final Report — “The iOS app, whole”

## App overview

Trailmark connects daily activity, a media journal, recovery information, live workouts, and recorded journeys in one iPhone app. Today shows steps, distance, active energy, and hydration. Field Journal records voice/video memos and imports selected videos. Recovery shows last night's asleep duration, a seven-day energy chart, and a sample workout save action. Workout starts a walking session on Apple Watch and mirrors its live and average heart rate to iPhone. Journeys records a foreground GPS track and unites its route, Health summary, and associated memos in Journey Detail. The same continuous watch target also contains Wrist Home, Voice Memos, and a passive Live Vitals page for the latest saved heart rate plus today’s steps and active energy.

The project is organized using **Model–View–ViewModel (MVVM)**. The implementation described below is present in source. The existing watch scheme and its embedded iPhone companion completed a generic build successfully on **September 19, 2026**, including the continuous Assignment 1, Assignment 2, and Assignment 3 watch features. Xcode emitted only its AppIntents metadata-skip warning because the project has no AppIntents dependency. Automated tests, simulators, and physical-watch runtime were intentionally not used during this review. A paired physical Apple Watch is still required for the live-sensor and wrist-memo demonstrations. Screenshots and demo evidence remain outstanding.

## Feature checklist

“Done in source” means implemented, not verified working on a device.

| Requirement | Status | Implementation / remaining evidence |
| --- | --- | --- |
| Today (1.1) | Done in source; device verification pending | Activity and hydration reads, loading/error/empty states, refresh. |
| Field Journal (1.2) | Done in source; device verification pending | Audio/video capture, selected-video import, relative files, metadata, thumbnails, duration, audio waveform/scrubbing, playback, deletion. |
| Recovery (1.3) | Done in source; integration verification pending | Corrected sleep intervals, seven-date chart, explicit synthetic workout save. Visual verification in Health remains pending. |
| Live Workout | Done in source; physical-watch verification pending | Apple Watch workout session provides current/average BPM and energy; the iPhone Workout tab starts and mirrors the session. |
| Watch Live Vitals | Done in source; physical-watch verification pending | The watch observes the latest saved heart rate and today’s cumulative steps/energy through the existing package Health service. The passive page does not activate the sensor. |
| Journeys (1.4) | Done in source; device verification pending | Start/finish, foreground GPS, filtered fixes, segmented polylines, checkpoint persistence. |
| Unified Journey Detail | Done in source; device verification pending | Route, tappable memo pins/list, elapsed time, GPS distance, journey-window Health together. |
| Memo association/geotags | Done in source with availability handling | Stable journey ID and a recent fix captured at recording start. No fix means associated but explicitly unpinned; imported clips have no invented geotag. |
| Shared package / MVVM | Done in source | Models, platform services, persistence and view models are in TrailMarkCH10Core; app views present state. |
| Written architecture and limitations | Done | This report and README; Recovery reflection is linked below. |
| 3–6 real screenshots | **Not done** | Five planned figures below; actual images must be added. |
| Demo recording, upload, and source hand-in | **Not done** | Source is included; the recording and course upload still need to be completed. |

## Architecture: Service vs ViewModel vs View

The teaching specification refers to TrailmarkCore. The existing local module is named **TrailMarkCH10Core**, and it is the shared package used here.

### Model

`Models` contains Codable, Sendable value types: `ActivitySummary`, `JourneyHealthSummary`, `Journey`, `GeoPoint`, `JournalMedia`, `WorkoutMetrics`, `LiveVitalsSnapshot`, Recovery date/energy models, and sample-workout values. `WorkoutMetrics` is the framework-independent contract shared by the watch and phone, with workout state, current/average BPM, elapsed time, and active energy. `LiveVitalsSnapshot` keeps the latest readable BPM, its sample time, today’s steps and energy, and the last query-update time without exposing HealthKit types. A journey owns route points, start/end dates, status, GPS distance, and a cached Health summary. A memo stores its UUID, type, date, duration, relative filename, optional journey ID, optional capture coordinate, and optional import flag. These values do not own camera sessions, location managers, players, or Health stores.

### Service

`Services/Health` owns HealthKit permissions, quantity/category queries, and workout writes. `ActivityHealthService` serves both Today and journey-window summaries. Its watch-only `ActivityHealthService+LiveVitals` extension reuses that manager for long-running `HKStatisticsCollectionQuery` updates: `.mostRecent` heart rate and `.cumulativeSum` daily steps/energy, with a local-midnight rollover. `HealthKitRecoveryStore` supplies sleep/energy queries and the synthetic workout flow, including a fixed 128 BPM sample for assignment demonstration. `WorkoutSessionService` owns the real Apple Watch `HKWorkoutSession`/`HKLiveWorkoutBuilder`, reads heart-rate statistics, publishes the builder's pause-aware elapsed time once per second, saves the completed workout, and uses HealthKit workout mirroring to send the shared metrics and controls between watch and phone. The iPhone reports a connection timeout and failed remote commands without claiming that the watch-side workout stopped.

`Services/Location/LocationService` owns CLLocationManager, authorization changes, accuracy/freshness filtering, and tracking lifecycle. It accepts coordinates after the journey starts, with nonnegative accuracy no worse than 100 m and timestamps within the freshness window. It uses a 10 m distance filter. A gap over 60 seconds or a jump implying over 15 m/s begins a new route segment instead of adding a misleading connecting line or distance. These are walking-oriented heuristics, not guaranteed GPS error correction.

`Services/Media` owns microphone/camera permissions, AVAudioRecorder, a serial-queue AVCaptureSession worker, playback preparation, asynchronous thumbnails, video duration loading, and copying a user-selected Photos video from its temporary provider URL. Capture configuration and session start/stop happen on the worker queue, avoiding the earlier main-thread session startup design.

`AudioPlaybackService` owns the voice-memo player and metering. `AudioWaveformService` decodes PCM into bounded RMS buckets in a cancellable background task. `MediaDetailViewModel` owns waveform loading and playback-state updates; the app’s `AudioWaveformView` only draws values and forwards seek gestures. `AudioPlaybackState` lives in Models.

`Services/Storage` owns two local stores. `JourneyStore` writes atomic JSON checkpoints and restores an interrupted session as interrupted rather than silently restarting GPS. `JournalMediaStore` serializes its index with a lock and stores only relative filenames. Imports commit metadata after copying a file. Deletion first renames the file to a pending-delete name, commits the index removal, and then removes the file. Startup can roll back or complete an interrupted deletion and clean up unindexed UUID-named import files. Corrupt indexes throw an error instead of being overwritten with an empty list. These recovery measures address multi-file failure windows; the file and index operations are not a single filesystem transaction.

### ViewModel

The package's `ViewModels` folder contains `TodayViewModel`, `RecoveryViewModel`, `WorkoutViewModel`, `LiveVitalsViewModel`, `JournalViewModel`, `CaptureViewModel`, `MediaDetailViewModel`, `JourneysViewModel`, and `JourneyDetailViewModel`. They expose observable state and coordinate user actions: load, retry, record, save, delete, start/finish, and refresh. `WorkoutViewModel` exposes the same `WorkoutMetrics` to both app targets and forwards start, pause, resume, and end actions to the service. The watch-only `LiveVitalsViewModel` owns authorization/loading/live/error state and starts or stops its service as the page’s lifecycle changes. They do not import HealthKit, CoreLocation, AVFoundation, AVKit, PhotosUI, or UIKit.

`CaptureViewModel` snapshots the active journey and recent location when recording actually begins, after permission prompts. It retains that context through asynchronous recording and saving, so the memo does not inherit an unrelated position at save time. It preserves an unsaved completed recording for a retry when storage fails. `JourneyDetailViewModel` reads the same journey and journal view models as the tabs, keeping memo pins and rows synchronized after saves/deletions. `JourneysViewModel` re-reads its latest route after awaiting HealthKit so a Health response cannot overwrite newly collected GPS points.

The earlier names `HealthKitManager` and `RecoveryHealthManager` remain source-compatible aliases for the corresponding view models, not separate implementations.

### View and composition root

The app has `App` and `Views/Today`, `Views/Journal`, `Views/Recovery`, `Views/Workout`, and `Views/Journeys` folders. `AppModel` constructs and connects dependencies once and exposes recoverable startup errors. The views render values, show navigation/sheets, and forward user/lifecycle actions to view models. Their only framework imports are SwiftUI and, for the energy chart, Charts, plus the shared package.

The package's iOS-only `Presentation` folder adapts MapKit, camera preview layers, AVKit playback UI, and the system Photos picker into reusable surfaces. These framework bridges render service/model state; they do not acquire routes, query Health, or decide which journey owns a memo. This keeps hardware APIs and framework-specific types out of app views.

```text
App/TrailmarkCH10App → AppModel (construct dependencies)
                           ↓
Views → ViewModels → Services → Models + on-disk / Health stores
  ↓
Package Presentation adapters (map, camera, player, selected-video picker)
```

### Why this helps the watch

The watch target depends on the same package. Foundation models, date calculations, Health services, media persistence, and reusable state orchestration are shared, preventing a second copy of workout state, memo schemas, or query behavior. iPhone camera/Photos/player/map adapters remain guarded for iOS. The watch home uses the shared Today view model and opens a focused workout screen backed by the same `WorkoutViewModel` and `WorkoutMetrics` as iPhone. A separate wrist-memo page uses the same `JournalMedia`, `JournalMediaStore`, and `AudioPlaybackService` as the iPhone journal, with a package-owned watch recorder and view model. Live Vitals shares the exact `ActivityHealthService` instance used by Wrist Home; only the statistics-query extension is watch-specific. See [Wrist home](WatchHomeAssignment.md), [Wrist memo](WatchMemoAssignment.md), and [Live vitals](WatchVitalsAssignment.md). Sharing code does not automatically share the two devices' files.

## How Journey Detail integrates the features

1. Starting a journey persists its identity and start time, then requests location. Each accepted point checkpoints the route. Finishing persists an end time and stops location updates.
2. Recording from Journey Detail or Field Journal uses the same capture view model and media store. A fresh location at recording start becomes the memo's geotag; the active journey ID provides its association. A clip selected from Photos is associated with the active journey at import, but is labeled imported and receives no fabricated capture coordinate.
3. Journey Detail renders each continuous route segment and the memo coordinates. A pin or memo row opens the same playback/deletion screen used by Field Journal.
4. Health reads use the journey's start through end, or the current time while it is recording. They include steps, Health distance, active energy, and hydration. The cached summary records when it was queried and can be refreshed after Health synchronization.
5. GPS distance and Health distance are labeled separately. Health quantity samples must lie fully within the journey interval, which prevents claiming a whole sample that mostly lies outside the journey but can omit boundary-spanning samples. No readable result remains unavailable; it is not treated as proof of denied access or a measured zero.

## Permissions and graceful states

| Permission / condition | Handling |
| --- | --- |
| Location | When-in-use request on Start journey; purpose string supplied. Denied/restricted access leaves a useful journey without a route. Reduced accuracy is explained. No Always permission or background location mode is requested. |
| Health | Reads and writes are separate. Recovery writes only after the explicit sample-save action, requesting workout, energy, distance, and heart-rate sharing. Workout tracking requests its required access when Start is selected. Live Vitals separately requests watch read access to heart rate, steps, and active energy and passively observes saved samples. Read-denial status is intentionally not inferred from empty queries. |
| Camera and microphone | Requested before recording; failure or unavailable hardware gives an explanation. Voice recording and selected-video import remain alternatives when a usable camera is unavailable. |
| Photos | The system video picker grants access to the selected item. The app does not request broad library access or write to Photos. Cancelling leaves the journal unchanged; failed item loading shows an error. |
| No sleep / energy / activity | Explicit unavailable states; Recovery distinguishes missing energy from recorded zero. Sleep excludes awake and in-bed-only records. |
| Empty routes / lists | Helpful empty states; memos and Health remain usable without a polyline. Unpinned memos stay visible in the journey list. |
| Missing or corrupt media | Playback shows an error with retry; it does not remain stuck on an indefinite spinner. |
| Storage initialization failure | The affected tab shows an error/retry state; Today and Recovery remain available. Existing index files are preserved. |
| File/index deletion failure | Report the error and reconcile on the next store initialization. A completed deletion removes the memo from the shared list and map pins. |
| Background / process exit | Foreground route collection pauses in the background and resumes as a new segment. A relaunch marks a previously recording journey interrupted at its last saved GPS checkpoint. |

Health data availability and permission behavior follow [Apple's authorization model](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data). Foreground-only route recording avoids requesting the background mode described in [Apple's location-update documentation](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation()).

## Biggest challenge and solution

The biggest challenge was keeping one journey coherent across independent GPS, Health, and media operations. GPS can be stale or unavailable, a camera save completes later than its start, and Health results can arrive after more route points have been recorded. Putting all of this in views would create inconsistent copies of the same state.

I solved this with stable journey IDs, a capture-time association snapshot, shared observable view models, and package-owned services. Every screen uses the same media index. GPS fixes retain their own timestamp and accuracy, gaps become separate segments, and Health refreshes update the latest journey rather than an old copy. This makes the boundaries explicit and lets unavailable data stay unavailable instead of inventing a pin or a health total.

For the Recovery date-window challenge, see the [full reflection on last night's sleep](RecoveryAssignment.md#reflection-why-last-night-needs-an-explicit-policy). It explains the local 6 p.m.–noon window, its cap at now, overlapping asleep stages, daylight saving, and shift-work limitations.

## Screenshots — six figures to supply

**Actual screenshots are not included yet.** No app or simulator was launched for the latest reference-alignment revision. These are the planned figures and captions, not substitute screenshots. Add the real images under `docs/screenshots/` and embed them in this section before submitting. Avoid exposing personal information you do not want in the course submission.

| Figure / proposed filename | Required subject | Caption to use with the actual image |
| --- | --- | --- |
| 1 — `01-today.png` | Today with activity/hydration and its current state | “Today combines daily activity and hydration from the shared Health service.” |
| 2 — `02-field-journal.png` | Journal containing audio and video, duration and thumbnail | “Field Journal stores voice and video memos with duration and journey associations.” |
| 3 — `03-recovery.png` | Sleep window/duration and the seven-day chart | “Recovery shows the documented sleep window and seven calendar dates of active energy.” |
| 4 — `04-workout.png` | iPhone Workout tab mirrored from an active Apple Watch session | “Workout shows current and average wrist heart rate from the shared workout model.” |
| 5 — `05-journeys.png` | Active or saved journey list | “Journeys stores named routes and exposes recording and completed states.” |
| 6 — `06-journey-detail.png` | Unified route with memo pins, plus the Health/memo sections | “Journey Detail unites the route, geotagged memos, and journey-window Health.” |

If the unified detail content requires two captures, replace a less important overview image so the report stays within the requested 3–6 screenshot range. This planning table alone does not satisfy that requirement.

## Known limitations and next steps

- The watch scheme and embedded iPhone companion completed a generic build successfully on September 19. Xcode's AppIntents metadata-skip warning remains because the project has no AppIntents dependency. Tests, simulators, and physical-watch runtime were not used in this review. A build does not verify microphone capture/playback, wrist heart-rate collection, live steps/energy changes, pause/resume timing, reconnect behavior, mirroring, or Health saving; exercise those with a paired physical Apple Watch.
- Routes are foreground-only. Background time is included in elapsed journey time but contributes no route points; separate segments prevent drawing across the gap. Next: deliberate background-location support with an appropriate permission and battery strategy.
- Location accuracy and freshness filtering can leave memos without a pin. Imported clips have no inferred geotag. Next: optionally read source video metadata or allow an explicitly labeled manual location.
- GPS distance can contain noise; the walking-oriented speed/gap thresholds can be unsuitable for cycling or transport. Next: activity-specific filters and better quality indicators.
- Health data can sync late or be unavailable. Fully contained sample queries may undercount journey boundaries. GPS distance is not substituted for Health distance. Next: a documented boundary allocation policy and controlled device comparisons.
- The sample workout in Recovery is synthetic (20-minute indoor walk, 120 kcal, 1.5 km, 128 BPM average), separate from a recorded Journey, and affects Health totals. The live Workout tab records real Apple Watch heart rate, but Journeys do not yet become an `HKWorkout` or `HKWorkoutRoute`.
- Sleep uses a documented 6 p.m.–noon window and a union of readable asleep intervals. It is not a personalized sleep-episode detector or Apple's source-priority algorithm.
- JSON route checkpoints rewrite the stored collection; very long histories need a more scalable store. Media stays local, without cloud backup management, sharing, or phone–watch transfer.
- Media interruption/device rotation behavior and low-disk conditions need device work. Video capture is limited to two minutes. No offline map download is provided.
- Wrist Home, Workout, Wrist Memo, and Live Vitals are surfaces in the same watch target and use the same package. Live Vitals reports the latest heart-rate sample saved in HealthKit and its measurement time; opening the passive query does not activate the optical sensor. Physical-watch microphone/audio routing, authorization, sensor behavior, live query updates, and HealthKit mirroring still require device verification. Watch memo files remain in the watch sandbox until a future transfer feature is added.

## Demo recording and hand-in

When ready to produce the required evidence, show all five iPhone tabs. On the physical watch, show Wrist Home, record and play a wrist memo, and show heart rate, steps, and active energy changing on Live Vitals. Start a watch workout and show live heart rate on the watch and mirrored iPhone Workout tab. Then start a journey, collect a route, record audio/video memos during it, finish it, and open Journey Detail to show the polyline, pins, Health summary, and working playback. Demonstrate memo deletion and the resulting list/pin removal. For the Recovery workout criterion, show the explicit sample save and matching entry in Apple Health. Identify its values as synthetic.

Submit the full Xcode project with its adjacent local package, this report with 3–6 real screenshots, and the demo recording through the course upload workflow. Do not include `.git`, build caches, device data, or signing credentials. **The screenshots, recording, and course upload are outstanding; rubric completion is not claimed.**

## Reference-app comparison

The [assignment alignment review](AssignmentAlignment.md) maps the supplied `TrailMarkCH10-main.zip` to this project and every provided rubric. It preserves the current design and completed features while adding the reference’s waveform interaction through the MVVM boundaries. Screenshot, demo and Health verification requirements remain open.
