#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
import Foundation
import Observation
@preconcurrency import WatchConnectivity

/// Owns WatchConnectivity activation and transport selection for both apps.
/// Views never import WatchConnectivity; they consume state exposed by package view models.
@MainActor
@Observable
public final class PocketSyncService: NSObject {
    public private(set) var isActivated = false
    public private(set) var isReachable = false
    public private(set) var statusMessage = "Pocket Sync is preparing."
    public private(set) var lastReceivedSummary: PocketSyncSummary?

    @ObservationIgnored private let session: WCSession
    @ObservationIgnored private var activityReceiver: ((WatchActivityRecord) -> Void)?
    @ObservationIgnored private var memoReceiver: ((IncomingPocketMemo) -> Void)?
    @ObservationIgnored private var summaryReceiver: ((PocketSyncSummary) -> Void)?

    #if os(watchOS)
    @ObservationIgnored private var activityID: UUID?
    @ObservationIgnored private var activityStartedAt: Date?
    @ObservationIgnored private var lastCompletedActivityID: UUID?
    @ObservationIgnored private var lastCompletedActivityDate: Date?
    @ObservationIgnored private var lastWorkoutState: WorkoutTrackingState = .idle
    @ObservationIgnored private var pendingActivities: [WatchActivityRecord] = []
    @ObservationIgnored private var pendingSummaries: [PocketSyncSummary] = []
    @ObservationIgnored private var pendingMemoFiles: [(URL, PocketMemoMetadata)] = []
    #endif

    public override init() {
        session = .default
        super.init()
        #if os(watchOS)
        let savedDate = UserDefaults.standard.object(forKey: Self.lastActivityDateKey) as? Date
        if let savedID = UserDefaults.standard.string(forKey: Self.lastActivityIDKey),
           let savedDate,
           Date().timeIntervalSince(savedDate) < Self.memoAssociationWindow {
            lastCompletedActivityID = UUID(uuidString: savedID)
            lastCompletedActivityDate = savedDate
        }
        #endif
        session.delegate = self
    }

    /// The iPhone composition root installs package-owned import handlers before activation.
    public func configureReceiving(
        activity: @escaping (WatchActivityRecord) -> Void,
        memo: @escaping (IncomingPocketMemo) -> Void,
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
        session.activate()
        statusMessage = "Activating Pocket Sync…"
    }

    #if os(watchOS)
    /// Receives the shared workout model and queues exactly one durable activity record
    /// when a workout reaches `.completed`.
    public func observeWorkout(_ metrics: WorkoutMetrics) {
        if metrics.isActive, activityID == nil {
            activityID = UUID()
            activityStartedAt = metrics.startedAt ?? Date()
        }
        if let startedAt = metrics.startedAt { activityStartedAt = startedAt }

        if metrics.state == .completed, lastWorkoutState != .completed {
            let id = activityID ?? UUID()
            let start = metrics.startedAt ?? activityStartedAt ?? Date().addingTimeInterval(-metrics.elapsedTime)
            let end = Date()
            let record = WatchActivityRecord(
                id: id,
                startDate: start,
                endDate: end,
                duration: metrics.elapsedTime,
                averageHeartRateBPM: metrics.averageHeartRateBPM,
                activeEnergyKilocalories: metrics.activeEnergyKilocalories
            )
            pendingActivities.append(record)
            let summary = PocketSyncSummary(activityID: id, activityDate: start, duration: metrics.elapsedTime)
            pendingSummaries = [summary]
            lastCompletedActivityID = id
            lastCompletedActivityDate = end
            UserDefaults.standard.set(id.uuidString, forKey: Self.lastActivityIDKey)
            UserDefaults.standard.set(end, forKey: Self.lastActivityDateKey)
            activityID = nil
            activityStartedAt = nil
            flushPendingTransfers()
        } else if metrics.state == .failed || metrics.state == .idle {
            activityID = nil
            activityStartedAt = nil
        }
        lastWorkoutState = metrics.state
    }

    /// Copies the memo to an outbox before handing it to WatchConnectivity, so
    /// deleting the watch's local journal item cannot invalidate an in-flight transfer.
    public func queueMemo(fileURL: URL, item: JournalMedia) throws {
        let metadata = PocketMemoMetadata(
            mediaID: item.id,
            date: item.date,
            duration: item.duration,
            journeyID: item.journeyID ?? activityID ?? recentCompletedActivityID
        )
        let staged = try Self.stageOutgoingFile(from: fileURL)
        pendingMemoFiles.append((staged, metadata))
        flushPendingTransfers()
    }

