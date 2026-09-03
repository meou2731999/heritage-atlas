#if os(iOS)
import CloudKit
#endif
import Foundation

/// Syncs media binaries as CloudKit `CKAsset`s when CloudKit is enabled. Watch never runs this path.
public actor MediaSyncService {
    public static let recordType = "MediaAsset"

    private let store: MediaStore
    private var pendingUploadIDs: Set<UUID> = []

    public init(store: MediaStore) {
        self.store = store
    }

    public func enqueueUpload(id: UUID) {
        pendingUploadIDs.insert(id)
    }

    public func pendingIDs() -> Set<UUID> {
        pendingUploadIDs
    }

#if os(iOS)
    public func syncPending(descriptors: [MediaAssetDescriptor]) async {
        guard CloudKitAvailability.isICloudAccountAvailable else { return }
        let pending = descriptors.filter { pendingUploadIDs.contains($0.id) || $0.cloudAssetRecordID == nil }
        for descriptor in pending {
            do {
                try await upload(descriptor)
                pendingUploadIDs.remove(descriptor.id)
            } catch {
                // Stay local; retry when iCloud/network returns. Never fail the app.
            }
        }
    }

    public func downloadIfNeeded(descriptor: MediaAssetDescriptor) async {
        guard CloudKitAvailability.isICloudAccountAvailable else { return }
        if await store.fileExists(id: descriptor.id, relativePath: descriptor.relativePath) {
            return
        }
        guard descriptor.cloudAssetRecordID != nil else { return }
        do {
            try await download(descriptor)
        } catch {
            // File remains missing locally until a later pass.
        }
    }

    private func upload(_ descriptor: MediaAssetDescriptor) async throws {
        let fileURL = await store.url(for: descriptor.id, relativePath: descriptor.relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let container = CKContainer(identifier: HeritageAtlasSchema.cloudKitContainerIdentifier)
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: descriptor.id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["kind"] = descriptor.kind.rawValue as CKRecordValue
        record["checksum"] = descriptor.checksum as CKRecordValue
        record["asset"] = CKAsset(fileURL: fileURL)
        _ = try await database.save(record)
    }

    private func download(_ descriptor: MediaAssetDescriptor) async throws {
        let container = CKContainer(identifier: HeritageAtlasSchema.cloudKitContainerIdentifier)
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: descriptor.cloudAssetRecordID ?? descriptor.id.uuidString)
        let record = try await database.record(for: recordID)
        guard let asset = record["asset"] as? CKAsset, let assetURL = asset.fileURL else { return }
        let data = try Data(contentsOf: assetURL)
        let ext = URL(fileURLWithPath: descriptor.relativePath).pathExtension
        _ = try await store.save(data, id: descriptor.id, fileExtension: ext.isEmpty ? nil : ext)
    }
#else
    public func syncPending(descriptors: [MediaAssetDescriptor]) async {
        _ = descriptors
    }

    public func downloadIfNeeded(descriptor: MediaAssetDescriptor) async {
        _ = descriptor
    }
#endif
}
