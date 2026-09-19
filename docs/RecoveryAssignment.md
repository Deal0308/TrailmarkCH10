# Class 3 · Assignment 3: Recovery View

The Recovery tab reads sleep and active energy from HealthKit and lets the user save a completed sample activity as an `HKWorkout`. This guide explains the implemented policy and the evidence still needed for submission. It does not claim that a physical-device demonstration or LMS submission has already happened.

## Acceptance criteria and evidence

| Rubric criterion | Points available | Implementation | Evidence to include in the submission |
| --- | ---: | --- | --- |
| Workout written and verified in Health | 30 | Package-owned `HKWorkoutBuilder` save flow; sample workout includes associated active-energy, distance, and average-heart-rate samples. | A screen recording showing the save result followed by the matching record in Apple Health, including date/time, duration, heart rate, and source. |
| Sleep duration read correctly | 20 | `.sleepAnalysis` query includes overlapping samples; asleep intervals are clipped and merged before summing. | Recovery sleep duration and displayed window, supported by the relevant Health sleep records and the reflection below. |
| Seven-day energy trend and Swift Charts | 25 | Daily cumulative active energy in kcal for six previous local dates and today, rendered with `Chart` and `BarMark`. | Chart with all seven date positions and daily values; identify today as partial and explain missing data. |
| Queries in the package | 15 | HealthKit authorization, reads, and writes live in `TrailMarkCH10Core`; the app presents results. | Include the local package sources with the app project. |
| Submission complete | 10 | README, this implementation/reflection guide, app, and local package are included in the project. | Upload the project and required recording/reflection through the course submission workflow; verify that submitted files open. |

These are available rubric points, not a predicted or awarded grade.

## Run and authorize

1. Open `TrailmarkCH10.xcodeproj` in Xcode. Select the `TrailmarkCH10` scheme, configure your signing team, and run on a physical iPhone that supports HealthKit.
2. Open the Recovery tab. Loading it requests read access for Sleep, Active Energy, and Workouts as needed. Workout reads let the provider look for an already-saved attempt when retrying.
3. When choosing **Save sample to Apple Health**, allow writing Workouts, Active Energy, and Walking + Running Distance. The app requests the existing dashboard's Health types separately.
4. Use **Refresh** or pull down to refresh Recovery after changing permissions or adding data in Health. It also reloads when the app becomes active again after an initial load.

To review an existing choice, open Health → profile → Apps under Privacy → TrailmarkCH10 and review the relevant categories. A successful authorization request only establishes that the authorization flow completed; it does not prove that read access was granted. HealthKit deliberately hides read-denial status, so no readable samples cannot be labeled definitively as permission denied. [Apple: authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

## Sleep calculation

The query uses `HKCategoryType(.sleepAnalysis)`. Its window starts at **18:00 yesterday** and ends at **12:00 today**, expressed in the calendar and time zone captured for that refresh. Before noon, the end is **now**, so the query never counts future time.

For example, a refresh at 10:00 on September 12 uses September 11 at 18:00 through September 12 at 10:00. A refresh at 15:00 on September 12 uses September 11 at 18:00 through September 12 at 12:00. These times are local to the device.

The package calculates duration as follows:

1. Query category samples that **overlap** the window, including a sample that began before its start. A strict start-date filter would incorrectly discard that crossing sample.
2. Keep `asleepUnspecified`, `asleepCore`, `asleepDeep`, and `asleepREM`. The older generic asleep value is represented by `asleepUnspecified`. Discard `inBed`, `awake`, and unrecognized values.
3. Clip each retained interval to the query bounds. Ignore intervals with no positive duration.
4. Sort and merge overlapping or adjoining intervals, then sum the elapsed seconds of their union.

Example: 23:00–03:00 and 02:00–07:00 represent eight hours of covered asleep time, not nine. An in-bed record spanning 22:00–08:00 does not add another ten hours. Apple models in-bed time and sleep stages as separate categories that may overlap. [Apple: sleep-analysis categories](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis).

Only in-bed data is insufficient to claim a sleep duration. Missing readable asleep samples remain unavailable rather than becoming zero hours slept. This implementation measures the union of readable asleep intervals; it does not implement Apple's source-priority choices or infer which device is correct when sources disagree. A conflicting awake sample from another source does not erase a readable asleep interval. That limitation can explain differences from the Health app's summary.

## Seven-day active energy

The energy range begins at local midnight six calendar dates before today and ends at the refresh time. It contains **seven calendar dates including today**, rather than a rolling 168-hour interval or seven completed days excluding today.

The package uses HealthKit cumulative statistics for `.activeEnergyBurned`, converted to kilocalories. Daily boundaries follow the selected calendar and time zone. Calendar date arithmetic preserves local-day boundaries across daylight-saving transitions; a day can contain 23 or 25 elapsed hours. The package produces a value slot for every date in the range, even when HealthKit supplies no readable samples.

Each daily value carries sample availability separately from its numeric amount. No readable sample appears as a chart gap and **Unavailable** under **Daily values**. A recorded zero appears as a dot at zero and **0 kcal**. Today is explicitly marked as partial. Expand **Daily values** to read every date and value, including dates with no samples. The chart visualizes energy activity; it does not calculate a medical recovery score. [Apple: statistics collection queries](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery).

## Sample workout save

The sample represents a completed **20-minute indoor walk ending at the initial Save attempt**, with **120 kcal** active energy, **1.5 km** walking distance, and **128 BPM** average heart rate. These are fixed demonstration values, not measurements taken by the app. A retry keeps the same activity identity and dates. After success, the Save action is disabled for that manager instance; relaunching can permit a new sample, so this is not a permanent one-workout limit. Additional samples affect Health activity totals.

The package requests the corresponding write types, checks their sharing authorization, configures a walking workout, begins collection, adds the associated energy/distance/heart-rate samples and identifying metadata, ends collection, and finishes the workout. `finishWorkout` creates and saves the resulting `HKWorkout`. Apple also documents success with no returned workout object when the device is locked; the receipt therefore permits a missing UUID. [Apple: HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder), [Apple: finishing a workout](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:)).

