# Class 1 · Assignment 1: Wrist home

## What was added

The existing **TrailMarkWatchCh10 Watch App** target has a focused home screen: **today’s step count** and one **Start Workout** action. The action opens a walking workout that tracks current and average heart rate, elapsed time, and active energy. The package is named `TrailMarkCH10Core` in this project; it fulfills the assignment’s TrailmarkCore role. Its watch target linkage, HealthKit entitlement, workout background mode, and watchOS 10 minimum are retained.

The same continuous app now has four vertical pages: **Home, Voice Memos, Live Vitals, and Motion**. Home retains one headline and one quick action. Health is optional: a new launch shows an unavailable step value until the user chooses **Enable Health** in Vitals, and navigation remains accessible throughout.

The redesigned watch scheme and iPhone companion passed generic **watchOS device and watchOS Simulator builds** on **September 22, 2026**. Current visual runtime checks remain pending. The earlier **watchOS 26.5 / Apple Watch Series 11 (46 mm)** simulator check confirmed all four pages were reachable without Health authorization before the redesign; it does not validate the new layout. No automated tests, new simulator launch, microphone capture/playback, or sensor verification were performed for this visual revision. Physical-watch evidence remains required for readings, pause-aware elapsed time, reconnection, saving, and phone mirroring. The approximately two-second home glance remains a design goal, not a measured result.

The redesigned Home uses the package's evergreen/lime identity on a black watch canvas, with a cream step headline, a full-width capsule action, and decorative contour lines. `Views/Components/WatchDesign.swift` supplies wrist-only presentation components backed by shared `Presentation/Design/TrailmarkTheme.swift`. These files add no model, manager, or Health logic.

## Acceptance criteria and rubric mapping

| Criterion | Points listed | Implementation | Remaining evidence |
| --- | ---: | --- | --- |
| Shared core, no duplication | 30 | Watch app imports the existing package and uses shared Today and Workout models, view models, and Health services. No model or manager implementation is copied into the watch target. | Complete the Health permission and physical-watch demonstration. |
| Headline metric + one quick action | 30 | One large step count and one Start Workout action. Steps refresh only when Health has been enabled, Home is selected, and the app is active. Workout navigation stays available while Health is disabled, loading, or unavailable. | Observe the loaded home and action on a watch. |
| Wrist layout and hierarchy | 20 | A single vertical hierarchy, scalable rounded numeric text, a full-width SwiftUI button with wrist-specific capsule styling, and a Crown-scrollable fallback for larger text or long state messages. | Check the redesigned interface on intended watch sizes, Dynamic Type, and the approximate two-second reading goal. |
| Specific guideline reflection | 10 | Reflection below names and links Apple’s **Designing for watchOS** Human Interface Guidelines. | Included in this document. |

These are the four criteria and point values supplied in the assignment, not a claim of an awarded grade.

## MVVM and folder structure

```text
TrailMarkWatchCh10 Watch App/
  App/TrailMarkWatchCh10App.swift       # constructs shared dependencies once
  Views/WatchHomeView.swift            # presentation and lifecycle/action forwarding
  Views/WatchWorkoutView.swift         # live BPM/energy/time and workout controls
  Views/Components/WatchDesign.swift   # wrist presentation backed by shared visual tokens
  TrailMarkWatchCh10.entitlements      # HealthKit capability

TrailMarkCH10Core/Sources/TrailMarkCH10Core/
  Presentation/Design/TrailmarkTheme.swift
                                      # same visual identity used by the iPhone
  ViewModels/TodayViewModel.swift      # same observable state/load/retry logic as iPhone
  ViewModels/WorkoutViewModel.swift    # shared workout screen state and commands
  ViewModels/TodayViewModel+StepHeadline.swift
                                      # headline/status/action presentation state
  Services/Health/ActivityHealthService.swift
                                      # same HealthKit implementation, configured stepsOnly
  Services/Health/WorkoutSessionService.swift
                                      # watch sensors, workout save, iPhone mirroring
  Models/ActivityHealthScope.swift     # quantity-selection configuration
  Models/ActivitySummary.swift         # existing shared model
  Models/WorkoutMetrics.swift          # shared current/average BPM and workout state
  Models/Journey.swift                 # existing JourneyHealthSummary value type
  Models/TodayDateRange.swift          # shared date-window value
  Support/TodayDateRangeProvider.swift         # same local-day window provider as iPhone
```

The watch target remains linked to the package product in its Frameworks phase and `packageProductDependencies`. The local package dependency points to the adjacent `TrailMarkCH10Core` directory. Xcode’s synchronized source group includes the new App and Views subfolders.

**Service:** Home receives `ActivityHealthService(scope: .stepsOnly, requestsAuthorizationOnRead: false)` and runs the existing cumulative step query after the user enables Health through Vitals. Home never requests permission on appearance. The explicit Vitals action requests reads for steps, heart rate, and active energy through the same service. Its default `.allMetrics` configuration retains the iPhone Today/Journeys behavior. There is one HealthKit implementation, parameterized by screen needs. The watch-simulator versions of the activity and workout services do not construct an `HKHealthStore` or trigger authorization.

