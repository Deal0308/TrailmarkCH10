#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
import Foundation
import Observation
@preconcurrency import WatchConnectivity

/// Transport and retry live in the package. Delivery to the counterpart and a
/// successful import into its local store are deliberately different outcomes.
@MainActor
@Observable
public final class PocketSyncService: NSObject {
    public private(set) var isActivated = false
    public private(set) var isReachable = false
    public private(set) var statusMessage = "Preparing Pocket Sync…"
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false
    public private(set) var lastReceivedSummary: PocketSyncSummary?
    public private(set) var memoStates: [UUID: PocketTransferState] = [:]
    public private(set) var pendingCount = 0

    @ObservationIgnored private let session = WCSession.default
    @ObservationIgnored private var activityReceiver: ((WatchActivityRecord) -> Bool)?
    @ObservationIgnored private var memoReceiver: ((IncomingPocketMemo) async -> Bool)?
    @ObservationIgnored private var summaryReceiver: ((PocketSyncSummary) -> Void)?
    @ObservationIgnored private var importing = false
    @ObservationIgnored private var importAgain = false
    @ObservationIgnored private var activityID: UUID?
    @ObservationIgnored private var activityStartedAt: Date?
    @ObservationIgnored private var activityEndedAt: Date?
    @ObservationIgnored private var lastWorkoutState: WorkoutTrackingState = .idle

    public override init() {
        super.init()
        session.delegate = self
    }

    public func configureReceiving(
        activity: @escaping (WatchActivityRecord) -> Bool,
        memo: @escaping (IncomingPocketMemo) async -> Bool,
        summary: @escaping (PocketSyncSummary) -> Void
    ) {
        activityReceiver = activity
        memoReceiver = memo
        summaryReceiver = summary
    }

    public func activate() {
        guard WCSession.isSupported() else {
            statusMessage = "Pocket Sync is unavailable on this device."
            return
        }
        if session.activationState == .activated { didActivate(error: nil) }
        else {
            statusMessage = "Connecting to Pocket Sync…"
            session.activate()
        }
    }

    public func retry() {
        guard !isWorking else { return }
        errorMessage = nil
        activate()
    }

    #if os(watchOS)
    /// Capture association at recording start; a delayed save cannot attach a memo
    /// to a different workout that began while it was waiting.
    public var memoJourneyID: UUID? {
        if let activityID { return activityID }
        guard let date = UserDefaults.standard.object(forKey: Self.lastActivityDateKey) as? Date,
              (0...(12 * 60 * 60)).contains(Date().timeIntervalSince(date)),
              let value = UserDefaults.standard.string(forKey: Self.lastActivityIDKey) else { return nil }
        return UUID(uuidString: value)
    }

    public func observeWorkout(_ metrics: WorkoutMetrics) {
        if metrics.isActive, activityID == nil {
            activityID = UUID()
            activityStartedAt = metrics.startedAt ?? Date()
            activityEndedAt = nil
        }
        if let start = metrics.startedAt { activityStartedAt = start }
        if metrics.state == .ending, activityEndedAt == nil { activityEndedAt = Date() }
        if metrics.state == .completed, lastWorkoutState != .completed {
            let record = WatchActivityRecord(
                id: activityID ?? UUID(), startDate: metrics.startedAt ?? activityStartedAt ?? Date(),
                endDate: activityEndedAt ?? Date(), duration: metrics.elapsedTime,
                averageHeartRateBPM: metrics.averageHeartRateBPM,
                activeEnergyKilocalories: metrics.activeEnergyKilocalories
            )
            do {
                try PocketSyncArchive.save(record, direction: .outgoing)
                let summary = PocketSyncSummary(activityID: record.id, activityDate: record.startDate, duration: record.duration)
                UserDefaults.standard.set(try JSONEncoder().encode(summary), forKey: Self.summaryKey)
                UserDefaults.standard.set(record.id.uuidString, forKey: Self.lastActivityIDKey)
                UserDefaults.standard.set(record.endDate, forKey: Self.lastActivityDateKey)
                flushOutgoing()
            } catch { report("Workout saved in Health. Pocket Sync could not queue its copy: \(error.localizedDescription)") }
            activityID = nil
        } else if metrics.state == .failed || metrics.state == .idle {
            activityID = nil
        }
        lastWorkoutState = metrics.state
    }

