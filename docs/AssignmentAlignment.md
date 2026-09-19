# Assignment and reference-app alignment

## Scope and evidence

Compared against the supplied `TrailMarkCH10-main.zip` (archive commit comment `5804c9b2214ed4b3e01fa577fd24b701a5011665`) and the assignment requirements supplied in this conversation. The reference is a structural and feature example; the existing Trailmark visual design is retained. Its comments and TODOs are source context, not extra assignment requirements.

This review inspected source, package/target configuration, permission descriptions, and folder boundaries. On September 19, 2026, the existing watch scheme and its embedded iPhone companion completed a generic build successfully with all three watch assignments in the same target. Xcode emitted only its AppIntents metadata-skip warning because the project has no AppIntents dependency. No automated tests, simulator launch, or physical-device exercise was performed. A successful build does not verify audio/video hardware, live wrist sensors, Health query updates, workout mirroring/saving, location collection, or the required course demonstrations.

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
| Journal rows and memo details | Shared list/detail screen with generated video thumbnails and duration | Retain current styling and journey association labels. |
| Watch target with placeholder greeting | Watch `App` + focused Home, Workout, Voice Memo, and Live Vitals views using the shared package | Retain one continuous target. Wrist Home shows today’s steps and one Start Workout action; later assignments are separate vertical pages. |

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
| Final: four features integrated (35) | Four-tab root and shared AppModel dependencies | Today, Journal, Recovery, Journeys implemented; end-to-end device demonstration pending. |
| Final: unified Journey detail (25) | `JourneyDetailViewModel`, `JourneyMapSurface`, `JourneyDetailView` | Segmented route polyline, memo pins, associated memos, GPS distance and journey-window Health. Geotags require a recent usable GPS fix. |
| Final: shared-package architecture (20) | Package Models/Services/ViewModels/Presentation; app App/Views | App views and view models contain no HealthKit, CoreLocation, AVFoundation, AVKit, UIKit, or PhotosUI imports. |
| Final: written report (10) | README, `FinalReport.md` | Architecture, permissions, challenge and limitations supplied; **3–6 actual screenshots pending**. |
| Final: demo + source (10) | Full project and adjacent package | Source included; demo recording and upload pending. |
| Wrist Home: shared core (30) | Watch package dependency and `App/TrailMarkWatchCh10App` | Same Today view model, Health service and models; no copied manager/model code. Generic build succeeded; device demonstration remains pending. |
| Wrist Home: headline + quick action (30) | `WatchHomeView`, `TodayViewModel+StepHeadline` | Today's steps and one Start Workout action. Loaded Health state and action demonstration pending. |
| Wrist: layout/hierarchy (20) | `WatchHomeView` | Large scalable headline, vertical hierarchy, native button and scroll fallback. Two-second readability and size/accessibility verification pending. |
| Wrist: named guideline reflection (10) | `WatchHomeAssignment.md` | Names and links Apple's Designing for watchOS guideline; explains the one-metric/one-action choice. |
| Wrist Memo: shared record/save (35) | `WatchAudioMemoService`, `WatchMemoViewModel`, `JournalMediaStore`, `JournalMedia` | Same package model/store used by iOS; physical-watch microphone capture remains pending. |
| Wrist Memo: list/playback (30) | `WatchMemoListView`, `AudioPlaybackService` | Compact date/duration rows and focused Play/Pause detail; audible device playback remains pending. |
| Wrist Memo: essentials-only UI (15) | `WatchMemoListView` | Record/Stop, saved list and Play/Pause; iPhone video and editing controls deliberately omitted. Watch-size verification pending. |
| Wrist Memo: reflection | `WatchMemoAssignment.md` | Contrasts the iPhone and watch capture experiences; supplied rubric did not include a point value for this row. |
| Live Vitals: heart rate (30) | `ActivityHealthService+LiveVitals`, `LiveVitalsSnapshot`, `WatchLiveVitalsView` | Long-running `.mostRecent` statistics query and sample time are implemented; changing heart rate must be proven on physical Apple Watch. |
| Live Vitals: steps + energy (25) | `ActivityHealthService+LiveVitals`, `LiveVitalsViewModel` | Today’s `.cumulativeSum` statistics update through HealthKit callbacks; visible device changes remain pending. |
| Live Vitals: shared Health layer (20) | `TrailMarkWatchCh10App`, `ActivityHealthService`, `LiveVitalsProviding` | Wrist Home and Live Vitals receive the same package-owned Health service; only live-query additions are watch-specific. |
| Live Vitals: reflection (15) | `WatchVitalsAssignment.md` | Explains watch versus phone sensor access, `HKStatisticsCollectionQuery`, and the passive-query limitation. |

## MVVM ownership

- **Models:** shared value types, including `AudioPlaybackState`, `LiveVitalsSnapshot`, `SleepInterval`, `TodayDateRange`, activity, recovery, journey and memo metadata. No models are defined inside app view files.
- **Services:** Health permissions, snapshot and long-running watch queries, camera/microphone capture, audio/video playback, PCM waveform decoding, location acquisition, and file/index persistence.
- **ViewModels:** observable screen state and commands, live-vitals lifecycle, capture-time association, waveform loading, playback progress updates, cancellation, and error handling.
- **Views:** layout, Swift Charts, waveform drawing, navigation, sheet state, and forwarding gestures/buttons/lifecycle events.
- **Presentation:** package-only adapters for system map, camera preview, video player and Photos picker UI. These bridges own rendering, not business rules.
- **App:** scene setup and construction/connection of shared dependencies. The watch injects one step-scoped `ActivityHealthService` into both `TodayViewModel` and `LiveVitalsViewModel`.

Audio decoding streams 4,096-frame buffers into 96 RMS buckets on a background task, rather than loading the whole recording into a view. Cancellation propagates to the decoder. A waveform failure falls back to an icon while playback and the seek slider remain available. The audio service uses [Apple's AVAudioFile PCM reading](https://developer.apple.com/documentation/avfaudio/avaudiofile) and [AVAudioPlayer's playback position](https://developer.apple.com/documentation/avfaudio/avaudioplayer/currenttime); framework types stay private to the package.

## Remaining submission work

1. Supply 3–6 real feature/Journey screenshots described in `FinalReport.md`.
2. Record the required audio/video capture, playback, deletion, route/memo/Health integration, Wrist Home, Wrist Memo, and physical-watch Live Vitals demonstrations.
3. Show the saved sample workout in Apple Health. A save receipt in Trailmark alone is not the required visual verification.
4. Submit the source with its adjacent package, report/reflections, screenshots and recording.

Known limits remain foreground-only routes, absent pins without valid GPS, no inferred geotags for imported video, delayed Health synchronization, a fixed sleep window, and no phone–watch media transfer. Live Vitals observes the latest samples saved by HealthKit and does not activate the optical sensor. The generic build succeeds; tests, simulator behavior, and physical-device runtime remain unverified, and no crash-free claim is made.
