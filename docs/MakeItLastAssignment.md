# Class 3 · Assignment 3 — Make it last

Trailmark uses the same iPhone app, watch app, and shared `TrailMarkCH10Core` package as the earlier assignments. This report focuses on **Motion** on Apple Watch: Core Motion samples wrist acceleration, a one-second window derives movement intensity, and a SwiftUI page shows the result. Motion starts only after tapping **Start Sensing** and stops when the page or app becomes inactive.

**Submission status:** The code optimizations are implemented and generic watchOS/iOS device builds pass without compiler warnings. No physical Apple Watch is connected to this Mac as of September 29, 2026. Instruments traces, before/after measurements, and their screenshots are **not yet available**. The calculated rates below are design values, not measured battery or CPU savings. This report is not ready to submit for the profiling and measurement rubric rows until those real values and screenshots are added.

## What changed

| Optimization | Before | After | Expected effect | Tradeoff |
| --- | --- | --- | --- | --- |
| Sensor sampling | Requested interval 0.1 s (10 Hz) | Requested interval 0.2 s (5 Hz) | At most half as many delivered samples and half as many per-sample window updates if hardware honors the request. | A wrist movement shorter than 0.2 s is easier to miss. The screen is a broad movement signal, not a fall detector or step counter. |
| Display cadence | Snapshot at most every 0.5 s (2 Hz) | Snapshot at most every 1 s (1 Hz) | At most half as many observable model changes and UI redraw opportunities. | A change can take up to about one second to appear; the one-second RMS window already smooths brief movements. |
| Main-thread work | A new MainActor task for every sensor callback | The existing serial sensor queue keeps the window and sends one immutable result only when the display is due | Avoids most cross-actor tasks, repeated main-thread collection edits, and unnecessary `MotionViewModel` assignments. | More state lives on a dedicated queue. A new accumulator is created per capture, and the existing generation check rejects results from earlier captures. |

These are three code changes supporting at least two distinct optimizations. The one-second window, RMS calculation, Still/Moving hysteresis thresholds, permission behavior, and stop-on-leave behavior remain the same. `MotionService` still owns Core Motion inside the package; `WatchMotionView` only renders `MotionViewModel` state.

## Calculated rates, not Instruments measurements

| Quantity from source settings | Previous commit `0eb0e3e` | Current optimized code | Calculation |
| --- | ---: | ---: | --- |
| Requested motion deliveries during 60 s | 600 | 300 | 60 s ÷ requested interval |
| Maximum display publications during 60 s after warm-up | 120 | 60 | 60 s ÷ display interval |
| MainActor tasks caused by motion samples during 60 s | Up to 600 | Up to 60 | Previous: one per sample; current: one per published result |

Core Motion can deliver at a different rate. Apple recommends checking **sample timestamps** for actual cadence. These calculations establish a falsifiable expectation; they are **not** the assignment's required before/after measurements. No energy reduction percentage is claimed. [Apple: device motion delivery](https://developer.apple.com/documentation/coremotion/cmmotionmanager), [Apple: motion interval and timestamps](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval).

## Physical-watch Instruments protocol

