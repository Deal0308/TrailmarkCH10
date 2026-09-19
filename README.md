# TrailmarkCH10

Trailmark is one continuous iPhone and Apple Watch project. The iPhone app has **Today**, **Field Journal**, **Recovery**, **Workout**, and **Journeys** tabs. The same watch target contains a glanceable Wrist Home, live workout tracking, essentials-only Voice Memos, and a Live Vitals page for the latest saved heart rate plus today’s steps and active energy.

Read the [full final report](docs/FinalReport.md) for the iPhone feature checklist and architecture. The [Recovery reflection](docs/RecoveryAssignment.md) explains the last-night sleep window. The watch coursework is documented in [Assignment 1: Wrist Home](docs/WatchHomeAssignment.md), [Assignment 2: Wrist Memo](docs/WatchMemoAssignment.md), and [Assignment 3: Live Vitals](docs/WatchVitalsAssignment.md).

## Current delivery status

The iPhone features and all three watch assignments are implemented in the same source project and existing watch target. **The existing watch scheme and its embedded iPhone companion completed a generic build successfully on September 19, 2026 with Live Vitals included.** Xcode emitted only its AppIntents metadata-skip warning because the project has no AppIntents dependency. Automated tests and simulator launches were not run, following the requested verification scope. No physical-watch runtime was performed. A physical Apple Watch is still required to prove microphone capture/playback, heart-rate and activity updates, phone mirroring, and Health saving. Actual screenshots and demo recordings are still needed.

See [Assignment and reference-app alignment](docs/AssignmentAlignment.md) for the supplied ZIP comparison, criterion-by-criterion evidence, and remaining submission work. Your current design is retained; audio detail now adds the reference app’s waveform, scrubbing, elapsed/remaining time and play/pause through separate services and a view model.

## Open the project

Open `TrailmarkCH10.xcodeproj`, select the `TrailmarkCH10` iOS scheme, and choose your signing team when preparing your own device demonstration. Keep the adjacent `TrailMarkCH10Core` folder with the project. The Xcode project uses a local Swift package and synchronized source folders.

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
    Storage/                      # relative media paths and atomic JSON stores
  ViewModels/                     # observable screen state and user-action orchestration
  Presentation/                   # iOS-only camera, player, map and picker rendering adapters
  Support/                        # calendar windows and sleep interval calculations
TrailMarkWatchCh10 Watch App/
  App/                            # one watch composition root for all watch assignments
  Views/                          # focused Home, Workout, Voice Memo, and Live Vitals surfaces