Workout and quantity metadata mark the record as user-entered and indoor, identify it as a Trailmark sample activity, and supply synchronization identifiers. On retry, the provider first looks for a workout with the same identity. If building fails, it discards the builder and attempts to remove the three quantities created by that attempt; a cleanup failure is surfaced for inspection in Health. These measures reduce accidental duplicates and leftover sample data without claiming a transaction across every HealthKit operation.

The result shown in Recovery is a save receipt for locating the record. It does not prove that the student opened Health or made the required recording. Automated tests use controlled inputs and test doubles; they do not write demonstration data to someone's Health store.

## Physical-device demonstration and submission

1. Prepare readable sleep data within the displayed window and active-energy data across the displayed dates. Existing watch/device data is suitable. If the test device has no history, manually add clearly identified test values using Health's **Add Data** action for the relevant category, selecting the intended dates. For sleep, add an **Asleep** interval rather than only **In Bed**. Record that your demonstration uses synthetic data. [Apple: managing Health data](https://support.apple.com/en-us/108779).
2. Start a screen recording. Open Recovery and show the sleep duration, exact window, seven-day energy chart, and expanded **Daily values**. If today is incomplete or some days have no data, explain that on the recording.
3. Show the sample activity's values, tap **Save sample to Apple Health**, and show **Saved workout details** after a successful save. Keep the receipt's start/end time available for matching the record.
4. Switch to Apple Health. Open **Search** (called **Browse** on earlier iOS releases) → **Activity** → **Workouts** → **Show All Data**. Open the record matching the receipt, and show the walking activity, duration, date/time, and the Trailmark app as its source. Health can format distance and energy in the user's selected units. [Apple: viewing Health data](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios).
5. Include the recording, project, local `TrailMarkCH10Core` package, and reflection in the assignment submission. Preserve package paths when zipping the project. Build caches and signing credentials are unnecessary. Confirm that the uploaded recording plays and the project opens with its package dependency.

After recording, remove the synthetic workout if you do not want it in your health history. Use its **Show All Data** entry and select deletion for that record. If prompted, include associated data. Then inspect Active Energy and Walking + Running Distance for demo samples matching the receipt's time/source and remove only those if they remain. Remove any manually seeded test sleep or energy records as well. Reopen Recovery and refresh. Apple's Health guide describes deleting an individual entry; do not use Delete All for this cleanup. [Apple: viewing and managing individual Health records](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios).

## Reflection: why "last night" needs an explicit policy

I used a local-time window from 6 p.m. yesterday to noon today, capped at the current time before noon. A midnight-to-midnight query would cut ordinary overnight sleep into two dates, and a narrow assumed bedtime could miss an early bedtime or late wake-up. The wider window gives the query room to include the overnight episode while keeping its date assignment clear. At an early-morning refresh, the result can still be incomplete because sleep or watch synchronization may be ongoing.

Bracketing is harder than choosing two clock times. A sample can start before the window and finish inside it, so I request overlaps and clip their intervals. HealthKit also contains in-bed periods, awake periods, sleep stages, and records from multiple sources. Summing every sample would confuse time in bed with time asleep and double-count overlaps. I count only asleep categories and sum the union of their intervals. This avoids duplicate time but cannot determine the most reliable source when devices disagree, so the result may differ from Health's source-prioritized summary.

Time zones and daylight-saving changes add another boundary problem. I construct the endpoints using calendar dates and local clock components, rather than adding a fixed number of seconds to midnight. Duration is measured as actual elapsed time between the resulting instants. If the device changes time zone, a later refresh uses the new local window, which can select different samples from the same underlying history.

Finally, 6 p.m.–noon is a documented assignment policy, not a personalized sleep-episode detector. It can include an evening nap or multiple sleep periods, miss naps outside the window, and truncate daytime sleep for a night-shift worker. A future version could let the user select a sleep schedule or a target episode. The current screen exposes its time window so the displayed duration can be interpreted honestly.

## Code and validation scope

| Location | Responsibility |
| --- | --- |
| `TrailMarkCH10Core/Sources/TrailMarkCH10Core/Services/Health/HealthKitRecoveryStore.swift` | HealthKit permissions, sleep/energy queries, workout saving, and save-failure cleanup. |
| `TrailMarkCH10Core/Sources/TrailMarkCH10Core/ViewModels/RecoveryViewModel.swift` | Package-owned loading/error/save states, injectable provider boundary, and sample activity/receipt models. |
| `TrailMarkCH10Core/Sources/TrailMarkCH10Core/Models/RecoverySummary.swift` | Recovery models and local calendar windows. |
| `TrailMarkCH10Core/Sources/TrailMarkCH10Core/Support/RecoveryCalculations.swift` | Clipping and merging asleep intervals to calculate elapsed duration. |
| `TrailmarkCH10/Views/Recovery/RecoveryView.swift` | SwiftUI presentation, Swift Charts, status/error handling, and user actions. |
| `TrailMarkCH10Core/Tests/TrailMarkCH10CoreTests/` | Deterministic tests for package behavior. |

The earlier Recovery-only revision built successfully and passed 39 package tests. The later Course 1 integration reorganizes these sources into MVVM and adds Journeys/media changes. Those earlier results do not validate the integrated revision. No builds, tests, or simulators were run for that integration, as requested. The Health demonstration and course submission remain outstanding. See [the final report](FinalReport.md) for current status and architecture.