    private var recentCompletedActivityID: UUID? {
        guard let lastCompletedActivityID, let lastCompletedActivityDate,
              Date().timeIntervalSince(lastCompletedActivityDate) < Self.memoAssociationWindow else { return nil }
        return lastCompletedActivityID
    }

    private func flushPendingTransfers() {
        guard session.activationState == .activated else {
            statusMessage = "Saved on Apple Watch · waiting for Pocket Sync"
            return
        }

        for activity in pendingActivities {
            guard let data = try? JSONEncoder().encode(activity) else { continue }
            session.transferUserInfo([Self.activityKey: data])
        }
        pendingActivities.removeAll()

        if let summary = pendingSummaries.last,
           let data = try? JSONEncoder().encode(summary) {
            do {
                try session.updateApplicationContext([Self.summaryKey: data])
                pendingSummaries.removeAll()
            } catch {
                statusMessage = "Activity saved · latest summary will retry when Trailmark reopens"
            }
        }

        for (url, metadata) in pendingMemoFiles {
            guard let data = try? JSONEncoder().encode(metadata) else { continue }
            session.transferFile(url, metadata: [Self.memoKey: data])
        }
        pendingMemoFiles.removeAll()
        statusMessage = "Queued for iPhone · delivery continues in the background"
    }
    #endif

    private func didActivate(error: Error?) {
        isActivated = error == nil && session.activationState == .activated
        isReachable = session.isReachable
        if let error {
            statusMessage = "Pocket Sync could not activate: \(error.localizedDescription)"
        } else {
            statusMessage = "Pocket Sync active · background delivery ready"
            #if os(watchOS)
            flushPendingTransfers()
            #endif
        }
    }

    private func updateReachability() {
        isReachable = session.isReachable
        if isActivated {
            statusMessage = isReachable
                ? "iPhone nearby · background delivery ready"
                : "iPhone offline · transfers remain queued"
        }
    }

    private func receive(activity: WatchActivityRecord) {
        activityReceiver?(activity)
        statusMessage = "Watch activity added to Journeys"
    }

    private func receive(summary: PocketSyncSummary) {
        lastReceivedSummary = summary
        summaryReceiver?(summary)
    }

    private func receive(memo: IncomingPocketMemo) {
        memoReceiver?(memo)
        statusMessage = "Watch voice memo added to the journal"
    }

    #if os(watchOS)
    private func finish(fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            statusMessage = "Memo transfer needs another try: \(error.localizedDescription)"
            return
        }
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        statusMessage = "Voice memo delivered to iPhone"
    }
    #endif

    nonisolated private static func stageIncomingFile(from source: URL) throws -> URL {
        let directory = try syncDirectory(named: "Inbox")
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    nonisolated private static func stageOutgoingFile(from source: URL) throws -> URL {
        let directory = try syncDirectory(named: "Outbox")
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    nonisolated private static func syncDirectory(named name: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("TrailmarkCore/PocketSync/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static let activityKey = "trailmark.activity.v1"
    nonisolated private static let summaryKey = "trailmark.summary.v1"
    nonisolated private static let memoKey = "trailmark.memo.v1"
    nonisolated private static let lastActivityIDKey = "trailmark.pocket-sync.last-activity-id"
    nonisolated private static let lastActivityDateKey = "trailmark.pocket-sync.last-activity-date"
    nonisolated private static let memoAssociationWindow: TimeInterval = 12 * 60 * 60
}

extension PocketSyncService: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor [weak self] in self?.didActivate(error: error) }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateReachability() }
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
              metadata.duration > 0,
              let stagedURL = try? Self.stageIncomingFile(from: file.fileURL) else { return }
        let incoming = IncomingPocketMemo(metadata: metadata, stagedFileURL: stagedURL)
        Task { @MainActor [weak self] in self?.receive(memo: incoming) }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    #if os(watchOS)
    nonisolated public func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: (any Error)?
    ) {
        Task { @MainActor [weak self] in self?.finish(fileTransfer: fileTransfer, error: error) }
    }
    #endif
}
#endif
