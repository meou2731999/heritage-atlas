import AVFoundation
import Foundation
import HeritageAtlasCore
import SwiftData

struct MemoryDraft {
    var kind: MemoryKind = .text
    var title: String = ""
    var hasDate = false
    var occurredOn = Date()
    var body: String = ""
    var personIDs: [UUID] = []
    var placeIDs: [UUID] = []
    var timelineEventID: UUID?
    var isFeatured = false
    var photoData: Data?
    var audioURL: URL?
    var documentURL: URL?
    var removeMedia = false

    init() {}

    init(memory: Memory) {
        kind = memory.kind
        title = memory.title
        if let occurredOn = memory.occurredOn {
            hasDate = true
            self.occurredOn = occurredOn
        }
        body = memory.body
        personIDs = memory.personIDs
        placeIDs = memory.placeIDs
        timelineEventID = memory.timelineEventID
        isFeatured = memory.isFeatured
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TimelineEventDraft {
    var kind: TimelineEventKind = .custom
    var title: String = ""
    var date = Date()
    var personID: UUID?
    var placeID: UUID?
    var memoryIDs: [UUID] = []

    init() {}

    init(event: TimelineEvent) {
        kind = event.kind
        title = event.title
        date = event.date
        personID = event.person?.id
        placeID = event.place?.id
        memoryIDs = event.memoryIDs
    }

    var isValid: Bool {
        personID != nil && !resolvedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { return trimmed }
        return kind.localizedName(.en)
    }
}

extension FamilySession {
    func bindWatchConnectivity(container: ModelContainer) {
        WatchConnectivityService.shared.onAudioFileReceived = { [weak self] url, message in
            Task { @MainActor in
                guard let self else { return }
                await self.importWatchRecording(
                    fileURL: url,
                    message: message,
                    context: container.mainContext
                )
            }
        }
    }

    func mediaFileURL(for mediaID: UUID) async -> URL {
        mediaStore.url(for: mediaID, relativePath: mediaPathByID[mediaID])
    }

    func mediaData(for mediaID: UUID) async -> Data? {
        await photoData(for: mediaID)
    }

    @discardableResult
    func saveMemory(existing: Memory?, draft: MemoryDraft, context: ModelContext) async -> UUID? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return nil }

        let memory: Memory
        let previousEventID: UUID?
        if let existing {
            memory = existing
            previousEventID = existing.timelineEventID
            memory.kind = draft.kind
            memory.title = title
            memory.occurredOn = draft.hasDate ? draft.occurredOn : nil
            memory.body = draft.body
            memory.personIDs = uniqued(draft.personIDs)
            memory.placeIDs = uniqued(draft.placeIDs)
            memory.isFeatured = draft.isFeatured
        } else {
            memory = Memory(
                kind: draft.kind,
                title: title,
                occurredOn: draft.hasDate ? draft.occurredOn : nil,
                body: draft.body,
                personIDs: uniqued(draft.personIDs),
                placeIDs: uniqued(draft.placeIDs),
                isFeatured: draft.isFeatured
            )
            previousEventID = nil
            context.insert(memory)
        }

        if draft.removeMedia {
            await replaceMemoryMedia(memory, with: [], context: context)
        } else if let photoData = draft.photoData {
            await attachPhoto(photoData, to: memory, context: context)
        } else if let audioURL = draft.audioURL {
            await attachFile(audioURL, kind: .audio, to: memory, context: context)
        } else if let documentURL = draft.documentURL {
            await attachFile(documentURL, kind: .document, to: memory, context: context)
        }

        relinkTimelineEvent(
            memory: memory,
            previousEventID: previousEventID,
            newEventID: draft.timelineEventID,
            context: context
        )
        persistDataChange(context: context)
        return memory.id
    }

    func deleteMemory(_ memory: Memory, context: ModelContext) async {
        let eventID = memory.timelineEventID
        await replaceMemoryMedia(memory, with: [], context: context)
        if let eventID {
            relinkTimelineEvent(memory: memory, previousEventID: eventID, newEventID: nil, context: context)
        }
        context.delete(memory)
        persistDataChange(context: context)
    }

    func assignMemory(_ memory: Memory, personIDs: [UUID], context: ModelContext) {
        memory.personIDs = uniqued(personIDs)
        persistDataChange(context: context)
    }

    func updateMemoryTranscript(_ memory: Memory, body: String, context: ModelContext) {
        memory.body = body
        persistDataChange(context: context)
    }

    func setMemoryFeatured(_ memory: Memory, isFeatured: Bool, context: ModelContext) {
        memory.isFeatured = isFeatured
        persistDataChange(context: context)
    }

