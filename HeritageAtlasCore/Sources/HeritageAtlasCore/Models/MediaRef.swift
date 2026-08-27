import Foundation
import SwiftData

@Model
public final class MediaRef {
    public var id: UUID = UUID()
    public var kind: MediaKind = MediaKind.photo
    /// Path relative to `Application Support/Media/`, typically `{uuid}` or `{uuid}.jpg`.
    public var relativePath: String = ""
    public var cloudAssetRecordID: String?
    public var byteSize: Int = 0
    public var checksum: String = ""
    public var thumbnailRelativePath: String?
    public var durationSeconds: Double?

    public init(
        id: UUID = UUID(),
        kind: MediaKind,
        relativePath: String,
        cloudAssetRecordID: String? = nil,
        byteSize: Int = 0,
        checksum: String = "",
        thumbnailRelativePath: String? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.cloudAssetRecordID = cloudAssetRecordID
        self.byteSize = byteSize
        self.checksum = checksum
        self.thumbnailRelativePath = thumbnailRelativePath
        self.durationSeconds = durationSeconds
    }

    public func asDescriptor() -> MediaAssetDescriptor {
        MediaAssetDescriptor(
            id: id,
            kind: kind,
            relativePath: relativePath,
            cloudAssetRecordID: cloudAssetRecordID,
            checksum: checksum
        )
    }
}

public struct MediaAssetDescriptor: Sendable, Equatable, Codable {
    public var id: UUID
    public var kind: MediaKind
    public var relativePath: String
    public var cloudAssetRecordID: String?
    public var checksum: String

    public init(
        id: UUID,
        kind: MediaKind,
        relativePath: String,
        cloudAssetRecordID: String? = nil,
        checksum: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.cloudAssetRecordID = cloudAssetRecordID
        self.checksum = checksum
    }
}