```

**View → ViewModel → Service → Model/store.** Services own platform APIs and persistence. View models coordinate services and expose observable state. Views render that state and forward actions. The app's composition root creates shared view-model instances so a memo added from Journey Detail immediately appears in Field Journal, and deletion removes it from both views.

No app view imports HealthKit, CoreLocation, AVFoundation, AVKit, PhotosUI, or UIKit, or performs file operations. Platform rendering adapters are isolated in the package's `Presentation` folder; they adapt framework UI without owning journey business rules. SwiftUI and Charts remain presentation dependencies.

## Feature guide

- **Today:** steps, Health distance, active energy, and hydration. Missing readable quantities display a dash instead of a measured zero. Pull down to refresh.
- **Field Journal:** use **+ → Record a memo** for audio or video; **+ → Import video** selects one clip from Photos. The list shows icons/thumbnails and duration. Memo detail supplies playback and deletion. Voice memos include a decoded waveform, scrubbing, an accessible position slider, play/pause, elapsed/remaining time and a live playback meter. Video recording is capped at two minutes.
- **Recovery:** asleep duration from 6 p.m. yesterday to noon today, capped at now; seven local calendar dates of active energy; explicit synthetic sample-workout save. See the separate reflection for DST, overlapping stages, and missing data.
- **Workout:** starts a walking workout on the paired Apple Watch, reads current and average BPM with `HKLiveWorkoutBuilder`, and mirrors BPM, pause-aware elapsed time, active energy, and controls to iPhone. A disconnect leaves the watch workout authoritative instead of pretending it ended. The completed workout is saved to Health; missing sensor values remain unavailable.
- **Journeys:** start a named journey and open its detail. Keep Trailmark in the foreground to collect GPS. **Add memo** records for the active journey. **Finish journey** saves its end time and reads its Health summary. Tap a map pin or memo row to play it. Health can be refreshed later after device data syncs.
- **Watch Voice Memos:** swipe from Wrist Home to Voice Memos, tap **Record Memo**, then **Stop & Save**. The watch lists date and duration and provides focused Play/Pause detail. Recordings use mono AAC and stop automatically at 60 seconds to limit watch storage.
- **Watch Live Vitals:** swipe to Live Vitals to request watch Health access and observe the latest saved heart-rate sample plus today’s cumulative steps and active energy. Heart rate includes its measurement time. Long-running statistics queries update the page when HealthKit changes; opening this passive page does not activate the heart-rate sensor.

## Persistence and permissions

Journey JSON is saved under `Application Support/TrailmarkCore/Journeys/journeys.json`. Memo metadata and files are under `Application Support/TrailmarkCore/Media`. Media filenames remain relative. Optional journey IDs, coordinates, and import flags preserve decoding of earlier journal entries.

Location is requested on journey start. Camera/microphone are requested on recording. The watch requests its own microphone permission only when **Record Memo** is tapped. The Photos picker grants access only to the chosen iPhone video; broad library access is not requested. Health read permissions and workout/energy/distance/heart-rate write permissions are separate. Live Vitals requests watch read access to heart rate, steps, and active energy; the explicit workout flow separately requests the types needed to record and save a workout. The Apple Watch supplies wrist BPM, and the iPhone never estimates it. HealthKit does not disclose read-denial status, so missing samples are described as unavailable.

Denied permissions, missing media, empty lists, and storage failures have visible states. A usable route requires a fresh location with acceptable accuracy; without one, a memo keeps its journey association and explicitly has no map pin. Imported video is never assigned the phone's current position as its capture location.

## Biggest challenge and limitations

The main challenge was keeping GPS, delayed media saves, and asynchronous Health results attached to the same journey. Stable journey IDs, a snapshot at recording start, and shared view models keep these operations connected without duplicating state in views.

Routes are foreground-only; unavailable GPS leaves a memo unpinned. Health can sync late and its distance may differ from GPS. The watch home keeps one quick action, now opening the shared workout tracker; workout metrics mirror to the iPhone Workout tab. Live Vitals passively observes samples saved to HealthKit, so its heart rate can be older than the time the page opens and is labeled with the actual measurement time. The full report explains these limitations and the screenshot subjects.

## Submission still needed

Supply 3–6 real screenshots, the feature/watch demo recording, physical-watch evidence that Live Vitals changes, and a recording showing the sample workout in Apple Health. Submit the complete Xcode project with its adjacent package and reports. See the [alignment checklist](docs/AssignmentAlignment.md#remaining-submission-work).


## Watch assignment: Wrist home

The existing watch target shows **today’s steps** and one **Start Workout** action. The workout screen uses the package’s `WorkoutViewModel`, `WorkoutMetrics`, and `WorkoutSessionService`; it displays live and average heart rate, energy, time, pause/resume, and End. There are no copied models or managers. HealthKit calls and phone mirroring remain in `Services/Health/`, while both app views render the same framework-independent workout model.

The [Wrist home assignment and reflection](docs/WatchHomeAssignment.md) documents the MVVM structure, state handling, rubric mapping, and design choice against Apple’s **Designing for watchOS** guideline. Assignments 2 and 3 add Voice Memos and Live Vitals as separate vertical pages, so the original home still presents one headline metric and one quick action. The physical-watch session, the two-second glance, and watch-size fit remain to be demonstrated.

## Watch assignment: Wrist memo

Assignment 2 extends the same watch target and shared package. A second focused watch page records a voice memo, persists its relative file and metadata with `JournalMediaStore`, lists saved audio, and plays it through the package-owned audio service. `WatchMemoViewModel` owns capture, retry, storage, and playback state; the watch views remain free of AVFoundation and file operations.

The watch deliberately omits iPhone video capture/import, thumbnails, waveform scrubbing, geotag details, journey controls, metadata editing, and an exposed delete control. This keeps Record/Stop, saved date/duration, and Play/Pause usable at wrist size. See [Wrist memo assignment and reflection](docs/WatchMemoAssignment.md) for the rubric mapping, MVVM file map, limitations, and physical-watch demo sequence.

## Watch assignment: Live vitals

Assignment 3 adds a third focused page to the same watch target. `TrailMarkWatchCh10App` injects one package-owned `ActivityHealthService` into both Wrist Home and `LiveVitalsViewModel`. The watch-only service extension owns HealthKit authorization and three long-running `HKStatisticsCollectionQuery` objects: `.mostRecent` for heart rate and `.cumulativeSum` for today’s steps and active energy. `LiveVitalsSnapshot` keeps unavailable quantities optional and records the heart-rate sample time.

The page starts its queries while visible and active, stops them when it leaves the foreground, and resets the daily interval at local midnight. It observes HealthKit changes but does not activate the optical sensor. See [Live vitals assignment and reflection](docs/WatchVitalsAssignment.md) for the rubric mapping, MVVM file map, sensor-access explanation, limitations, and required physical-watch demo checklist.
