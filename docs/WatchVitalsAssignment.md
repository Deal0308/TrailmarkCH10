# Class 3 · Assignment 3: Live vitals

## What was added

Assignment 3 extends the same **TrailMarkWatchCh10 Watch App** target used for Wrist Home and Wrist Memo. It is the third of four vertical pages: **Home, Voice Memos, Live Vitals, and Motion**. On a physical watch, the explicit **Enable Health** action requests read access to heart rate, steps, and active energy. Vitals then shows the latest readable saved heart rate or a newer sample from Trailmark's active workout, together with today's cumulative steps and active energy. No second project, target, or HealthKit manager was created.

Wrist Home and Live Vitals share one `ActivityHealthService` instance from `TrailMarkCH10Core` and the same `WorkoutViewModel`. The watch-only `ActivityHealthService+LiveVitals` extension adds long-running queries while the existing service continues to supply Home's step summary. `LiveVitalsViewModel` selects the appropriate heart-rate source from shared model values; `WatchLiveVitalsView` contains only SwiftUI presentation and lifecycle/action forwarding.

The redesigned watch scheme and iPhone companion passed generic **watchOS device and watchOS Simulator builds** on **September 22, 2026**. Current visual runtime checks remain pending. The earlier **watchOS 26.5 / Apple Watch Series 11 (46 mm)** simulator check confirmed all four pages were reachable without Health authorization before the redesign; it does not validate the new Vitals layout. No automated tests, new simulator launch, microphone capture/playback, or sensor verification were performed for this visual revision. Heart-rate collection and visible live changes still require a physical Apple Watch demonstration.

## Acceptance criteria and rubric mapping

| Criterion | Points listed | Implementation | Remaining evidence |
| --- | ---: | --- | --- |
| Live heart rate updating on device | 30 | Explicit watch Health authorization; `.mostRecent` statistics for saved samples; direct `HKLiveWorkoutBuilder` heart-rate samples from the existing running workout when at least as recent. Source and measurement time are explicit. | Show the value and measurement time changing on a physical Apple Watch. |
| Steps and active energy live | 25 | Two long-running statistics collection queries use `.cumulativeSum` for the local day. HealthKit recalculates totals when matching samples are saved or deleted. | Demonstrate at least one visible change to steps and active energy on the watch. |
| Reuses shared HealthKit layer | 20 | Home and Vitals receive the same package-owned `ActivityHealthService` and `WorkoutViewModel`. Live queries extend the existing manager; workout heart rate reuses its existing session and shared `WorkoutMetrics`. No HealthKit reaches a view. | Briefly show the package files and shared dependency construction in Xcode. |
| Reflection explains sensor-access difference | 15 | The reflection below distinguishes the watch’s optical sensor from the phone’s Health store and identifies the long-running query type and handlers. | Included below. |

The supplied rubric lists these four rows for 90 points. This document does not invent a missing criterion or claim an awarded grade.

## MVVM and continuous-project structure

```text
TrailMarkWatchCh10 Watch App/
  App/TrailMarkWatchCh10App.swift
      # one composition root for four pages plus shared workout controls
      # injects the same ActivityHealthService and WorkoutViewModel into Home/Vitals
  Views/WatchLiveVitalsView.swift
      # heart rate/source/time, daily steps/energy, explicit Enable Health, and Retry
  Views/Components/WatchDesign.swift
      # wrist presentation components; no Health or sensor logic

TrailMarkCH10Core/Sources/TrailMarkCH10Core/
  Presentation/Design/TrailmarkTheme.swift
      # shared phone/watch visual palette and components
  Models/LiveVitalsSnapshot.swift
      # optional BPM/totals, sample timestamps, formatting, and screen phase
  Models/WorkoutMetrics.swift
      # shared workout values, including optional heartRateSampleDate
  Services/Health/ActivityHealthService.swift
      # existing shared HealthKit manager and watch query ownership
  Services/Health/ActivityHealthService+LiveVitals.swift
      # watch-only authorization, statistics queries, updates, and day rollover
  Services/Health/LiveVitalsProviding.swift
      # framework-free service contract consumed by the view model
  ViewModels/LiveVitalsViewModel.swift
      # opt-in state, lifecycle, source selection, and enable/retry actions
  ViewModels/WorkoutViewModel.swift
      # same workout state and commands used by Home and the iPhone
  Services/Health/WorkoutSessionService.swift
      # existing live builder, sample timestamps, workout save, and phone mirroring
```

