import HeritageAtlasCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MemoryEditorView: View {
    var memoryID: UUID?
    var presetPersonID: UUID?
    var presetPlaceID: UUID?
    var presetKind: MemoryKind?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memories: [Memory]
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var events: [TimelineEvent]
    @Query private var settingsRows: [AppSettings]

    @State private var draft = MemoryDraft()
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var recorder = VoiceRecorder()
    @State private var pickingPerson = false
    @State private var pickingPlace = false
    @State private var importingDocument = false
    @State private var isSaving = false
    @State private var didLoad = false
    @State private var transcribing = false
    @State private var transcriptError: String?
    @State private var existingAudioURL: URL?

    private var existing: Memory? {
        guard let memoryID else { return nil }
        return memories.first { $0.id == memoryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Memory") {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(MemoryKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.systemImageName).tag(kind)
                        }
                    }
                    TextField("Title", text: $draft.title)
                    Toggle("Date", isOn: $draft.hasDate)
                    if draft.hasDate {
                        DatePicker("Occurred", selection: $draft.occurredOn, displayedComponents: .date)
                    }
                    Toggle("Feature on Watch", isOn: $draft.isFeatured)
                }

                mediaSection

                Section("Transcript / notes") {
                    TextField("Write or paste a transcript", text: $draft.body, axis: .vertical)
                        .lineLimit(4...12)
                    Text("Optional. Audio can also be transcribed on this iPhone — never in the cloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if transcribeURL != nil {
                        Button {
                            Task { await transcribeDraft() }
                        } label: {
                            if transcribing {
                                Label("Transcribing on device…", systemImage: "waveform")
                            } else {
                                Label(draft.body.isEmpty
                                      ? LocalizedStringKey("Transcribe on this iPhone")
                                      : LocalizedStringKey("Re-transcribe on this iPhone"),
                                      systemImage: "text.badge.waveform")
                            }
                        }
                        .disabled(transcribing)
                    }
                }

                Section("People") {
                    if selectedPeople.isEmpty {
                        Text("No one linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedPeople) { person in
                            HStack {
                                PersonRowView(person: person)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    draft.personIDs.removeAll { $0 == person.id }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    Button("Add person") { pickingPerson = true }
                }

                Section("Places") {
                    if selectedPlaces.isEmpty {
                        Text("No places linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedPlaces) { place in
                            HStack {
                                PlaceRowView(place: place)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    draft.placeIDs.removeAll { $0 == place.id }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    Button("Add place") { pickingPlace = true }
                }

                Section("Timeline event") {
                    Picker("Event", selection: $draft.timelineEventID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(relevantEvents, id: \.id) { event in
                            Text(eventLabel(event)).tag(Optional(event.id))
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? LocalizedStringKey("New memory") : LocalizedStringKey("Edit memory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!draft.isValid || isSaving)
                }
            }
            .onAppear(perform: populateIfNeeded)
            .onChange(of: pickerItem) { _, item in
                Task { await loadPickerItem(item) }
            }
            .sheet(isPresented: $pickingPerson) {
                PersonPickerSheet(title: "Link a person", excludedIDs: Set(draft.personIDs)) { person in
                    if let person {
                        draft.personIDs.append(person.id)
                    }
                }
            }
            .sheet(isPresented: $pickingPlace) {
                PlacePickerSheet(excludedIDs: Set(draft.placeIDs)) { place in
                    draft.placeIDs.append(place.id)
                }
            }
            .fileImporter(isPresented: $importingDocument, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    draft.documentURL = url
                    draft.removeMedia = false
                }
            }
            .alert("Couldn’t transcribe", isPresented: Binding(
                get: { transcriptError != nil },
                set: { if !$0 { transcriptError = nil } }
            )) {
                Button("OK", role: .cancel) { transcriptError = nil }
            } message: {
                Text(transcriptError ?? "")
            }
            .task(id: existing?.mediaIDs.first) {
                await loadExistingAudio()
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        switch draft.kind {
        case .photo:
            Section("Photo") {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let mediaID = existing?.mediaIDs.first {
                    MediaImageView(mediaID: mediaID)
                        .frame(height: 180)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(previewImage == nil && existing?.mediaIDs.isEmpty != false
                         ? LocalizedStringKey("Add photo")
                         : LocalizedStringKey("Change photo"))
                }
            }
        case .audio, .story:
            Section(draft.kind == .story ? LocalizedStringKey("Recording") : LocalizedStringKey("Audio")) {
                if recorder.isRecording {
                    Button("Stop") { recorder.stop() }
                    Text(Self.formatElapsed(recorder.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Button("Record") {
                        Task { _ = await recorder.start() }
                    }
                }
                if let url = recorder.recordedURL, recorder.isRecording == false {
                    MemoryAudioPlayer(url: url)
                    Button("Discard recording", role: .destructive) {
                        recorder.discard()
                        draft.audioURL = nil
                    }
                } else if existing?.mediaIDs.isEmpty == false {
                    Text("A recording is already attached. Record again to replace it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = recorder.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .onChange(of: recorder.recordedURL) { _, url in
                if recorder.isRecording == false {
                    draft.audioURL = url
                    draft.removeMedia = false
                }
            }
        case .document:
            Section("Document") {
                if let url = draft.documentURL {
                    Text(url.lastPathComponent)
                        .foregroundStyle(.secondary)
                } else if existing?.mediaIDs.isEmpty == false {
                    Text("A document is already attached.")
                        .foregroundStyle(.secondary)
                }
                Button("Choose file") { importingDocument = true }
            }
        case .text, .event:
            EmptyView()
        }
    }

    private var selectedPeople: [Person] {
        people.filter { draft.personIDs.contains($0.id) }
    }

    private var selectedPlaces: [Place] {
        places.filter { draft.placeIDs.contains($0.id) }
    }

    private var relevantEvents: [TimelineEvent] {
        let ids = Set(draft.personIDs)
        return events
            .filter { event in
                guard let personID = event.person?.id else { return false }
                return ids.isEmpty || ids.contains(personID)
            }
            .sorted { $0.date > $1.date }
    }

    private func eventLabel(_ event: TimelineEvent) -> String {
        let name = event.person?.fullName ?? HeritageLocale.string("Person")
        return "\(event.kind.displayName) · \(name)"
    }

    private func populateIfNeeded() {
        guard didLoad == false else { return }
        didLoad = true
        if let existing {
            draft = MemoryDraft(memory: existing)
            if let mediaID = existing.mediaIDs.first {
                Task {
                    if let data = await session.mediaData(for: mediaID) {
                        previewImage = UIImage(data: data)
                    }
                }
            }
        } else {
            if let presetKind { draft.kind = presetKind }
            if let presetPersonID { draft.personIDs = [presetPersonID] }
            if let presetPlaceID { draft.placeIDs = [presetPlaceID] }
            if presetKind == .story {
                draft.title = HeritageLocale.string("Family story")
            }
        }
    }

    private func loadPickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let compressed = compressPhoto(data)
        draft.photoData = compressed
        draft.removeMedia = false
        if let compressed {
            previewImage = UIImage(data: compressed)
        }
    }

    private func compressPhoto(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 1400, height: 1400)) ?? image
        return thumbnail.jpegData(compressionQuality: 0.82) ?? data
    }

    private func save() async {
        isSaving = true
        if recorder.isRecording { recorder.stop() }
        if recorder.recordedURL != nil {
            draft.audioURL = recorder.recordedURL
        }
        let id = await session.saveMemory(existing: existing, draft: draft, context: modelContext)
        isSaving = false
        if id != nil {
            dismiss()
        }
    }

    private var transcribeURL: URL? {
        if recorder.isRecording == false, let url = recorder.recordedURL { return url }
        if let url = draft.audioURL { return url }
        return existingAudioURL
    }

    private func loadExistingAudio() async {
        guard let existing, existing.kind.isHearable || existing.kind == .audio,
              let mediaID = existing.mediaIDs.first else {
            existingAudioURL = nil
            return
        }
        existingAudioURL = await session.mediaFileURL(for: mediaID)
    }

    private func transcribeDraft() async {
        guard let transcribeURL else { return }
        transcribing = true
        defer { transcribing = false }
        let locale = settingsRows.first?.localeKinship == .en ? "en-US" : "vi-VN"
        do {
            draft.body = try await SpeechTranscriptService.transcribe(url: transcribeURL, localeIdentifier: locale)
        } catch {
            transcriptError = error.localizedDescription
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
