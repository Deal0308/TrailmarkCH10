# Class 3 · Assignment 3: Live vitals

## What was added

Assignment 3 extends the same **TrailMarkWatchCh10 Watch App** target used for Wrist Home and Wrist Memo. The third vertical watch page requests read access to heart rate, step count, and active energy, then displays the latest readable heart-rate sample and today’s cumulative steps and active energy. No second project, target, or HealthKit manager was created.

Wrist Home and Live Vitals share one `ActivityHealthService` instance from `TrailMarkCH10Core`. The watch-only `ActivityHealthService+LiveVitals` extension adds long-running queries while the existing service continues to supply the home’s step summary. `LiveVitalsViewModel` exposes framework-independent screen state, and `WatchLiveVitalsView` contains only SwiftUI presentation and lifecycle forwarding.

The existing watch scheme and its embedded iPhone companion completed a generic build successfully on **September 19, 2026** with Assignment 3 included. Automated tests and simulators were not run, and no physical-watch runtime claim is made. Heart-rate collection and visible live changes still require the required physical Apple Watch demonstration.

## Acceptance criteria and rubric mapping

| Criterion | Points listed | Implementation | Remaining evidence |
| --- | ---: | --- | --- |
| Live heart rate updating on device | 30 | The watch requests heart-rate read access and keeps an `HKStatisticsCollectionQuery` running with `.mostRecent`. Its update handler publishes the latest saved sample and its measurement time through `LiveVitalsSnapshot`. | Show the value and measurement time changing on a physical Apple Watch. |
| Steps and active energy live | 25 | Two long-running statistics collection queries use `.cumulativeSum` for the local day. HealthKit recalculates totals when matching samples are saved or deleted. | Demonstrate at least one visible change to steps and active energy on the watch. |
| Reuses shared HealthKit layer | 20 | Wrist Home and Live Vitals receive the same package-owned `ActivityHealthService`; only its live-query extension is watch-specific. Models and view models remain in the package, and the watch view imports no HealthKit. | Briefly show the package files and single service construction in Xcode. |
| Reflection explains sensor-access difference | 15 | The reflection below distinguishes the watch’s optical sensor from the phone’s Health store and identifies the long-running query type and handlers. | Included below. |

The supplied rubric lists these four rows for 90 points. This document does not invent a missing criterion or claim an awarded grade.

## MVVM and continuous-project structure

```text
TrailMarkWatchCh10 Watch App/
  App/TrailMarkWatchCh10App.swift
      # one composition root for Home, Workout, Voice Memos, and Live Vitals
      # injects the same ActivityHealthService into Home and Live Vitals
  Views/WatchLiveVitalsView.swift
      # dominant heart rate, compact steps/energy, status, and Retry

TrailMarkCH10Core/Sources/TrailMarkCH10Core/
  Models/LiveVitalsSnapshot.swift
      # optional BPM/totals, sample timestamps, formatting, and screen phase
  Services/Health/ActivityHealthService.swift
      # existing shared HealthKit manager and watch query ownership
  Services/Health/ActivityHealthService+LiveVitals.swift
      # watch-only authorization, statistics queries, updates, and day rollover
  Services/Health/LiveVitalsProviding.swift
      # framework-free service contract consumed by the view model
  ViewModels/LiveVitalsViewModel.swift
      # authorization/loading/live/error state and start/stop/retry actions
```

The dependency direction is **WatchLiveVitalsView → LiveVitalsViewModel → ActivityHealthService → LiveVitalsSnapshot**. HealthKit types never reach the view or view model. The view starts and stops updates as the page and app become active or inactive, while the service owns authorization, query configuration, aggregation, and cancellation.

`LiveVitalsSnapshot` keeps each quantity optional. A readable zero for today’s steps or energy remains zero; a quantity that HealthKit did not return remains a dash. This avoids describing missing data as a measured zero or as proof that the user denied read access.

## HealthKit query and update policy

The service requests read access to `heartRate`, `stepCount`, and `activeEnergyBurned`. It then creates one `HKStatisticsCollectionQuery` for each quantity, anchored to local midnight with one-day intervals:

