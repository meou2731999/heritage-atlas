import HeritageAtlasCore
import SwiftData
import SwiftUI

struct MemoriesListView: View {
    var personID: UUID?
    var placeID: UUID?
    var hearableOnly = false

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query private var memories: [Memory]
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]

    @State private var showEditor = false
    @State private var query = ""

    private var filtered: [Memory] {
        var items = memories
        if let personID {
            items = MemoryQueries.forPerson(personID, in: items)
        }
        if let placeID {
            items = MemoryQueries.forPlace(placeID, in: items)
        }
        if hearableOnly {
            items = MemoryQueries.hearable(in: items)
        }
        items = MemoryQueries.sorted(items)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else { return items }
        return items.filter {
            $0.title.lowercased().contains(needle) || $0.body.lowercased().contains(needle)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "waveform",
                    description: Text(emptyDescription)
                )
            } else {
                ForEach(filtered) { memory in
                    NavigationLink {
                        MemoryDetailView(memoryID: memory.id)
                    } label: {
                        MemoryRowView(memory: memory, subtitle: subtitle(for: memory))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            Task { await session.deleteMemory(memory, context: modelContext) }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Title or transcript")
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add memory")
            }
        }
        .sheet(isPresented: $showEditor) {
            MemoryEditorView(memoryID: nil, presetPersonID: personID, presetPlaceID: placeID)
        }
    }

    private var navigationTitle: String {
        if hearableOnly { return "Memories to hear" }
        if personID != nil { return "Memories" }
        if placeID != nil { return "Memories" }
        return "Memories"
    }

    private var emptyTitle: String {
        hearableOnly ? "Nothing to hear yet" : "No memories yet"
    }

    private var emptyDescription: String {
        hearableOnly
            ? "Record a story on iPhone or Apple Watch, or add an audio memory."
            : "Photos, stories, documents, and events live here — on this iPhone."
    }

    private func subtitle(for memory: Memory) -> String {
        let names = memory.personIDs.compactMap { id in people.first { $0.id == id }?.displayName }
        let placeNames = memory.placeIDs.compactMap { id in places.first { $0.id == id }?.name }
        var parts = [memory.kind.displayName]
        if let date = MemoryDateText.short(memory.occurredOn) { parts.append(date) }
        if names.isEmpty == false { parts.append(names.prefix(2).joined(separator: ", ")) }
        if placeNames.isEmpty == false { parts.append(placeNames.prefix(1).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}