    public func queueMemo(fileURL: URL, item: JournalMedia) throws {
        // Repeated taps never create another in-flight copy or change its Journey ID.
        var pending = try PocketSyncArchive.memos(.outgoing)
        for memo in pending where memo.metadata.mediaID == item.id {
            let url = try PocketSyncArchive.fileURL(memo, direction: .outgoing)
            if !FileManager.default.fileExists(atPath: url.path) {
                try PocketSyncArchive.removeMemo(memo, direction: .outgoing)
            }
        }
        pending = try PocketSyncArchive.memos(.outgoing)
        if !pending.contains(where: { $0.metadata.mediaID == item.id }) {
            let metadata = PocketMemoMetadata(mediaID: item.id, date: item.date, duration: item.duration, journeyID: item.journeyID)
            _ = try PocketSyncArchive.stage(fileURL, metadata: metadata, direction: .outgoing)
        }
        memoStates[item.id] = .queued
        errorMessage = nil
        flushOutgoing()
    }

    private func flushOutgoing() {
        do {
            let activities = try PocketSyncArchive.activities(.outgoing)
            let memos = try PocketSyncArchive.memos(.outgoing)
            pendingCount = activities.count + memos.count
            for memo in memos where memoStates[memo.metadata.mediaID] != .failed { memoStates[memo.metadata.mediaID] = .queued }
            guard isActivated else {
                statusMessage = pendingCount > 0 ? "Saved on watch · waiting to connect" : "Connecting to iPhone…"
                return
            }
            guard session.isCompanionAppInstalled else {
                statusMessage = "Install Trailmark on your paired iPhone to sync. Your recordings stay on this watch."
                return
            }
            let activityIDs = Set(session.outstandingUserInfoTransfers.compactMap {
                ($0.userInfo[Self.activityKey] as? Data).flatMap { try? JSONDecoder().decode(WatchActivityRecord.self, from: $0).id }
            })
            let memoIDs = Set(session.outstandingFileTransfers.compactMap {
                ($0.file.metadata?[Self.memoKey] as? Data).flatMap { try? JSONDecoder().decode(PocketMemoMetadata.self, from: $0).mediaID }
            })
            for activity in activities where !activityIDs.contains(activity.id) {
                session.transferUserInfo([Self.activityKey: try JSONEncoder().encode(activity)])
            }
            for memo in memos where !memoIDs.contains(memo.metadata.mediaID) {
                let url = try PocketSyncArchive.fileURL(memo, direction: .outgoing)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    memoStates[memo.metadata.mediaID] = .failed
                    report("A queued memo file is missing. Open the saved memo and send it again.")
                    continue
                }
                session.transferFile(url, metadata: [Self.memoKey: try JSONEncoder().encode(memo.metadata)])
                memoStates[memo.metadata.mediaID] = .queued
            }
            if let summary = UserDefaults.standard.data(forKey: Self.summaryKey) {
                try session.updateApplicationContext([Self.summaryKey: summary])
            }
            statusMessage = pendingCount > 0 ? "\(pendingCount) item(s) queued · delivery may take a little time" : "Ready to sync with iPhone"
        } catch { report("Sync is waiting for another try. \(error.localizedDescription)") }
    }
    #endif

    private func didActivate(error: Error?) {
        isActivated = error == nil && session.activationState == .activated
        isReachable = session.isReachable
        if let error { report("Could not connect. Try again. \(error.localizedDescription)"); return }
        updateConnection()
        if let data = session.receivedApplicationContext[Self.summaryKey] as? Data,
           let summary = try? JSONDecoder().decode(PocketSyncSummary.self, from: data) { receive(summary: summary) }
        #if os(watchOS)
        flushOutgoing()
        #else
        Task { await importInbox() }
        #endif
    }

    private func updateConnection() {
        isReachable = session.isReachable
        #if os(iOS)
        if !session.isPaired { statusMessage = "Pair an Apple Watch to bring activities and voice memos here." }
        else if !session.isWatchAppInstalled { statusMessage = "Install Trailmark from the Watch app on your iPhone, then open it on your watch." }
        else { statusMessage = "Ready for watch activities and voice memos. Delivery can continue while the apps are in the background." }
        #else
        // Reachability describes live messaging, not whether queued delivery can run.
        if pendingCount == 0 { statusMessage = "Ready to sync with iPhone" }
        #endif
    }

    private func receive(activity: WatchActivityRecord) {
        do {
            try PocketSyncArchive.save(activity, direction: .incoming)
            Task { await importInbox() }
        } catch { report("An activity arrived but could not be stored. \(error.localizedDescription)") }
    }

    private func receive(summary: PocketSyncSummary) {
        lastReceivedSummary = summary
        summaryReceiver?(summary)
    }

    private func importInbox() async {
        guard !importing else { importAgain = true; return }
        importing = true
        isWorking = true
        defer { importing = false; isWorking = false }
        repeat {
            importAgain = false
            do {
                var saved = 0
                for activity in try PocketSyncArchive.activities(.incoming) {
                    if activityReceiver?(activity) == true {
                        try PocketSyncArchive.removeActivity(activity.id, direction: .incoming)
                        saved += 1
                    }
                }
                for memo in try PocketSyncArchive.memos(.incoming) {
                    let incoming = IncomingPocketMemo(metadata: memo.metadata, stagedFileURL: try PocketSyncArchive.fileURL(memo, direction: .incoming))
                    if await memoReceiver?(incoming) == true {
                        try PocketSyncArchive.removeMemo(memo, direction: .incoming)
                        saved += 1
                    }
                }
                pendingCount = try PocketSyncArchive.activities(.incoming).count + PocketSyncArchive.memos(.incoming).count
                if pendingCount > 0 { report("\(pendingCount) received item(s) are waiting to be saved. Free some storage if needed, then tap Retry sync.") }
                else if saved > 0 { errorMessage = nil; statusMessage = "Saved on this iPhone · find your activities in Journeys and memos in Journal" }
            } catch { report("Received items are waiting to be saved. \(error.localizedDescription)") }
        } while importAgain
    }

    private func report(_ message: String) { errorMessage = message }

    #if os(watchOS)
    private func finishMemo(_ metadata: PocketMemoMetadata, error: String?) {
        if let error {
            memoStates[metadata.mediaID] = .failed
            report("Your memo is safe on watch. Retry sync. \(error)")
            return
        }
        do {
            for memo in try PocketSyncArchive.memos(.outgoing) where memo.metadata.mediaID == metadata.mediaID {
                try PocketSyncArchive.removeMemo(memo, direction: .outgoing)
            }
            memoStates[metadata.mediaID] = .transferred
            pendingCount = try PocketSyncArchive.activities(.outgoing).count + PocketSyncArchive.memos(.outgoing).count
            statusMessage = "Memo transferred · open Journal on iPhone to play it"
        } catch { report("Memo transferred, but its temporary copy needs cleanup. Retry sync. \(error.localizedDescription)") }
    }

    private func finishActivity(_ id: UUID, error: String?) {
        if let error { report("Activity saved on watch. Retry sync. \(error)"); return }
        do {
            try PocketSyncArchive.removeActivity(id, direction: .outgoing)
            pendingCount = try PocketSyncArchive.activities(.outgoing).count + PocketSyncArchive.memos(.outgoing).count
            statusMessage = "Activity transferred · open Journeys on iPhone"
        } catch { report("Activity transferred. Retry sync to finish cleanup. \(error.localizedDescription)") }
    }
    #endif

    nonisolated private static let activityKey = "trailmark.activity.v1"
    nonisolated private static let summaryKey = "trailmark.summary.v1"
    nonisolated private static let memoKey = "trailmark.memo.v1"
    nonisolated private static let lastActivityIDKey = "trailmark.pocket-sync.last-activity-id"
    nonisolated private static let lastActivityDateKey = "trailmark.pocket-sync.last-activity-date"
}