The passive-data path is **WatchLiveVitalsView → LiveVitalsViewModel → ActivityHealthService → LiveVitalsSnapshot**. During a running workout, the view model can also use **WorkoutViewModel → WorkoutSessionService → WorkoutMetrics**. HealthKit types never reach the view or view models. The view forwards page/app visibility; services own authorization, query configuration, aggregation, session ownership, and cancellation.

`LiveVitalsSnapshot` keeps each quantity optional. A readable zero for today’s steps or energy remains zero; a quantity that HealthKit did not return remains a dash. This avoids describing missing data as a measured zero or as proof that the user denied read access.

## Optional Health and simulator access

A new app launch starts with `isHealthEnabled == false`. This records the user's feature choice for the current session; it is not a HealthKit permission-status check and is not persisted. Opening the app, paging through it, or returning to the foreground never requests Health authorization. **Enable Health** calls the separate package authorization method. After that request completes, subscriptions can resume when Vitals is selected and the app is active without prompting again.

Home uses `ActivityHealthService(scope: .stepsOnly, requestsAuthorizationOnRead: false)`. Its step query runs only while Health is enabled, Home is selected, and the app is active. Its workout navigation stays available during loading, disabled Health, and errors. Memos and Motion do not depend on Health readiness.

In the watch simulator, the activity and workout services do not create an `HKHealthStore`, and Vitals shows a physical-watch explanation instead of an Enable Health button. All four pages remain available. No fake sensor readings are inserted. An explicit workout still requires the appropriate physical-watch permissions; optional app navigation does not bypass them.

## HealthKit query and update policy

After the explicit read request for `heartRate`, `stepCount`, and `activeEnergyBurned`, the service creates one `HKStatisticsCollectionQuery` for each quantity, anchored to local midnight with one-day intervals:

- The passive heart-rate query uses `.mostRecent` and reports the end time of that sample. **Latest Health sample** identifies that source, and **Measured** shows its time; it is not a promise that the optical sensor is measuring at that exact second.
- Steps and active energy use `.cumulativeSum`, allowing HealthKit to reconcile its sources instead of manually adding raw samples.
- Each query supplies an initial-results handler and a `statisticsUpdateHandler`. The update handler keeps monitoring the Health store and publishes a new snapshot when matching data changes.
- At the next local midnight, the service stops the old queries, clears the snapshot, and installs queries for the new day. Leaving the page or making the app inactive also stops the queries so repeated visits do not accumulate subscriptions.

Opening Vitals or enabling its passive queries does **not** turn on the heart-rate sensor or create a workout. For sustained workout measurements, its **Walking Workout** link opens the same controls as Home; the user explicitly starts the existing walking session. The package's `HKLiveWorkoutBuilder` publishes `currentHeartRateBPM` and `heartRateSampleDate` through `WorkoutMetrics`. While that workout is running and Vitals is enabled/streaming, the view model uses the workout sample if its timestamp is at least as recent as the passive result. It labels this source **Workout heart rate**. No second session or heart-rate manager is created. Steps and energy stay daily Health totals rather than changing to workout-only values. [Apple: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), [Apple: `statisticsUpdateHandler`](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery/statisticsupdatehandler).

## Wrist interface and graceful states

The redesigned screen gives heart rate the largest cream numeric type on a black canvas, with steps and energy in compact supporting cards. Coral and lime accents come from the watch presentation layer, which reuses the package's visual identity. A `ViewThatFits` fallback makes the hierarchy Crown-scrollable when larger Dynamic Type or a longer status cannot fit. Each metric supplies a combined VoiceOver label and value; color is supportive rather than the only distinction. This layout still requires current runtime and device accessibility review.

