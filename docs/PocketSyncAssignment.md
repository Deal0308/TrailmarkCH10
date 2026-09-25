# Class 1 — Assignment 1: Pocket sync

Pocket Sync extends the same `TrailmarkCH10.xcodeproj`, watch target, and `TrailMarkCH10Core` package used by the earlier assignments. It does not add a second app or copy activity/media models into either target.

## What was added

- `PocketSyncService` in the shared package owns `WCSession`, activates it on iPhone and Apple Watch, and implements all delegate callbacks.
- `WatchActivityRecord`, `PocketSyncSummary`, and `PocketMemoMetadata` are framework-independent, Codable package models.
- A completed watch workout is queued to the phone and imported idempotently into `JourneyStore` as **Apple Watch walk**.
- A saved watch voice memo is copied to a private transfer outbox, transferred with its metadata, and imported into the iPhone's existing `JournalMediaStore`. Its stored filename remains relative.
- The activity ID is also the Journey ID. Memos captured during that activity, or within 12 hours of the most recently completed activity, use that ID and appear in the Journey detail screen. The recent ID survives a watch-app relaunch, and delivery order does not matter.
- The watch memo detail includes **Sync to iPhone**, so a saved recording can be queued again. The iPhone deduplicates both activities and memo IDs.

The iPhone Journey list identifies imported records with **Synced from Watch**. Journey detail shows the transferred duration, average heart rate, active energy, and any associated voice memo. The memo uses the existing iPhone playback screen.

### Reliability and feedback refinement

The interaction polish pass adds `PocketSyncArchive` for atomic on-disk manifests, `PocketSyncViewModel` for presentation, a sync status/retry disclosure in iPhone Journeys, and per-memo queued/transferred/failed labels on watch. Activity and memo queues reload after activation or relaunch. Files received by WatchConnectivity are copied synchronously with metadata before its temporary URL expires; iPhone retries failed imports and cleans staging files only after a successful import. Duplicate IDs do not create duplicate records. Watch workout totals remain separate from iPhone Health queries.

“Transferred to iPhone” reflects WatchConnectivity's transport callback, not a claim that the iPhone successfully indexed the item. The iPhone reports its own successful save or retryable import error. A live-message reachability change is not reported as “offline,” because queued background delivery has different requirements. Watch memo journey IDs are captured at recording start and saved in the shared media model, so a delayed save/retry cannot reassign a recording to a newer workout.

Apple requires file-transfer verification on a paired iPhone and Apple Watch; the simulator does not deliver the file-receipt delegate callback. See [Apple's file receipt documentation](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate/session(_:didreceive:)).

## Transfer choices and reflection

### Latest summary — `updateApplicationContext`

The small “latest watch activity” summary uses **application context** because it is replaceable state. The phone needs the newest summary, not a history of stale summaries. A live message would fail whenever the counterpart was not reachable; `transferUserInfo` would unnecessarily queue every obsolete summary; and file transfer is intended for file-backed data rather than a few Codable fields.

### Completed activity record — `transferUserInfo`

Each completed activity uses **user info** because every record matters and should be queued for background delivery when the iPhone is temporarily unavailable. Application context would overwrite an older unsent activity with the newest one. A live message requires both apps to be reachable at that moment and therefore is not reliable enough for a completed workout. A file would add needless file lifecycle work for a small structured payload.

### Voice-memo audio — `transferFile`

The `.m4a` memo uses **file transfer** because the payload is file-backed binary media and should continue in the background. Its ID, date, duration, and optional Journey ID travel as file metadata. A message is reachability-dependent and is not appropriate for audio bytes; application context would replace one memo with another; and user info is suited to property-list metadata, not a media file. The watch first copies the recording into a package-owned outbox so deleting the local journal entry cannot invalidate an in-flight transfer.

`sendMessage` is intentionally not part of the required data path. Reachability can improve immediacy, but correctness cannot depend on both apps being active.

## MVVM and package boundary

```text
Watch views
  → WatchMemoViewModel / WorkoutViewModel
  → WatchAudioMemoService / WorkoutSessionService
  → PocketSyncService
  → WCSession queued transfer
  → iPhone AppModel composition callbacks
  → JourneysViewModel / JournalViewModel
  → JourneyStore / JournalMediaStore
  → iPhone Journey and memo playback views
```

Both app roots only construct dependencies and activate the shared service. Views import SwiftUI and `TrailMarkCH10Core`; they do not import WatchConnectivity or perform file operations. Transport, staging, metadata encoding, receipt handling, deduplication, and relative-path persistence stay in the package.

## Acceptance criteria and evidence

| Criterion | Implementation | Demonstration evidence still needed |
| --- | --- | --- |
| WCSession established and activated on both sides | Both composition roots retain and activate one `PocketSyncService`; its delegate handles activation, reachability, background user info, application context, and files. | Show the paired apps running on iPhone and Apple Watch. |
| Activity syncs watch → phone into the list | Workout completion queues a `WatchActivityRecord` with `transferUserInfo`; iPhone imports it into `JourneyStore` using the record ID. | End a watch workout, then show **Apple Watch walk** in iPhone Journeys. |
| Memo file transfers and plays on iOS | Watch stages the `.m4a` and calls `transferFile`; iPhone stages the temporary receive URL, imports it into `JournalMediaStore`, and uses the existing audio player. | Record/stop on watch, then open and play it on iPhone. |
| Correct transfer type per payload | Application context = replaceable latest summary; user info = durable activity events; file = audio bytes. | Include the reflection above in the submission. |
| Submission complete | Source and reflection are in this continuous project. | Add a paired-device demo recording or screenshots before submission. |

## Demo sequence

1. Install the iPhone app and its companion watch app from this project on a paired iPhone and Apple Watch.
2. Open each app once so both sessions activate.
3. On Apple Watch, open **Start Workout**, start a walk, wait for readings, and tap **End**.
4. Record and save a voice memo. If needed, open the saved memo and tap **Sync to iPhone**.
5. On iPhone, open **Journeys** and select **Apple Watch walk**. Show the watch metrics and associated memo.
6. Play the memo in Journey detail or Field Journal.
7. For stronger evidence, turn off or separate the phone during capture, reconnect it, and show that queued delivery still completes.

The generic iOS and watchOS device builds passed on September 24, 2026. No simulator or app was launched for this assignment. A real paired-device recording is still needed to prove cross-device delivery and audio playback at submission time.
