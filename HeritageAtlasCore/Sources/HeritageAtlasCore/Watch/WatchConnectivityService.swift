import Foundation

#if os(iOS) || os(watchOS)
import WatchConnectivity

public final class WatchConnectivityService: NSObject, WCSessionDelegate, @unchecked Sendable {
    public static let shared = WatchConnectivityService()
    public static let snapshotContextKey = "heritageAtlas.snapshot"
    public static let audioMessageKey = "heritageAtlas.audio"
    public static let snapshotFileType = "snapshot"
    public static let audioFileType = "audioRecording"
    public static let audioPayloadKey = "payload"
    public static let audioPersonIDKey = "personID"

    public var onSnapshotReceived: (@Sendable (WatchSnapshot) -> Void)?
    public var onAudioMessageReceived: (@Sendable (WatchAudioRecordingMessage) -> Void)?
    public var onAudioFileReceived: (@Sendable (URL, WatchAudioRecordingMessage) -> Void)?
    public var onAudioFileTransferFinished: (@Sendable (URL, (any Error)?) -> Void)?

    private override init() {
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iPhone: push the latest cache subset. Prefers application context; large payloads use file transfer.
    public func sendSnapshot(_ snapshot: WatchSnapshot) throws {
        guard WCSession.isSupported() else { return }
        let data = try JSONEncoder().encode(snapshot)
        let session = WCSession.default
        if data.count < 50_000, session.activationState == .activated {
            try session.updateApplicationContext([Self.snapshotContextKey: data])
        } else {
            let url = FileManager.default.temporaryDirectory.appending(path: "heritage-atlas-watch-snapshot.json")
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["type": Self.snapshotFileType])
        }
    }

    /// Watch → iPhone: metadata for a recorded story. The audio file is transferred separately.
    public func sendAudioRecordingMessage(_ message: WatchAudioRecordingMessage) throws {
        guard WCSession.isSupported() else { return }
        let data = try JSONEncoder().encode(message)
        WCSession.default.transferUserInfo([Self.audioMessageKey: data])
    }

    /// Watch → iPhone: audio file plus metadata. iPhone is the source of truth and persists a Memory.
    @discardableResult
    public func sendAudioRecording(fileURL: URL, message: WatchAudioRecordingMessage) throws -> WCSessionFileTransfer? {
        guard WCSession.isSupported() else { return nil }
        var metadata: [String: Any] = ["type": Self.audioFileType]
        if let payload = try? JSONEncoder().encode(message),
           let payloadString = String(data: payload, encoding: .utf8) {
            metadata[Self.audioPayloadKey] = payloadString
        }
        if let personID = message.personID {
            metadata[Self.audioPersonIDKey] = personID.uuidString
        }
        metadata["fileName"] = message.fileName
        return WCSession.default.transferFile(fileURL, metadata: metadata)
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        _ = error
        guard activationState == .activated else { return }
        handleSnapshotData(session.receivedApplicationContext[Self.snapshotContextKey] as? Data)
    }

#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        _ = session
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        _ = session
        handleSnapshotData(applicationContext[Self.snapshotContextKey] as? Data)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        _ = session
        if let data = userInfo[Self.audioMessageKey] as? Data,
           let message = try? JSONDecoder().decode(WatchAudioRecordingMessage.self, from: data) {
            onAudioMessageReceived?(message)
        }
        handleSnapshotData(userInfo[Self.snapshotContextKey] as? Data)
    }

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        _ = session
        let type = file.metadata?["type"] as? String
        if type == Self.audioFileType || file.fileURL.pathExtension.lowercased() == "m4a" {
            handleAudioFile(file)
            return
        }
        guard type == Self.snapshotFileType else { return }
        let data = try? Data(contentsOf: file.fileURL)
        handleSnapshotData(data)
    }

    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        _ = session
        onAudioFileTransferFinished?(fileTransfer.file.fileURL, error)
    }

    private func handleAudioFile(_ file: WCSessionFile) {
        let ext = file.fileURL.pathExtension.isEmpty ? "m4a" : file.fileURL.pathExtension
        let destination = FileManager.default.temporaryDirectory.appending(path: "watch-\(UUID().uuidString).\(ext)")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: destination)
        } catch {
            return
        }
        let message = decodeAudioMessage(from: file.metadata, fallbackFileName: file.fileURL.lastPathComponent)
        onAudioFileReceived?(destination, message)
        onAudioMessageReceived?(message)
    }

    private func decodeAudioMessage(from metadata: [String: Any]?, fallbackFileName: String) -> WatchAudioRecordingMessage {
        if let payload = metadata?[Self.audioPayloadKey] as? String,
           let data = payload.data(using: .utf8),
           let message = try? JSONDecoder().decode(WatchAudioRecordingMessage.self, from: data) {
            return message
        }
        if let data = metadata?[Self.audioPayloadKey] as? Data,
           let message = try? JSONDecoder().decode(WatchAudioRecordingMessage.self, from: data) {
            return message
        }
        let personID = (metadata?[Self.audioPersonIDKey] as? String).flatMap(UUID.init(uuidString:))
        return WatchAudioRecordingMessage(
            fileName: (metadata?["fileName"] as? String) ?? fallbackFileName,
            personID: personID,
            recordedAt: Date()
        )
    }

    private func handleSnapshotData(_ data: Data?) {
        guard let data, let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        onSnapshotReceived?(snapshot)
    }
}
#endif
