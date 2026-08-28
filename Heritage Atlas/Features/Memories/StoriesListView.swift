import HeritageAtlasCore
import SwiftData
import SwiftUI

struct StoriesListView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query private var memories: [Memory]
    @Query(sort: \Person.fullName) private var people: [Person]

    @State private var showEditor = false

    private var stories: [Memory] {
        MemoryQueries.stories(in: memories)
    }

    var body: some View {
        List {
            if stories.isEmpty {
                ContentUnavailableView(
                    "No family stories yet",
                    systemImage: "book",
                    description: Text("Write a story, record one here, or record from Apple Watch. Transcripts stay on this iPhone.")
                )
            } else {
                ForEach(stories) { story in
                    NavigationLink {
                        MemoryDetailView(memoryID: story.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            MemoryRowView(memory: story, subtitle: storySubtitle(story))
                            if story.body.isEmpty == false {
                                Text(story.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            Task { await session.deleteMemory(story, context: modelContext) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Family Stories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add story")
            }
        }
        .sheet(isPresented: $showEditor) {
            MemoryEditorView(memoryID: nil, presetKind: .story)
        }
    }

    private func storySubtitle(_ story: Memory) -> String {
        let names = story.personIDs.compactMap { id in people.first { $0.id == id }?.displayName }
        var parts: [String] = []
        if let date = MemoryDateText.short(story.occurredOn) { parts.append(date) }
        if names.isEmpty == false { parts.append(names.prefix(3).joined(separator: ", ")) }
        if story.isFromWatch { parts.append(HeritageLocale.string("From Watch")) }
        if story.body.isEmpty { parts.append(HeritageLocale.string("No transcript yet")) }
        return parts.joined(separator: " · ")
    }
}
