import Foundation
import Testing
@testable import HeritageAtlasCore

@Suite("Media store")
struct MediaStoreTests {
    @Test func writesUnderMediaFolderWithChecksum() async throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = MediaStore(baseDirectory: temp)
        let payload = Data("heritage".utf8)
        let write = try await store.save(payload, fileExtension: "txt")
        #expect(write.byteSize == payload.count)
        #expect(!write.checksum.isEmpty)
        let loaded = try await store.load(id: write.id, relativePath: write.relativePath)
        #expect(loaded == payload)
        #expect(write.relativePath.contains(write.id.uuidString))
        try await store.delete(id: write.id, relativePath: write.relativePath)
        #expect(await store.fileExists(id: write.id, relativePath: write.relativePath) == false)
        try? FileManager.default.removeItem(at: temp)
    }

    @Test func importFileCopiesBytesAndKeepsExtension() async throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = MediaStore(baseDirectory: temp)
        let source = temp.appending(path: "source.m4a")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let payload = Data("audio-bytes".utf8)
        try payload.write(to: source)
        let write = try await store.importFile(from: source, fileExtension: "m4a")
        #expect(write.relativePath.hasSuffix(".m4a"))
        #expect(try await store.load(id: write.id, relativePath: write.relativePath) == payload)
        try? FileManager.default.removeItem(at: temp)
    }
}
