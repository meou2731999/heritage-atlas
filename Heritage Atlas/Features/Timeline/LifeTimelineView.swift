import HeritageAtlasCore
import SwiftData
import SwiftUI

struct LifeTimelineView: View {
    let personID: UUID

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [TimelineEvent]
    @Query private var memories: [Memory]

    @State private var showEditor = false
    @State private var editingEvent: TimelineEvent?

    private var timeline: [TimelineEvent] {
        events
            .filter { $0.person?.id == personID }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if timeline.isEmpty {
                ContentUnavailableView(
                    "No timeline yet",
                    systemImage: "calendar",
                    description: Text("Add born, moved, married, child, died, or a custom moment. Birth and death dates also create events when you save the person.")
                )
            } else {
                ForEach(timeline) { event in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            editingEvent = event
                        } label: {
                            timelineRow(event)
                        }
                        .buttonStyle(.plain)

                        let linked = memories.filter { event.memoryIDs.contains($0.id) }
                        ForEach(linked) { memory in
                            NavigationLink {
                                MemoryDetailView(memoryID: memory.id)
                            } label: {
                                Label(memory.title, systemImage: memory.kind.systemImageName)
                                    .font(.caption)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            session.deleteTimelineEvent(event, context: modelContext)
                        }
                    }
                }
            }
        }
        .navigationTitle("Life Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add timeline event")
            }
        }
        .sheet(isPresented: $showEditor) {
            TimelineEventEditorView(personID: personID, eventID: nil)
        }
        .sheet(item: $editingEvent) { event in
            TimelineEventEditorView(personID: personID, eventID: event.id)
        }
    }

    private func timelineRow(_ event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.systemImageName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func subtitle(_ event: TimelineEvent) -> String {
        var parts = [event.kind.displayName]
        if let date = MemoryDateText.short(event.date) { parts.append(date) }
        if let place = event.place?.name { parts.append(place) }
        return parts.joined(separator: " · ")
    }
}