**ViewModel:** the watch instantiates the package’s existing `TodayViewModel`, passing the steps-only service. It reuses the same loading, errors, refresh logic, date window, and optional metric results. There is no second watch manager and no local copy of a model. The `ActivityHealthProviding` contract lives beside its service implementation; `ActivityHealthScope` lives under Models. The dependency direction is View → ViewModel → Service, with services returning shared model values.

**View:** `WatchHomeView` and `WatchWorkoutView` import only SwiftUI and the shared package. They lay out ready-to-display values and forward navigation and workout controls. Number formatting and state live in package models/view models. The views contain no HealthKit queries, permission requests, workout-session objects, or mirroring logic. The watch app entry point retains the assignment view models with `@State`; it shares both the Home health service and `WorkoutViewModel` with Live Vitals. The latter can display newer workout heart-rate samples from the same session without copying the workout manager.

The watch reads its available Health store; this is not a WatchConnectivity transfer of the phone’s in-memory dashboard. Phone and watch results can differ temporarily as Health synchronizes.

## Interaction and graceful states

- Health starts disabled in the app for each launch. Home shows a dash and **Health optional · Enable in Vitals**. This is an app-level feature choice, not a claim that HealthKit permission has been denied or revoked.
- The shared view model refreshes the local-day step count only while Health is enabled, Home is selected, and the app is active. Its loading guard prevents overlapping requests. Returning to Home or reactivating it can refresh data without another permission prompt.
- The loaded screen puts **TODAY’S STEPS**, the count, a small last-updated time, and the single action in order of importance. It contains no metric grid, chart, tab bar, route, or journal list.
- Loading displays a dash and “Updating Health…”. **Start Workout stays available**, including while steps are loading or Health is unavailable. The home does not present yesterday’s value as today’s during a refresh.
- An available zero remains **0**. Missing readable steps display a dash and an explanation, rather than claiming zero steps or definite permission denial.
- A query error shows a concise state plus its explanation. Refreshes occur on the same enabled/selected/active conditions; Health errors do not disable the other pages.
- The headline scales with Dynamic Type, groups its accessibility label/value for VoiceOver, and uses text as well as color. A native vertical scroll view is available when content cannot fit, allowing Crown scrolling without custom gestures.
- The workout screen requests Health workout/heart-rate access only after its explicit Start, uses a background workout session on a physical Apple Watch, and mirrors the shared `WorkoutMetrics` model to the iPhone Workout tab. Opening the workout screen alone does not start a sensor session. The simulator explains that a physical watch is needed for a workout instead of attempting a Health connection.
- The four pages stay reachable without Health. Voice memo storage/playback has its own state, and Motion owns its independent sensor lifecycle; unavailable measurements are never replaced with fabricated values.

The daily quantity query uses the existing local-midnight-to-now window and fully contained samples. This preserves the shared service’s conservative boundary policy; a sample spanning midnight may be omitted. The last-updated time describes the query, not a guarantee that every device has finished syncing.

## Reflection: defend one choice against a named watchOS guideline

I chose to show **one large step count with one Start Workout button**. Apple’s **Designing for watchOS** Human Interface Guidelines emphasize glanceability and focused interactions: people should be able to get essential information and perform a simple task quickly. My hierarchy makes the number the first thing to read, keeps “today’s steps” beside it for context, and gives the user one immediate action. Live BPM, compact memo browsing, and Motion each have a focused screen. I left charts, maps, video, and detailed media management on the iPhone because they need longer attention. This supports the assignment’s roughly two-second glance goal without claiming that it has already been measured. [Apple: Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos).

## Wearable principles applied

- **Glanceability and focused tasks:** one headline and one action reduce what must be scanned.
- **Hierarchy:** the count is dominant; its label and freshness timestamp provide context with lower visual emphasis.
- **Digital Crown ergonomics:** the standard vertical-scroll fallback keeps enlarged content reachable without relying on small custom swipe targets. The Crown can navigate without a finger obscuring the display. [Apple: Digital Crown](https://developer.apple.com/design/human-interface-guidelines/digital-crown), [Apple: Design and build apps for watchOS 10](https://developer.apple.com/videos/play/wwdc2023/10138/).
- **Defer to the phone:** leave extended reading and route/media management to the larger screen; live workout values are mirrored to the companion Workout tab.

## Current limits and hand-in

The **September 22 watchOS and watchOS Simulator builds** and limited Health-independent navigation check preceded this visual redesign. They do not validate its layout; the redesigned watchOS device and watchOS Simulator builds, including the iPhone companion, passed on September 22, 2026; current visual runtime checks remain pending. Automated tests, recording/playback, and physical sensors were not checked. Physical-watch verification remains required because compilation/navigation does not prove device-to-device mirroring, pause/resume timing, reconnection, or Health saving. Watch display fit, Health authorization on a paired device, VoiceOver behavior, and the reading-time goal remain to be demonstrated. The workout is a walking session, not a complication or Smart Stack widget, and it is not automatically attached to a Journey. See the [Course 2 final report](WatchFinalReport.md) for all four integrated features and the quantified reuse inventory.

Submit this reflection with the project and its adjacent shared package. When you choose to produce device evidence, show the loaded home, its single action, and the shared package dependency in Xcode. Do not claim a device demonstration based on source changes alone.
