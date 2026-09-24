# TrailmarkCH10

Trailmark is one continuous iPhone and Apple Watch project. The iPhone app has **Today**, **Field Journal**, **Recovery**, **Workout**, and **Journeys** tabs. The existing watch target has four pages: **Wrist Home**, **Voice Memos**, **Live Vitals**, and **Motion**, with the walking workout reachable from Home and Vitals. Health access is optional; opening the watch app never waits for a Health connection. **Pocket Sync** now sends completed watch activities and voice-memo files into the iPhone's existing Journey and Journal stores.

The current assignment report is **[Pocket Sync](docs/PocketSyncAssignment.md)**, including the transfer-type reflection, MVVM map, rubric evidence, and demo sequence. The [Course 2 final report](docs/WatchFinalReport.md) covers the four original watch features, and the [Course 1 final report](docs/FinalReport.md) covers the iPhone features. See also [Recovery reflection](docs/RecoveryAssignment.md), [Wrist Home](docs/WatchHomeAssignment.md), [Wrist Memo](docs/WatchMemoAssignment.md), and [Live Vitals](docs/WatchVitalsAssignment.md).

## Current delivery status

All watch features and Pocket Sync remain in the same source project and existing watch target. **Generic iOS and watchOS device builds passed on September 24, 2026.** No app or simulator was launched for Pocket Sync. The earlier Apple Watch Series 11 (46mm), watchOS 26.5 simulator check confirmed the four watch pages were reachable without Health authorization before the visual redesign and sync assignment. Cross-device transfer, microphone playback, physical-watch sensor evidence, submission screenshots, and demo recordings remain outstanding.

See [Assignment and reference-app alignment](docs/AssignmentAlignment.md) for the supplied ZIP comparison, criterion-by-criterion evidence, and remaining submission work. The reference informed structure and features; the current outdoor editorial design is original. Audio detail retains waveform, scrubbing, elapsed/remaining time, and play/pause through separate services and a view model.

## Visual direction

The iPhone uses warm cream surfaces, evergreen feature panels, serif section headings, clear numeric metrics, and restrained trail-contour artwork. Dark appearance adapts the palette. The watch carries the same identity onto a black canvas with compact metrics, lime actions, and focused pages. Decorative contours never stand in for recorded routes or sensor data.

`Presentation/Design/TrailmarkTheme.swift` supplies shared colors, typography, cards, and controls; watch-only `Views/Components/WatchDesign.swift` adapts that presentation to the wrist. The original peak-and-trail app icon has matching phone/watch artwork plus iOS dark and tinted variants; its editable source is [trailmark-mark.svg](docs/design/trailmark-mark.svg). All features continue to use the existing models and services. Larger-text layout fallbacks and accessibility labels are implemented; current visual/device verification remains pending.

## Open the project

The continuous project folder is `/Users/michaeldeal/Desktop/TrailmarkCH10`. Open `TrailmarkCH10.xcodeproj`, select the `TrailmarkCH10` iOS scheme, and choose your signing team when preparing your own device demonstration. Keep the adjacent `TrailMarkCH10Core` folder with the project. The Xcode project uses a local Swift package and synchronized source folders.

For the watch, select the existing `TrailMarkWatchCh10 Watch App` scheme. All four pages are immediately accessible without Health permission. On a physical watch, choose **Live Vitals → Enable Health** when ready; the separate Workout **Start** action also requests its own needed Health access. The simulator skips watch Health requests altogether, shows dedicated physical-watch explanations for Vitals and Motion, and leaves navigation and Voice Memos usable. Microphone input still depends on the simulator's available audio route and permission. No simulated readings are presented as real sensor data.

To update the app visible in the watch simulator, select that **watch scheme**, choose the paired Apple Watch simulator destination, and press **Run (⌘R)**. Building alone does not install or launch the new watch executable. The current Home has **Start Workout** and **Health is optional**; a Home with a green **Refresh** button is an older installed build. Swipe vertically between Home, Voice Memos, Live Vitals, and Motion.

The teaching spec calls the shared package “TrailmarkCore”; this project's existing module is named **TrailMarkCH10Core**. It serves the same role. Its name is preserved so the iPhone and watch targets keep their existing package dependency.

## MVVM structure