- Heart rate uses `.mostRecent` and reports the end time of that sample. The screen says **Measured** with that time because the value is the latest sample saved in HealthKit, not a promise that the optical sensor is measuring at that exact second.
- Steps and active energy use `.cumulativeSum`, allowing HealthKit to reconcile its sources instead of manually adding raw samples.
- Each query supplies an initial-results handler and a `statisticsUpdateHandler`. The update handler keeps monitoring the Health store and publishes a new snapshot when matching data changes.
- At the next local midnight, the service stops the old queries, clears the snapshot, and installs queries for the new day. Leaving the page or making the app inactive also stops the queries so repeated visits do not accumulate subscriptions.

The Live Vitals page is a passive reader. Opening it does **not** turn on the heart-rate sensor or create a workout. watchOS decides when to save passive heart-rate samples. Trailmark’s existing walking workout uses `HKWorkoutSession` and can generate higher-frequency heart-rate samples while it is active, but that is a separate, explicit user action. [Apple: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), [Apple: `statisticsUpdateHandler`](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery/statisticsupdatehandler).

## Wrist interface and graceful states

The screen gives heart rate the largest type, with steps and energy in two compact supporting cards. A `ViewThatFits` fallback makes the same hierarchy Crown-scrollable when larger Dynamic Type or a longer status cannot fit. Each metric supplies a combined VoiceOver label and value; color is supportive rather than the only distinction.

While Health authorization is being requested, the page shows progress. A failed start shows the error and a Retry button. A successful query with no readable samples stays in a waiting state and shows dashes instead of claiming denial. A later error from one metric is shown without discarding other readable values. The heart-rate row always includes its sample time when available.

## Reflection: watch sensor access and live query choice

The Apple Watch differs from the iPhone because the watch contains the optical heart-rate sensor and writes its locally measured samples into HealthKit. The iPhone does not have a built-in heart-rate sensor; it can read heart-rate data after it syncs from Apple Watch or receives samples from a compatible external sensor. Both devices enforce their own HealthKit authorization, so the watch app requests access on the watch instead of assuming the phone’s prompt covers it.

I used long-running **`HKStatisticsCollectionQuery`** objects with `statisticsUpdateHandler` for live changes. Heart rate uses the query’s `.mostRecent` statistic, while steps and active energy use `.cumulativeSum` for the current local day. The initial handler fills the screen from data already in HealthKit, and the update handler runs again when matching samples are saved or deleted. This gives correct daily totals and avoids manually adding samples from overlapping sources. It also means “live” describes updates from the Health store: a passive query observes the sensor’s saved samples but does not activate the sensor itself.

## Physical Apple Watch demo checklist

1. Install the signed continuous Trailmark app on the paired iPhone and physical Apple Watch.
2. Open Live Vitals and respond to the watch’s Health request if it appears. Allow heart rate, steps, and active energy reads.
3. Show all three labeled values and the heart-rate **Measured** time. If a value is unavailable, verify the corresponding data exists and is shared in Health settings.
4. Create new activity and show steps and active energy changing. For frequent heart-rate samples, start Trailmark’s existing walking workout, return to Live Vitals, and wait for HealthKit to save a new sample.
5. Record the before/after values on the physical watch. Simulator output or a successful build is not evidence for the heart-rate rubric item.
6. In Xcode, show that `LiveVitalsSnapshot`, `LiveVitalsViewModel`, and the live-query extension live in `TrailMarkCH10Core`, and that the watch app constructs one shared `ActivityHealthService` for Home and Live Vitals.

## Current limitations and hand-in

- The September 19 generic watch build establishes source and target integration only. It does not verify Health prompts, sensor readings, update cadence, day rollover, layout on every watch size, or VoiceOver on a device.
- Passive heart-rate frequency is controlled by watchOS. The page may initially show the most recent earlier sample and its timestamp; it must not be presented as an instantaneous reading.
- HealthKit does not reveal whether read access was denied. Missing values can also mean no matching sample has been recorded or synchronized.
- Live Vitals runs while its page is visible and the app is active. It is not a complication, Smart Stack widget, or background sensor recorder.
- Daily totals use the watch’s current calendar and time zone and reset at local midnight. Phone and watch values can differ temporarily while Health data synchronizes.

Submit this reflection with the continuous project and a physical-watch recording that visibly proves all three metrics update. Do not describe the build, simulator, or static screenshots as sensor verification.
