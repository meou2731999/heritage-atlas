import CryptoKit
import Foundation

/// Files live on disk at `Application Support/Media/{uuid}`. SwiftData only stores `MediaRef` metadata.
public actor MediaStore {
    public let directory: URL

    public init(baseDirectory: URL? = nil) {
        let base = baseDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appending(path: "Media", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for id: UUID, relativePath: String? = nil) -> URL {
        if let relativePath, !relativePath.isEmpty {
            return directory.appending(path: relativePath)
        }
        return directory.appending(path: id.uuidString)
    }

    @discardableResult
    public func save(_ data: Data, id: UUID = UUID(), fileExtension: String? = nil) throws -> MediaStoreWrite {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let relativePath: String
        if let fileExtension, !fileExtension.isEmpty {
            relativePath = "\(id.uuidString).\(fileExtension)"
        } else {
            relativePath = id.uuidString
        }
        let fileURL = directory.appending(path: relativePath)
        try data.write(to: fileURL, options: .atomic)
        return MediaStoreWrite(
            id: id,
            relativePath: relativePath,
            byteSize: data.count,
            checksum: Self.checksum(of: data)
        )
    }

    @discardableResult
    public func importFile(from source: URL, id: UUID = UUID(), fileExtension: String? = nil) throws -> MediaStoreWrite {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = fileExtension ?? source.pathExtension
        let relativePath: String
        if ext.isEmpty {
            relativePath = id.uuidString
        } else {
            relativePath = "\(id.uuidString).\(ext)"
        }
        let fileURL = directory.appending(path: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.copyItem(at: source, to: fileURL)
        let data = try Data(contentsOf: fileURL)
        return MediaStoreWrite(
            id: id,
            relativePath: relativePath,
            byteSize: data.count,
            checksum: Self.checksum(of: data)
        )
    }

    public func load(id: UUID, relativePath: String? = nil) throws -> Data {
        try Data(contentsOf: url(for: id, relativePath: relativePath))
    }

    public func fileExists(id: UUID, relativePath: String? = nil) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id, relativePath: relativePath).path)
    }

    public func delete(id: UUID, relativePath: String? = nil) throws {
        let fileURL = url(for: id, relativePath: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public static func checksum(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct MediaStoreWrite: Sendable, Equatable {
    public var id: UUID
    public var relativePath: String
    public var byteSize: Int
    public var checksum: String
}