    func importWatchRecording(
        fileURL: URL,
        message: WatchAudioRecordingMessage,
        context: ModelContext
    ) async {
        do {
            let ext = fileURL.pathExtension.isEmpty ? "m4a" : fileURL.pathExtension
            let write = try await mediaStore.importFile(from: fileURL, fileExtension: ext)
            let storedURL = mediaStore.url(for: write.id, relativePath: write.relativePath)
            let ref = MediaRef(
                id: write.id,
                kind: .audio,
                relativePath: write.relativePath,
                byteSize: write.byteSize,
                checksum: write.checksum,
                durationSeconds: audioDuration(url: storedURL)
            )
            context.insert(ref)
            mediaPathByID[write.id] = write.relativePath
            await enqueueMediaUpload(id: write.id)

            let formatter = DateFormatter()
            formatter.locale = HeritageLocale.locale
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let memory = Memory(
                kind: .story,
                title: HeritageLocale.string("Watch story · \(formatter.string(from: message.recordedAt))"),
                occurredOn: message.recordedAt,
                personIDs: message.personID.map { [$0] } ?? [],
                mediaIDs: [write.id],
                isFromWatch: true
            )
            context.insert(memory)
            persistDataChange(context: context)
            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func saveTimelineEvent(
        existing: TimelineEvent?,
        draft: TimelineEventDraft,
        context: ModelContext
    ) -> UUID? {
        guard let personID = draft.personID else { return nil }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        guard let person = people.first(where: { $0.id == personID }) else { return nil }
        let place = draft.placeID.flatMap { id in places.first { $0.id == id } }

        let event: TimelineEvent
        if let existing {
            event = existing
            event.kind = draft.kind
            event.title = draft.resolvedTitle
            event.date = draft.date
            event.person = person
            event.place = place
            event.memoryIDs = uniqued(draft.memoryIDs)
        } else {
            event = TimelineEvent(
                person: person,
                date: draft.date,
                title: draft.resolvedTitle,
                kind: draft.kind,
                place: place,
                memoryIDs: uniqued(draft.memoryIDs)
            )
            context.insert(event)
        }

        syncMemories(for: event, context: context)
        persistDataChange(context: context)
        return event.id
    }

    func deleteTimelineEvent(_ event: TimelineEvent, context: ModelContext) {
        let eventID = event.id
        if let memories = try? context.fetch(FetchDescriptor<Memory>()) {
            for memory in memories where memory.timelineEventID == eventID {
                memory.timelineEventID = nil
            }
        }
        context.delete(event)
        persistDataChange(context: context)
    }

    func upsertLifeEvents(for person: Person, context: ModelContext) {
        let events = person.timelineEvents ?? []
        if let birth = person.birthDate {
            if let existing = events.first(where: { $0.kind == .born }) {
                existing.date = birth
                if existing.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.title = TimelineEventKind.born.localizedName(.en)
                }
            } else {
                context.insert(
                    TimelineEvent(
                        person: person,
                        date: birth,
                        title: TimelineEventKind.born.localizedName(.en),
                        kind: .born
                    )
                )
            }
        }
        if let death = person.deathDate {
            if let existing = events.first(where: { $0.kind == .died }) {
                existing.date = death
                if existing.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.title = TimelineEventKind.died.localizedName(.en)
                }
            } else {
                context.insert(
                    TimelineEvent(
                        person: person,
                        date: death,
                        title: TimelineEventKind.died.localizedName(.en),
                        kind: .died
                    )
                )
            }
        }
    }

    private func attachPhoto(_ data: Data, to memory: Memory, context: ModelContext) async {
        do {
            let write = try await mediaStore.save(data, fileExtension: "jpg")
            let ref = MediaRef(
                id: write.id,
                kind: .photo,
                relativePath: write.relativePath,
                byteSize: write.byteSize,
                checksum: write.checksum
            )
            context.insert(ref)
            photoDataByID[write.id] = data
            mediaPathByID[write.id] = write.relativePath
            await enqueueMediaUpload(id: write.id)
            await replaceMemoryMedia(memory, with: [write.id], context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func attachFile(_ url: URL, kind: MediaKind, to memory: Memory, context: ModelContext) async {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            let ext = url.pathExtension.isEmpty ? (kind == .audio ? "m4a" : "bin") : url.pathExtension
            let write = try await mediaStore.importFile(from: url, fileExtension: ext)
            let storedURL = mediaStore.url(for: write.id, relativePath: write.relativePath)
            let ref = MediaRef(
                id: write.id,
                kind: kind,
                relativePath: write.relativePath,
                byteSize: write.byteSize,
                checksum: write.checksum,
                durationSeconds: kind == .audio ? audioDuration(url: storedURL) : nil
            )
            context.insert(ref)
            mediaPathByID[write.id] = write.relativePath
            await enqueueMediaUpload(id: write.id)
            await replaceMemoryMedia(memory, with: [write.id], context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func replaceMemoryMedia(_ memory: Memory, with mediaIDs: [UUID], context: ModelContext) async {
        let removed = memory.mediaIDs.filter { mediaIDs.contains($0) == false }
        for id in removed {
            await deleteMedia(id: id, context: context)
        }
        memory.mediaIDs = mediaIDs
    }

    private func relinkTimelineEvent(
        memory: Memory,
        previousEventID: UUID?,
        newEventID: UUID?,
        context: ModelContext
    ) {
        let events = (try? context.fetch(FetchDescriptor<TimelineEvent>())) ?? []
        if let previousEventID, previousEventID != newEventID,
           let previous = events.first(where: { $0.id == previousEventID }) {
            previous.memoryIDs.removeAll { $0 == memory.id }
        }
        memory.timelineEventID = newEventID
        if let newEventID, let event = events.first(where: { $0.id == newEventID }) {
            if event.memoryIDs.contains(memory.id) == false {
                event.memoryIDs.append(memory.id)
            }
        }
    }

    private func syncMemories(for event: TimelineEvent, context: ModelContext) {
        let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
        for memory in memories {
            if event.memoryIDs.contains(memory.id) {
                memory.timelineEventID = event.id
            } else if memory.timelineEventID == event.id {
                memory.timelineEventID = nil
            }
        }
    }

    private func audioDuration(url: URL) -> Double? {
        let duration = (try? AVAudioPlayer(contentsOf: url))?.duration
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    private func uniqued(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