```text
TrailmarkCH10/
  App/
    TrailmarkCH10App.swift          # scene entry point
    AppModel.swift                 # dependency construction and startup error state
    ContentView.swift              # feature-tab navigation and scene lifecycle forwarding
  Views/
    Today/                        # TodayDashboardView
    Journal/                      # list, recording, memo detail
    Recovery/                     # RecoveryView and Swift Charts
    Workout/                      # mirrored live workout metrics and controls
    Journeys/                     # journey list and unified detail
TrailMarkCH10Core/Sources/TrailMarkCH10Core/
  Models/                         # Codable value types, IDs, coordinates, summaries
  Services/
    Health/                       # permissions, HealthKit reads and workout writes
    Location/                     # CLLocationManager, GPS filtering and route gaps
    Media/                        # recording, playback, thumbnails, selected-video staging
    Motion/                       # Core Motion sampling, rolling RMS, movement heuristic
    Connectivity/                 # WCSession activation, queued activity/summary/file transfer
    Storage/                      # relative media paths and atomic JSON stores
  ViewModels/                     # observable screen state and user-action orchestration
  Presentation/                   # iOS camera, player, map and picker rendering adapters
    Design/TrailmarkTheme.swift    # visual tokens/components reused by phone and watch
  Support/                        # calendar windows and sleep interval calculations
TrailMarkWatchCh10 Watch App/
  App/                            # one watch composition root for all watch assignments
  Views/                          # Home, Workout, Voice Memos, Live Vitals, Motion
    Components/WatchDesign.swift   # wrist-only layout/control presentation
```

**View → ViewModel → Service → Model/store.** Services own platform APIs and persistence. View models coordinate services and expose observable state. Views render that state and forward actions. The app's composition root creates shared view-model instances so a memo added from Journey Detail immediately appears in Field Journal, and deletion removes it from both views.

No app view imports HealthKit, CoreMotion, CoreLocation, AVFoundation, AVKit, PhotosUI, or UIKit, or performs file operations. Platform rendering adapters are isolated in the package's `Presentation` folder; they adapt framework UI without owning journey business rules. SwiftUI and Charts remain presentation dependencies.

## Feature guide

- **Today:** steps, Health distance, active energy, and hydration. Missing readable quantities display a dash instead of a measured zero. Pull down to refresh.
- **Field Journal:** choose **Record a memo** for audio or video or **Import from Photos** for a selected video. The list shows icons/thumbnails and duration. Memo detail supplies playback and deletion. Voice memos include a decoded waveform, scrubbing, an accessible position slider, play/pause, elapsed/remaining time and a live playback meter. Video recording is capped at two minutes.
- **Recovery:** asleep duration from 6 p.m. yesterday to noon today, capped at now, plus seven local calendar dates of active energy. Expand **Sample workout → Save sample to Health** for the explicit synthetic workout write. Sleep-method and daily-value disclosures retain the detailed explanations. See the separate reflection for DST, overlapping stages, and missing data.
- **Workout:** starts a walking workout on the paired Apple Watch, reads current and average BPM with `HKLiveWorkoutBuilder`, and mirrors BPM, pause-aware elapsed time, active energy, and controls to iPhone. A disconnect leaves the watch workout authoritative instead of pretending it ended. The completed workout is saved to Health; missing sensor values remain unavailable.
- **Journeys:** start a named journey and open its detail. Keep Trailmark in the foreground to collect GPS. **Add memo** records for the active journey. **Finish journey** saves its end time and reads its Health summary. Tap a map pin or memo row to play it. Health can be refreshed later after device data syncs.
- **Watch Voice Memos:** swipe from Wrist Home to Voice Memos, tap **Record Memo**, then **Stop & Save**. The watch lists date and duration and provides focused Play/Pause detail. Recordings use mono AAC and stop automatically at 60 seconds to limit watch storage.
- **Watch Live Vitals:** choose **Enable Health** on a physical watch to observe today's cumulative steps/active energy and the latest readable heart rate. During an explicitly started Trailmark workout, the screen also consumes the existing builder's heart-rate stream, using the actual measurement time and identifying the source. Daily totals stay separate from workout-only energy. Opening this page never starts a workout or permission request automatically.
- **Watch Motion:** swipe to Motion and tap **Start** on a physical watch. The display shows Still/Moving and gravity-free movement strength in g, using a one-second rolling RMS and two thresholds to reduce flicker. Sampling requests 10 Hz; the display updates at most twice per second. Tap **Stop**, leave the page, or make the app inactive to stop sampling. No Health connection is needed.
- **Pocket Sync:** finishing a watch workout queues an activity record for the iPhone Journey list. Saving a watch voice memo queues its `.m4a` file and metadata for the same Journey; the watch memo detail can retry the transfer. The latest replaceable summary uses application context, each completed activity uses user info, and audio uses file transfer. See the [assignment reflection](docs/PocketSyncAssignment.md).

## Persistence and permissions

Journey JSON is saved under `Application Support/TrailmarkCore/Journeys/journeys.json`. Memo metadata and files are under `Application Support/TrailmarkCore/Media`. Media filenames remain relative. Pocket Sync uses private `Inbox` and `Outbox` staging folders while a file crosses devices; the iPhone then copies it into the same media store as local recordings. Stable activity/media IDs make repeated delivery idempotent. Optional watch activity records, journey IDs, coordinates, and import flags preserve decoding of earlier entries.