Before activation, Vitals explains that Health is optional. An authorization request shows progress and **Not Now**; failure offers **Retry** and **Use Without Health**. A successful query with no readable samples shows unavailable values instead of claiming denial or zero activity. A later error from one metric is shown without discarding other readable values. Heart rate includes its measurement time when available, and the active-workout status distinguishes workout BPM from daily Health totals. These states do not lock navigation to the other pages.

## Reflection: watch sensor access and live query choice

The Apple Watch differs from the iPhone because the watch contains the optical heart-rate sensor and writes its locally measured samples into HealthKit. The iPhone does not have a built-in heart-rate sensor; it can read heart-rate data after it syncs from Apple Watch or receives samples from a compatible external sensor. Both devices enforce their own HealthKit authorization, so the watch app requests access on the watch instead of assuming the phone’s prompt covers it.

I used long-running **`HKStatisticsCollectionQuery`** objects with `statisticsUpdateHandler` for live Health-store changes. Heart rate uses `.mostRecent`, while steps and active energy use `.cumulativeSum` for the current local day. The initial handler fills the screen from readable saved data, and the update handler runs again when matching samples are saved or deleted. HealthKit computes the daily totals rather than my code manually adding overlapping source samples. A passive query observes saved samples; it does not activate the sensor itself.

For an explicitly started Trailmark workout, I also reuse the existing **`HKLiveWorkoutBuilderDelegate`** updates through `WorkoutSessionService` and `WorkoutMetrics`. A newer running-workout heart-rate sample can reach Vitals before it appears in the passive store query. Its source and measurement time remain visible, while steps/energy keep their daily meaning. This uses the watch's workout sensor access without creating a second session or pretending a store query controls the sensor. [Apple: `HKWorkoutSession`](https://developer.apple.com/documentation/healthkit/hkworkoutsession), [Apple: `statisticsUpdateHandler`](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery/statisticsupdatehandler).

## Physical Apple Watch demo checklist

1. Install the signed continuous Trailmark app on the paired iPhone and physical Apple Watch.
2. Navigate all four pages before enabling Health. Then open Live Vitals, tap **Enable Health**, and respond to the watch's request if it appears. Allow heart rate, steps, and active energy reads.
3. Show all three labeled values and the heart-rate **Measured** time. If a value is unavailable, verify the corresponding data exists and is shared in Health settings.
4. Open **Walking Workout**, explicitly start the existing workout, return to Vitals, and show **Workout heart rate** plus its measurement time changing. Create new activity and allow the saved daily steps/energy to update. Their timing need not match the direct workout BPM stream.
5. Record the before/after values on the physical watch. Simulator output or a successful build is not evidence for the heart-rate rubric item.
6. In Xcode, show that `LiveVitalsSnapshot`, `LiveVitalsViewModel`, and the live-query extension live in `TrailMarkCH10Core`, and that Home and Vitals receive one shared `ActivityHealthService` and `WorkoutViewModel`. End the workout when the demonstration is complete.

## Current limitations and hand-in

- The September 22 watchOS/watchOS Simulator builds and limited navigation check preceded the current redesign. The redesigned watchOS device and watchOS Simulator builds, including the iPhone companion, passed on September 22, 2026. Current visual runtime checks remain pending; automated tests, microphone capture/playback, and sensors were not checked. Earlier navigation evidence does not verify the new layout, real Health prompts, sensor readings, update cadence, day rollover, or device VoiceOver.
- Passive heart-rate frequency is controlled by watchOS. The page may initially show the most recent earlier sample and its timestamp; it must not be presented as an instantaneous reading.
- HealthKit does not reveal whether read access was denied. Missing values can also mean no matching sample has been recorded or synchronized.
- Vitals' Health subscriptions run only after the user enables Health and while its page/app is active. The session-only Enable choice resets at relaunch. An explicitly running workout has its own lifecycle and continues until ended; leaving Vitals does not end it. Vitals is not a complication or Smart Stack widget.
- Daily totals use the watch’s current calendar and time zone and reset at local midnight. Phone and watch values can differ temporarily while Health data synchronizes.

Submit this reflection with the continuous project and a physical-watch recording that visibly proves all three metrics update. The [Course 2 final report](WatchFinalReport.md) describes the integrated Motion feature and quantified reuse. Do not describe the build, simulator, or static screenshots as sensor verification.