1. Connect and unlock a physical Apple Watch and its paired iPhone, enable Developer Mode, and confirm the watch appears as a device in Xcode. Record its model, watchOS version, battery level, and Xcode version. A simulator cannot provide real watch sensor or energy evidence.
2. Record the **before** version from [commit `0eb0e3e`](https://github.com/Deal0308/TrailmarkCH10/commit/0eb0e3e996a89aeeb8ee1bee301f2917ddca5e3e) on that watch. Then record the **after** version from this project's current branch. Use the same watch, build configuration, screen brightness, motion routine, and session duration. Preserve both traces. If checking out the old commit in this single project, first save/commit current work and return to the current branch afterward.
3. In Xcode choose the physical watch destination, then **Product → Profile**. In Instruments choose **Time Profiler** for CPU and **Allocations** for memory. This Xcode installation includes both templates. Record the Trailmark watch app process, not the whole Mac. Apple's newer **Power Profiler** documentation currently lists iPhone and iPad availability, so do not present a Mac or iPhone power trace as a watch energy reading. Use a watch-compatible Energy template only if Instruments actually offers it for the connected watch.
4. For each trace, open **Motion → Start Sensing**. After the one-second warm-up, keep the page visible for three identical one-minute cycles: 20 s wrist still, 20 s deliberate moderate wrist movement, 20 s still. Keep unrelated apps closed and keep the watch charging state the same. Stop sensing and stop recording. Repeat each version at least three times if practical; use the median to reduce noise.
5. For each version, select the same 180-second active region in Instruments. Record Time Profiler CPU time or sample percentage for Trailmark and Allocations live bytes/peak live bytes; note the units and exact selected range. If Energy is available on this watch, record its displayed energy-impact value and units. Capture screenshots with the app/process name, device, selected time range, and measured values visible.

[Apple: profiling apps with Instruments](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance), [Apple: Power Profiler device scope](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler).

## Measurements to enter from Instruments

| Metric, same 180-second active region | Before trace | After trace | Change | Screenshot filenames |
| --- | --- | --- | --- | --- |
| Watch app CPU time or Time Profiler sample %, with unit | **Pending physical-watch trace** | **Pending physical-watch trace** | **Pending** | `screenshots/motion-before-cpu.png`, `screenshots/motion-after-cpu.png` |
| Allocations peak live bytes, with unit | **Pending physical-watch trace** | **Pending physical-watch trace** | **Pending** | `screenshots/motion-before-memory.png`, `screenshots/motion-after-memory.png` |
| Energy impact, only if a supported watch instrument supplies it | **Pending / may be unavailable** | **Pending / may be unavailable** | **Pending** | Add actual watch screenshots if supported |
| Observed motion responsiveness (same wrist routine) | **Pending device observation** | **Pending device observation** | Describe any slower or missed changes | Optional watch recording |

**Watch / OS / Xcode / battery / brightness:** pending. **Before trace date and build:** pending. **After trace date and build:** pending. **Raw `.trace` file locations:** pending. **Source link:** [TrailmarkCH10 on GitHub](https://github.com/Deal0308/TrailmarkCH10) (verify that this optimized revision has been pushed before submission).

The previous and new values must be copied from the same Instruments metric and time selection. Calculate change as `(after − before) / before × 100%` only after filling real measurements. Attach the actual screenshots under `docs/screenshots/`; a graph reconstructed from the requested rates cannot replace them.

## Tradeoff note

Motion is a deliberately low-detail wrist movement indicator. Five requested sensor samples each second are enough to maintain a rolling one-second RMS and hysteresis in source code, while allowing less sensor and callback work than ten. Publishing once each second avoids redraws that do not help the user interpret a smoothed one-second signal. A brief acceleration spike or a fast change of movement state may appear later or be missed. That loss of immediacy is acceptable for this screen's Still/Moving cue; it would not be acceptable for safety detection or precise motion analysis. Actual energy and CPU benefits remain a hypothesis until the paired before/after traces above are captured.

## Rubric status

| Criterion | Points supplied | Current evidence |
| --- | ---: | --- |
| Valid Instruments profile of a real feature | 25 | **Pending:** no physical watch available to trace. |
| Two genuine optimizations | 30 | **Implemented:** 10→5 Hz sampling, 2→1 Hz publication, and sensor-queue aggregation. |
| Before/after measurements documented | 25 | **Pending:** calculated source rates are labeled separately; Instruments values and screenshots are blank. |
| Tradeoff analysis | 10 | **Documented above**, to revisit after checking signal behavior and actual traces. |

The supplied rubric totals 90 points. This report deliberately does not claim completed profiling or measurement credit without device evidence.
