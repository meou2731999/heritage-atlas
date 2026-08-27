import HeritageAtlasCore
import SwiftData
import SwiftUI

struct TimelineEventEditorView: View {
    var personID: UUID
    var eventID: UUID?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var events: [TimelineEvent]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var memories: [Memory]
    @Query private var people: [Person]

    @State private var draft = TimelineEventDraft()
    @State private var pickingPlace = false
    @State private var didLoad = false

    private var existing: TimelineEvent? {
        guard let eventID else { return nil }
        return events.first { $0.id == eventID }
    }

    private var person: Person? { people.first { $0.id == personID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(TimelineEventKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.systemImageName).tag(kind)
                        }
                    }
                    TextField("Title", text: $draft.title, prompt: Text(draft.kind.displayName))
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                }

                Section("Place") {
                    Button {
                        pickingPlace = true
                    } label: {
                        HStack {
                            Text("Place")
                            Spacer()
                            Text(selectedPlace?.name ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if draft.placeID != nil {
                        Button("Clear place", role: .destructive) {
                            draft.placeID = nil
                        }
                    }
                }

                Section("Memories") {
                    let personMemories = MemoryQueries.forPerson(personID, in: memories)
                    if personMemories.isEmpty {
                        Text("No memories for this person yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(personMemories) { memory in
                            Toggle(isOn: binding(for: memory.id)) {
                                MemoryRowView(memory: memory)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New moment" : "Edit moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .onAppear(perform: populateIfNeeded)
            .sheet(isPresented: $pickingPlace) {
                PlacePickerSheet { place in
                    draft.placeID = place.id
                }
            }
        }
    }

    private var selectedPlace: Place? {
        draft.placeID.flatMap { id in places.first { $0.id == id } }
    }

    private func binding(for memoryID: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.memoryIDs.contains(memoryID) },
            set: { isOn in
                if isOn {
                    if draft.memoryIDs.contains(memoryID) == false {
                        draft.memoryIDs.append(memoryID)
                    }
                } else {
                    draft.memoryIDs.removeAll { $0 == memoryID }
                }
            }
        )
    }

    private func populateIfNeeded() {
        guard didLoad == false else { return }
        didLoad = true
        if let existing {
            draft = TimelineEventDraft(event: existing)
        } else {
            draft.personID = personID
            draft.kind = .custom
            if let person, draft.kind == .born, let birth = person.birthDate {
                draft.date = birth
            }
        }
        draft.personID = personID
    }

    private func save() {
        draft.personID = personID
        if session.saveTimelineEvent(existing: existing, draft: draft, context: modelContext) != nil {
            dismiss()
        }
    }
}
