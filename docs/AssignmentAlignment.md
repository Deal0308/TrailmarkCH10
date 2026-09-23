# Assignment and reference-app alignment

## Scope and evidence

Compared against the supplied `TrailMarkCH10-main.zip` (archive commit comment `5804c9b2214ed4b3e01fa577fd24b701a5011665`) and the assignment requirements supplied in this conversation. The reference is a structural and feature example. The current redesign uses an original outdoor editorial presentation while retaining the continuous app's features and MVVM boundaries. The reference's comments and TODOs are source context, not extra assignment requirements.

This review inspected source, package/target configuration, permission descriptions, and folder boundaries. The redesigned watch scheme and iPhone companion passed generic **watchOS device and watchOS Simulator builds** on **September 22, 2026**. Current visual runtime checks remain pending. An earlier four-page Health-independent simulator navigation check happened before the redesign; it does not verify the new interface. No automated tests, new simulator launch, microphone recording/playback check, or physical-device exercise was performed for this visual revision. Hardware, sensor updates, workout mirroring/saving, location, and course demonstrations still need evidence. The latest Course 2 report is [TrailMark on the wrist](WatchFinalReport.md); [FinalReport.md](FinalReport.md) retains the Course 1 iPhone integration scope.

## Reference app → current app

| Reference element | Current implementation | Alignment decision |
| --- | --- | --- |
| iPhone entry point, AppModel, Today/Journal tabs | `TrailmarkCH10/App` composes shared view models; feature screens are under `Views` | Same composition pattern, extended to the five current iPhone tabs. |
| Core `Models/ActivitySummary` and `Models/MediaMemo` | `Models/ActivitySummary`, `Models/JournalMedia`, journey/recovery models | Reuse the existing shared model types. Do not create a competing MediaMemo schema or duplicate a watch model. |
| `Health/HealthKitManager` | `Services/Health/ActivityHealthService` + `ViewModels/TodayViewModel` | Separate platform queries from observable UI state. Includes hydration. |
| `Media/MediaStore` and relative filenames | `Services/Storage/JournalMediaStore` | Retain atomic index writes, disk-file deletion, recovery of interrupted operations, and surfaced errors. |
| `Media/AudioRecorder` and record screen | `Services/Media/MediaCaptureService` + `ViewModels/CaptureViewModel` + `Views/Journal/JournalCaptureView` | Permission/capture/save logic stays out of the view. |
| AudioPlayer, WaveformLoader and waveform detail | `Services/Media/AudioPlaybackService`, `AudioWaveformService`, `Models/AudioPlaybackState`, `ViewModels/MediaDetailViewModel`, `Views/Journal/AudioWaveformView` | Added real decoded waveform, play/pause, scrubbing, elapsed/remaining time, and live metering. Playback polling lives in the view model. |
| Camera or library video input | Queue-owned capture service plus `VideoLibrarySurface` and `MediaLibraryService` | Keep separate Record and Import choices. Import works without a camera; no UIKit or AVFoundation code is copied into app views. |
| Journal rows and memo details | Shared list/detail screen with generated video thumbnails and duration | Redesigned editorial rows preserve media type, duration, journey association, playback, and deletion. |
| Watch target with placeholder greeting | Watch `App` + Home, Voice Memo, Live Vitals, and Motion pages; Workout opens from Home | One continuous target imports the shared package. Health is opt-in, so opening the app or its pages never depends on successful Health authorization. |

The reference does not implement Recovery or Journeys, its journal deletion is marked TODO, and its row thumbnail state is never populated. Its Today authorized branch also displays an unavailable message. Those gaps are not copied into this project. The existing Health service preserves the distinction between unavailable readable data and a known write-authorization state.

The naming differs intentionally: this project uses `JournalMedia` and `JournalMediaStore` for the same responsibilities as the reference's `MediaMemo` and `MediaStore`. Both app targets link the existing `TrailMarkCH10Core` product; the assignment's “TrailmarkCore” refers to this shared-package role. No migration of the reference app's on-device index format is claimed.

## Assignment checklist

“Implemented” below means source exists. It does not claim a device demonstration or an awarded rubric score.

