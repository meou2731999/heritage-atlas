import HeritageAtlasCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Vision

enum ArchiveOCRService {
    static func recognize(in image: UIImage) async -> [String] {
        let cgImage: CGImage?
        if let existing = image.cgImage {
            cgImage = existing
        } else {
            cgImage = image.jpegData(compressionQuality: 0.9).flatMap { UIImage(data: $0)?.cgImage }
        }
        guard let cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["vi-VN", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

struct ArchiveImportView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var ocrLines: [String] = []
    @State private var isRecognizing = false
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var title = ""
    @State private var didSave = false
    @State private var importingDocument = false

    private var suggestions: [ArchiveNameSuggestion] {
        ArchiveNameSuggester.suggest(
            ocrLines: ocrLines,
            people: people.map { ArchivePersonName(id: $0.id, fullName: $0.fullName, nickname: $0.nickname) }
        )
    }

    var body: some View {
        List {
            Section {
                Text("Import a photo or scan. On-device OCR suggests names already in this family. Nothing is linked until you confirm — Heritage Atlas never auto-creates a person.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Scan") {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(image == nil ? "Choose photo" : "Choose another photo", systemImage: "photo")
                }
                Button("Choose file") { importingDocument = true }
                if isRecognizing {
                    ProgressView("Reading text on this iPhone…")
                }
            }

            if ocrLines.isEmpty == false {
                Section("Recognized text") {
                    Text(ocrLines.joined(separator: "\n"))
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }

            if suggestions.isEmpty == false {
                Section("Suggested people") {
                    ForEach(suggestions) { suggestion in
                        Button {
                            toggle(suggestion.personID)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.personName)
                                    Text(suggestion.matchedText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: selectedPersonIDs.contains(suggestion.personID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPersonIDs.contains(suggestion.personID) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if ocrLines.isEmpty == false {
                Section {
                    Text("No names matched people already in this family. Search and link someone yourself, or leave the scan unlinked.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Save as memory") {
                TextField("Title", text: $title)
                if selectedPeople.isEmpty == false {
                    ForEach(selectedPeople) { person in
                        PersonRowView(person: person)
                    }
                }
                Button("Save to archive") {
                    Task { await save() }
                }
                .disabled(image == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if didSave {
                    Text("Saved. Names were only linked because you confirmed them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Family Archive")
        .onChange(of: pickerItem) { _, item in
            Task { await load(item) }
        }
        .fileImporter(isPresented: $importingDocument, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await loadFile(url) }
            }
        }
    }

    private var selectedPeople: [Person] {
        people.filter { selectedPersonIDs.contains($0.id) }
    }

    private func toggle(_ id: UUID) {
        if selectedPersonIDs.contains(id) {
            selectedPersonIDs.remove(id)
        } else {
            selectedPersonIDs.insert(id)
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let loaded = UIImage(data: data) else { return }
        await recognize(loaded)
    }

    private func loadFile(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let loaded = UIImage(data: data) else { return }
        await recognize(loaded)
    }

    @MainActor
    private func recognize(_ loaded: UIImage) async {
        image = loaded
        isRecognizing = true
        didSave = false
        let lines = await ArchiveOCRService.recognize(in: loaded)
        ocrLines = lines
        selectedPersonIDs = []
        if title.isEmpty {
            title = "Archive scan"
        }
        isRecognizing = false
    }

    @MainActor
    private func save() async {
        guard let image, let data = image.jpegData(compressionQuality: 0.82) else { return }
        var draft = MemoryDraft()
        draft.kind = .photo
        draft.title = title
        draft.body = ocrLines.joined(separator: "\n")
        draft.personIDs = Array(selectedPersonIDs)
        draft.photoData = data
        let id = await session.saveMemory(existing: nil, draft: draft, context: modelContext)
        didSave = id != nil
    }
}