extension PocketSyncService: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor [weak self] in self?.didActivate(error: error) }
    }
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateConnection() }
    }
    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[Self.activityKey] as? Data,
              let activity = try? JSONDecoder().decode(WatchActivityRecord.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.receive(activity: activity) }
    }
    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.summaryKey] as? Data,
              let summary = try? JSONDecoder().decode(PocketSyncSummary.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.receive(summary: summary) }
    }
    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let data = file.metadata?[Self.memoKey] as? Data,
              let metadata = try? JSONDecoder().decode(PocketMemoMetadata.self, from: data),
              metadata.duration.isFinite, metadata.duration > 0 else { return }
        do {
            // Copy bytes and manifest synchronously, before WC deletes its temporary URL.
            _ = try PocketSyncArchive.stage(file.fileURL, metadata: metadata, direction: .incoming)
            Task { @MainActor [weak self] in await self?.importInbox() }
        } catch {
            let message = error.localizedDescription
            Task { @MainActor [weak self] in self?.report("A memo could not be received. Send it again from your watch. \(message)") }
        }
    }
    #if os(iOS)
    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateConnection() }
    }
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.isActivated = false; self?.statusMessage = "Switching Apple Watch connection…" }
    }
    nonisolated public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
    #if os(watchOS)
    nonisolated public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        guard let data = fileTransfer.file.metadata?[Self.memoKey] as? Data,
              let metadata = try? JSONDecoder().decode(PocketMemoMetadata.self, from: data) else { return }
        let message = error?.localizedDescription
        Task { @MainActor [weak self] in self?.finishMemo(metadata, error: message) }
    }
    nonisolated public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: (any Error)?) {
        guard let data = userInfoTransfer.userInfo[Self.activityKey] as? Data,
              let activity = try? JSONDecoder().decode(WatchActivityRecord.self, from: data) else { return }
        let message = error?.localizedDescription
        Task { @MainActor [weak self] in self?.finishActivity(activity.id, error: message) }
    }
    #endif
}
#endif