| Assignment / criterion | Source evidence | Status / remaining evidence |
| --- | --- | --- |
| Today activity + hydration | `Models/ActivitySummary`, `Services/Health/ActivityHealthService`, `ViewModels/TodayViewModel`, `Views/Today` | Implemented: steps, distance, active energy, water, refresh and unavailable states. Hydration reads Health; it does not log water intake. |
| Field Journal: capture and correct metadata (30) | `MediaCaptureService`, `CaptureViewModel`, `JournalMedia`, `JournalMediaStore` | UUID, audio/video type, date, positive finite duration, and relative filename; capture-time journey context. Actual microphone/camera recording evidence still needed. |
| Journal: list and playback (30) | `JournalViewModel`, `MediaDetailViewModel`, media services, journal views | Audio icon, generated video thumbnail, durations, audio waveform/seek/play/pause, native video player. Playback demonstration pending. |
| Journal: disk deletion (15) | `JournalMediaStore.delete` | Renames file, commits index removal, deletes renamed file; interrupted deletions recover at startup. Filesystem errors remain visible. Successful file removal must be demonstrated. |
| Journal: package store/persistence (15) | `Services/Storage`, `Models/JournalMedia` | Package-owned store and relative filename; no absolute media URL encoded in metadata. |
| Journal: submission (10) | README and source | Capture/playback/deletion recording and course submission pending. |
| Recovery: workout saved and shown in Health (30) | `HealthKitRecoveryStore.saveSampleWorkout`, `RecoveryViewModel` | Explicit synthetic workout write implemented. Recording showing the matching entry in Apple Health is **pending**. |
| Recovery: sleep duration (20) | `HealthKitRecoveryStore.readSleep`, `SleepDurationCalculator` | Sleep-analysis category query; asleep-only intervals clipped and merged. See date-window reflection. Real Health data comparison pending. |
| Recovery: seven-day energy + Swift Charts (25) | `RecoveryDateWindowProvider`, `HealthKitRecoveryStore.readEnergy`, `Views/Recovery/RecoveryView` | Seven local dates including partial today; cumulative active energy and Swift Charts. Missing samples distinguished from measured zero. |
| Recovery: package queries (15) | `Services/Health` | All HealthKit reads/writes are in the package. |
| Recovery: submission (10) | `RecoveryAssignment.md` | Reflection supplied; device/Health recording and upload pending. |
| Course 1 final: four features integrated (35) | Five-tab root and shared AppModel dependencies | Today, Journal, Recovery, Journeys implemented, with an additional Workout tab; end-to-end device demonstration pending. |
| Final: unified Journey detail (25) | `JourneyDetailViewModel`, `JourneyMapSurface`, `JourneyDetailView` | Segmented route polyline, memo pins, associated memos, GPS distance and journey-window Health. Geotags require a recent usable GPS fix. |
| Final: shared-package architecture (20) | Package Models/Services/ViewModels/Presentation; app App/Views | App views and view models contain no HealthKit, CoreLocation, AVFoundation, AVKit, UIKit, or PhotosUI imports. |
| Final: written report (10) | README, `FinalReport.md` | Architecture, permissions, challenge and limitations supplied; **3–6 actual screenshots pending**. |
| Final: demo + source (10) | Full project and adjacent package | Source included; demo recording and upload pending. |
| Wrist Home: shared core (30) | Watch package dependency and `App/TrailMarkWatchCh10App` | Same Today view model, Health service and models; no copied manager/model code. Final redesigned device and simulator builds passed; device demonstration remains pending. |
| Wrist Home: headline + quick action (30) | `WatchHomeView`, `TodayViewModel+StepHeadline` | Today's steps and one Start Workout action. Loaded Health state and action demonstration pending. |
| Wrist: layout/hierarchy (20) | `WatchHomeView` | Large scalable headline, vertical hierarchy, wrist-styled SwiftUI button and scroll fallback. Two-second readability and size/accessibility verification pending. |
| Wrist: named guideline reflection (10) | `WatchHomeAssignment.md` | Names and links Apple's Designing for watchOS guideline; explains the one-metric/one-action choice. |
| Wrist Memo: shared record/save (35) | `WatchAudioMemoService`, `WatchMemoViewModel`, `JournalMediaStore`, `JournalMedia` | Same package model/store used by iOS; physical-watch microphone capture remains pending. |
| Wrist Memo: list/playback (30) | `WatchMemoListView`, `AudioPlaybackService` | Compact date/duration rows and focused Play/Pause detail; audible device playback remains pending. |
| Wrist Memo: essentials-only UI (15) | `WatchMemoListView` | Record/Stop, saved list and Play/Pause; iPhone video and editing controls deliberately omitted. Watch-size verification pending. |
| Wrist Memo: reflection | `WatchMemoAssignment.md` | Contrasts the iPhone and watch capture experiences; supplied rubric did not include a point value for this row. |
| Live Vitals: heart rate (30) | `ActivityHealthService+LiveVitals`, `LiveVitalsSnapshot`, `WorkoutViewModel`, `WatchLiveVitalsView` | Long-running `.mostRecent` saved-data query plus direct HR from the existing active workout, using the actual sample timestamp. Changing heart rate must be proven on physical Apple Watch. |
| Live Vitals: steps + energy (25) | `ActivityHealthService+LiveVitals`, `LiveVitalsViewModel` | Today’s `.cumulativeSum` statistics update through HealthKit callbacks; visible device changes remain pending. |
| Live Vitals: shared Health layer (20) | `TrailMarkWatchCh10App`, `ActivityHealthService`, `LiveVitalsProviding` | Wrist Home and Live Vitals receive the same package-owned Health service; only live-query additions are watch-specific. |
| Live Vitals: reflection (15) | `WatchVitalsAssignment.md` | Explains watch versus phone sensor access, saved-data statistics updates, and the distinction from the explicit workout’s sensor stream. |
| Course 2 final: four watch features (35) | Home, Memo, Vitals, Motion views and package view models/services | All four features implemented in the same target; physical-watch vitals and motion evidence pending. |
| Course 2 final: code reuse (25) | `TrailMarkCH10Core`, `WatchFinalReport.md` reuse inventory | Shared models/managers remain in the package; watch target contains views and composition. Reuse analysis supplied in the report. |
| Course 2 final: wrist design (20) | Focused pages and `WatchFinalReport.md` guideline reflection | Watch-specific hierarchy and named guideline justification supplied; device presentation review pending. |
| Course 2 final: written report (10) | `WatchFinalReport.md` | Reuse, design, and sampling discussion supplied; actual screenshot evidence pending. |
| Course 2 final: demo + source (10) | Same Xcode project and shared package | Source included; physical-watch recording and course upload pending. |

