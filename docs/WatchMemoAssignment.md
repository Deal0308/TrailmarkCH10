# Class 2 · Assignment 2: Wrist memo

## What was added

Assignment 2 extends the same **TrailMarkWatchCh10 Watch App** target created for Assignment 1. Swipe from Wrist Home to the Voice Memos page to record a short memo, save it through the package's existing `JournalMediaStore` and `JournalMedia` model, browse saved voice memos, and play one back. No second project, watch target, media schema, or store implementation was created.

The watch recorder uses a mono AAC `.m4a` file at 22.05 kHz and 32 kbps, capped at 60 seconds. This keeps recordings small and the interaction brief. Duration is read from the finalized audio file before the shared store copies it into Application Support and commits its metadata index. The stored filename remains relative.

The redesigned watch scheme and iPhone companion passed generic **watchOS device and watchOS Simulator builds** on **September 22, 2026**. Current visual runtime checks remain pending. An earlier simulator check confirmed all four pages were reachable without Health authorization before the redesign; it does not validate the new memo layout. No automated tests, new simulator launch, microphone recording/playback check, or physical-watch verification was performed for this visual revision. Microphone input and audible playback still require a physical Apple Watch demonstration. See the [Course 2 final report](WatchFinalReport.md).

The redesigned memo page uses a black canvas, compact saved-note rows, and one prominent coral Record/Stop action. Its watch presentation components live in `Views/Components/WatchDesign.swift` and reuse `Presentation/Design/TrailmarkTheme.swift` from the package. Recording, persistence, retry, and playback still belong to the existing shared services and view model.

## Acceptance criteria and rubric mapping

| Criterion | Points listed | Implementation | Remaining evidence |
| --- | ---: | --- | --- |
| Record and save via shared model | 35 | `WatchAudioMemoService` records in the package. `WatchMemoViewModel` saves with the same `JournalMediaStore.importMedia` method and `JournalMedia` model used by iOS. | Record on a physical Apple Watch and show the new row. |
| List and playback on watch | 30 | The watch page lists memo date and duration. Memo detail resolves the stored file through the shared store and plays it with the package's `AudioPlaybackService`. | Demonstrate audible playback on a physical watch or connected audio route. |
| Wrist-appropriate interface | 15 | One large Record/Stop control, a short status, compact rows, and one Play/Pause control. The page supports Crown scrolling and Dynamic Type. | Check fit and VoiceOver on the watch sizes used for the submission. |
| Reflection contrasts iOS and watchOS | Not supplied | The reflection below names the deliberately omitted iPhone features and connects each omission to short wrist interactions and limited space. | Included below. |

The point value for the reflection row was not present in the supplied rubric, so this report does not invent one or claim an awarded grade.

## MVVM and shared-package structure

```text
TrailMarkWatchCh10 Watch App/
  App/TrailMarkWatchCh10App.swift
      # four pages: Home, Voice Memos, Live Vitals, Motion; Workout opens from Home
  Views/WatchMemoListView.swift
      # Record/Stop, compact saved list, and focused playback detail
  Views/Components/WatchDesign.swift
      # wrist-only visual components, backed by the shared design file

TrailMarkCH10Core/Sources/TrailMarkCH10Core/
  Presentation/Design/TrailmarkTheme.swift
      # same visual identity used by the phone
  Models/JournalMedia.swift
      # same audio/video metadata model used by iOS
  Models/CapturedMedia.swift
      # framework-independent completed-capture value
  Models/AudioPlaybackState.swift
      # time, progress, playing state, and level
  Services/Storage/JournalMediaStore.swift
      # same relative-file persistence and JSON index used by iOS
  Services/Media/WatchAudioMemoService.swift
      # watch microphone permission, AVAudioSession, and AVAudioRecorder
  Services/Media/AudioPlaybackService.swift
      # shared iOS/watchOS AVAudioPlayer ownership
  ViewModels/WatchMemoViewModel.swift
      # capture/save/list/playback state and actions
```

The dependency direction is **WatchMemoListView → WatchMemoViewModel → media services/store → shared models**. The watch views import SwiftUI and `TrailMarkCH10Core`; they do not import AVFoundation, request microphone permission, construct players/recorders, or read/write files.

## User flow and graceful states

Voice Memos has no Health dependency. Launching the watch app, opening Vitals, or navigating to Memos does not request Health authorization. On a physical watch, **Enable Health** on Vitals is a separate choice; simulator Health is unavailable without blocking navigation or the memo interface. Microphone permission is still required to record.

1. The user swipes from Wrist Home to Voice Memos and taps **Record Memo**.
2. The package requests microphone permission at that moment and starts the watch audio session only when permission is granted.
3. **Stop & Save**, leaving the app, or reaching 60 seconds finalizes the recording. The service reads duration from the file rather than assuming wall-clock time.
4. The view model imports the recording through `JournalMediaStore`. The store copies the file, writes its `JournalMedia` metadata, and retains only a relative filename.
5. The list reloads immediately. Opening a row presents duration/progress and one Play/Pause action.

Denied microphone access displays a short Settings-oriented explanation. A failed save retains the completed temporary recording and offers **Retry Save** or **Discard**. Missing files and playback failures produce an error instead of a false playing state. Moving away from an active app stops and saves the short recording; leaving playback pauses it. An available zero-length result is rejected rather than indexed as a valid memo.

The original Wrist Memo assignment used separate app containers and the same package model/store. The subsequent [Pocket Sync assignment](PocketSyncAssignment.md) now transfers the audio file to the paired iPhone; each device keeps its own copy. The latest polish adds per-memo transfer status and confirmed deletion from watch detail.

## Reflection: what I deliberately left out

I deliberately left **video capture, camera preview, Photos import, thumbnails, waveform rendering, scrubbing, geotag details, journey controls, and metadata editing** out of the watch capture interface. Those features are useful in the iPhone Field Journal, where the larger display supports previewing media and inspecting context. On a wrist they would crowd the primary task and make the most important controls harder to hit. The later integration adds sync and deletion inside memo detail, keeping the capture screen focused. Deletion requires confirmation and removes only the watch's journal copy.

The watch experience therefore answers only three immediate questions: **Am I recording? Did it save? Can I play it?** Recording uses one large button, saved rows show only date and duration, and playback uses one Play/Pause button with simple progress. A 60-second cap and compressed mono audio also limit watch storage use. Detailed review and richer media management remain appropriate for the iPhone.

## Current limits and hand-in

Build success verifies that the same package APIs compile for the watch and companion targets. It cannot prove microphone input, speaker/Bluetooth routing, real permission prompts, interruptions, or audible playback. Demonstrate those behaviors on a physical Apple Watch for submission.

For the recording, show Wrist Home first to establish that Assignment 1 remains intact, swipe to Voice Memos, record and save a memo, show its duration in the list, then open it and play it. In Xcode, briefly show that `JournalMedia`, `JournalMediaStore`, the recorder service, and the view model live inside `TrailMarkCH10Core`.