Location is requested on journey start. Camera/microphone are requested on recording. The watch requests its own microphone permission only when **Record Memo** is tapped. The Photos picker grants access only to the chosen iPhone video; broad library access is not requested. Watch Health access is opt-in via **Enable Health** or the explicit workout **Start** action. Home never presents a Health permission sheet. Motion starts only on request, uses the watch's Motion usage description, and handles permission errors independently. HealthKit does not disclose read-denial status, so missing samples remain unavailable rather than being called zero or definitely denied.

Denied permissions, missing media, empty lists, and storage failures have visible states. A usable route requires a fresh location with acceptable accuracy; without one, a memo keeps its journey association and explicitly has no map pin. Imported video is never assigned the phone's current position as its capture location.

## Biggest challenge and limitations

The main challenge was keeping GPS, delayed media saves, and asynchronous Health results attached to the same journey. Stable journey IDs, a snapshot at recording start, and shared view models keep these operations connected without duplicating state in views.

Routes are foreground-only; unavailable GPS leaves a memo unpinned. Health can sync late and its distance may differ from GPS. Outside a Trailmark workout, Live Vitals reports the latest saved heart-rate sample with its actual time; passive queries do not activate the sensor. Motion's Still/Moving label describes wrist movement only, not walking, exercise, fall detection, or a validated medical measure. Its cadence and thresholds are initial engineering choices; battery use has not been measured. The Course 2 report explains reuse, sampling cost, and the required device evidence.

## Submission still needed

For Course 2, supply the physical-watch screenshots and demo listed in [TrailMark on the wrist](docs/WatchFinalReport.md), visibly showing both vitals and motion changing. Submit the same complete Xcode project with its adjacent package and report. The earlier Course 1 submission also needs its feature/Journey screenshots and sample workout shown in Apple Health; see the [alignment checklist](docs/AssignmentAlignment.md#remaining-submission-work).


## Watch assignment: Wrist home

The existing watch target shows **today’s steps** and one **Start Workout** action. The workout screen uses the package’s `WorkoutViewModel`, `WorkoutMetrics`, and `WorkoutSessionService`; it displays live and average heart rate, energy, time, pause/resume, and End. There are no copied models or managers. HealthKit calls and phone mirroring remain in `Services/Health/`, while both app views render the same framework-independent workout model.

The [Wrist home assignment and reflection](docs/WatchHomeAssignment.md) documents the MVVM structure, state handling, rubric mapping, and design choice against Apple’s **Designing for watchOS** guideline. Voice Memos, Live Vitals, and Motion are separate vertical pages, so the home still presents one headline and one quick action. Before Health is enabled it shows a dash with an optional-access message; navigation remains available.

## Watch assignment: Wrist memo

Assignment 2 extends the same watch target and shared package. A second focused watch page records a voice memo, persists its relative file and metadata with `JournalMediaStore`, lists saved audio, and plays it through the package-owned audio service. `WatchMemoViewModel` owns capture, retry, storage, and playback state; the watch views remain free of AVFoundation and file operations.

The watch deliberately omits iPhone video capture/import, thumbnails, waveform scrubbing, geotag details, journey controls, metadata editing, and an exposed delete control. This keeps Record/Stop, saved date/duration, and Play/Pause usable at wrist size. See [Wrist memo assignment and reflection](docs/WatchMemoAssignment.md) for the rubric mapping, MVVM file map, limitations, and physical-watch demo sequence.

## Watch assignment: Live vitals

Assignment 3 adds a third focused page to the same watch target. `TrailMarkWatchCh10App` injects one package-owned `ActivityHealthService` into both Wrist Home and `LiveVitalsViewModel`. The watch-only service extension owns HealthKit authorization and three long-running `HKStatisticsCollectionQuery` objects: `.mostRecent` for heart rate and `.cumulativeSum` for today’s steps and active energy. `LiveVitalsSnapshot` keeps unavailable quantities optional and records the heart-rate sample time.

After **Enable Health**, the page starts queries only while visible and active, stops them on leaving the foreground, and resets the daily interval at local midnight. The same `WorkoutViewModel` used by Home supplies live builder BPM during a running workout, with a real sample timestamp. See [Live vitals assignment and reflection](docs/WatchVitalsAssignment.md).

## Course 2 integration: Motion and reuse

Motion adds `MotionSnapshot`, `MotionProviding`, `MotionService`, and `MotionViewModel` to the shared package, plus the wrist-specific `WatchMotionView`. Pocket Sync adds shared transport models and `PocketSyncService`; neither app view imports WatchConnectivity. The [Course 2 final report](docs/WatchFinalReport.md) records the reuse inventory at the end of Course 2, before Pocket Sync was added. It also includes the named watchOS design justification, RMS calculation, 10 Hz/2 Hz sampling tradeoff, and device-demo checklist.