## MVVM ownership

- **Models:** shared value types, including `AudioPlaybackState`, `LiveVitalsSnapshot`, `MotionSnapshot`, `SleepInterval`, `TodayDateRange`, activity, recovery, journey and memo metadata. No models are defined inside app view files.
- **Services:** Health permissions, snapshot and long-running watch queries, explicit workout sensors, Core Motion sampling/aggregation, camera/microphone capture, audio/video playback, PCM waveform decoding, location acquisition, and file/index persistence.
- **ViewModels:** observable screen state and commands, opt-in Health and motion lifecycle, capture-time association, waveform loading, playback progress updates, cancellation, and error handling.
- **Views:** layout, Swift Charts, waveform drawing, navigation, sheet state, and forwarding gestures/buttons/lifecycle events.
- **Presentation:** iOS package adapters for map, camera preview, video player and Photos picker UI, plus phone/watch `Presentation/Design/TrailmarkTheme.swift`. Watch `Views/Components/WatchDesign.swift` adapts presentation to the wrist. These components own rendering, not business rules. The iPhone Recovery view uses `RecoveryViewModel+Presentation.swift` for derived sleep/energy values.
- **App:** scene setup and construction/connection of shared dependencies. The watch injects one step-scoped `ActivityHealthService` into both `TodayViewModel` and `LiveVitalsViewModel`.

Audio decoding streams 4,096-frame buffers into 96 RMS buckets on a background task, rather than loading the whole recording into a view. Cancellation propagates to the decoder. A waveform failure falls back to an icon while playback and the seek slider remain available. The audio service uses [Apple's AVAudioFile PCM reading](https://developer.apple.com/documentation/avfaudio/avaudiofile) and [AVAudioPlayer's playback position](https://developer.apple.com/documentation/avfaudio/avaudioplayer/currenttime); framework types stay private to the package.

## Remaining submission work

1. Supply 3–6 real feature/Journey screenshots described in `FinalReport.md`.
2. Record the required audio/video capture, playback, deletion, route/memo/Health integration, Wrist Home, Wrist Memo, and physical-watch Live Vitals and Motion demonstrations. Follow the Course 2 evidence plan in [WatchFinalReport.md](WatchFinalReport.md).
3. Show the saved sample workout in Apple Health. A save receipt in Trailmark alone is not the required visual verification.
4. Submit the source with its adjacent package, report/reflections, screenshots and recording.

Known limits remain foreground-only routes, absent pins without valid GPS, no inferred geotags for imported video, delayed Health synchronization, a fixed sleep window, and no phone–watch media transfer. Live Vitals queries saved Health samples and also receives actual HR samples through the same workout view model during an explicitly started workout; opening Vitals alone does not activate the optical sensor. Launch and navigation require no Health connection. **Enable Health** requests access only on a physical watch; simulator Health and Motion readings show unavailable states. Motion is a short-window wrist-movement heuristic, not an activity classifier. Earlier device/simulator builds and Health-independent navigation checks preceded the current redesign. The redesigned watchOS device and watchOS Simulator builds, including the iPhone companion, passed on September 22, 2026. Current visual runtime checks remain pending; automated tests, microphone recording/playback, and physical-device runtime remain unverified. Submission screenshots and the device demo remain pending, and no crash-free claim is made.
