import HeritageAtlasCore
import SwiftData
import SwiftUI

struct MemoryDetailView: View {
    let memoryID: UUID

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memories: [Memory]
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var events: [TimelineEvent]
    @Query private var settingsRows: [AppSettings]

    @State private var showEditor = false
    @State private var pickingPerson = false
    @State private var transcribing = false
    @State private var transcriptError: String?
    @State private var audioURL: URL?
    @State private var confirmDelete = false

    private var memory: Memory? { memories.first { $0.id == memoryID } }

    var body: some View {
        Group {
            if let memory {
                content(memory)
            } else {
                ContentUnavailableView("Memory not found", systemImage: "waveform.slash")
            }
        }
        .navigationTitle(memory?.title ?? HeritageLocale.string("Memory"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { showEditor = true }
                    if let memory {
                        Button(memory.isFeatured ? LocalizedStringKey("Remove from Watch glance") : LocalizedStringKey("Feature on Watch"), systemImage: "applewatch") {
                            session.setMemoryFeatured(memory, isFeatured: !memory.isFeatured, context: modelContext)
                        }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            MemoryEditorView(memoryID: memoryID)
        }
        .sheet(isPresented: $pickingPerson) {
            PersonPickerSheet(title: "Who is this about?") { person in
                if let memory, let person {
                    session.assignMemory(memory, personIDs: [person.id], context: modelContext)
                }
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
        .alert("Delete this memory?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    guard let memory else { return }
                    await session.deleteMemory(memory, context: modelContext)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task(id: memory?.mediaIDs.first) {
            await loadAudioURL()
        }
    }

    @ViewBuilder
    private func content(_ memory: Memory) -> some View {
        List {
            Section {
                Label(memory.kind.displayName, systemImage: memory.kind.systemImageName)
                if let date = MemoryDateText.short(memory.occurredOn) {
                    LabeledContent("Date", value: date)
                }
                if memory.isFromWatch {
                    Text("Recorded on Apple Watch")
                        .foregroundStyle(.secondary)
                }
                if memory.isFeatured {
                    Label("Shown as a Watch glance", systemImage: "star.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if memory.kind == .photo, let mediaID = memory.mediaIDs.first {
                Section {
                    MediaImageView(mediaID: mediaID, cornerRadius: 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                }
            }

            if memory.kind.isHearable || memory.kind == .audio {
                Section("Audio") {
                    if let audioURL {
                        MemoryAudioPlayer(url: audioURL)
                    } else if memory.mediaIDs.isEmpty == false {
                        Text("Audio file is on this iPhone but hasn’t loaded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No recording attached.")
                            .foregroundStyle(.secondary)
                    }
                    if memory.body.isEmpty == false {
                        Text(memory.body)
                    }
                    if audioURL != nil {
                        Button {
                            Task { await transcribe(memory) }
                        } label: {
                            if transcribing {
                                Label("Transcribing on device…", systemImage: "waveform")
                            } else {
                                Label(memory.body.isEmpty
                                      ? LocalizedStringKey("Transcribe on this iPhone")
                                      : LocalizedStringKey("Re-transcribe on this iPhone"),
                                      systemImage: "text.badge.waveform")
                            }
                        }
                        .disabled(transcribing)
                    }
                }
            } else if memory.body.isEmpty == false {
                Section("Transcript") {
                    Text(memory.body)
                }
            }

            if memory.kind == .document, let mediaID = memory.mediaIDs.first {
                Section("Document") {
                    Text(mediaFileName(mediaID))
                        .foregroundStyle(.secondary)
                }
            }

            Section("People") {
                let linked = people.filter { memory.personIDs.contains($0.id) }
                if linked.isEmpty {
                    Text(memory.isFromWatch
                         ? LocalizedStringKey("Assign someone from this Watch recording.")
                         : LocalizedStringKey("No people linked yet."))
                        .foregroundStyle(.secondary)
                    if memory.isFromWatch {
                        Button("Assign a person") { pickingPerson = true }
                    }
                } else {
                    ForEach(linked) { person in
                        NavigationLink {
                            PersonProfileView(personID: person.id)
                        } label: {
                            PersonRowView(person: person)
                        }
                    }
                    if memory.isFromWatch {
                        Button("Change person") { pickingPerson = true }
                    }
                }
            }

            Section("Places") {
                let linked = places.filter { memory.placeIDs.contains($0.id) }
                if linked.isEmpty {
                    Text("No places linked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linked) { place in
                        NavigationLink {
                            PlaceDetailView(placeID: place.id)
                        } label: {
                            PlaceRowView(place: place)
                        }
                    }
                }
            }

            if let eventID = memory.timelineEventID,
               let event = events.first(where: { $0.id == eventID }) {
                Section("Timeline") {
                    NavigationLink {
                        if let personID = event.person?.id {
                            LifeTimelineView(personID: personID)
                        }
                    } label: {
                        Label(event.title, systemImage: event.kind.systemImageName)
                    }
                }
            }
        }
    }

    private func transcribe(_ memory: Memory) async {
        guard let audioURL else { return }
        transcribing = true
        defer { transcribing = false }
        let locale = settingsRows.first?.localeKinship == .en ? "en-US" : "vi-VN"
        do {
            let text = try await SpeechTranscriptService.transcribe(url: audioURL, localeIdentifier: locale)
            session.updateMemoryTranscript(memory, body: text, context: modelContext)
        } catch {
            transcriptError = error.localizedDescription
        }
    }

    private func loadAudioURL() async {
        guard let memory, let mediaID = memory.mediaIDs.first else {
            audioURL = nil
            return
        }
        audioURL = await session.mediaFileURL(for: mediaID)
    }

    private func mediaFileName(_ mediaID: UUID) -> String {
        HeritageLocale.string("Document \(String(mediaID.uuidString.prefix(8)))")
    }
}
