import HeritageAtlasCore
import SwiftData
import SwiftUI

struct FamilyWalkListView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyWalk.title) private var walks: [FamilyWalk]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var settingsRows: [AppSettings]
    @State private var creating = false

    private var currentID: UUID? { settingsRows.first?.currentFamilyWalkID }

    var body: some View {
        List {
            if walks.isEmpty {
                ContentUnavailableView(
                    "No family walks",
                    systemImage: "figure.walk",
                    description: Text("Build an ordered tour of family places. Apple Watch uses the current walk for turn-by-turn glances.")
                )
            } else {
                ForEach(walks) { walk in
                    NavigationLink {
                        FamilyWalkDetailView(walkID: walk.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(walk.title.isEmpty ? "Untitled walk" : walk.title)
                                    .font(.body.weight(.medium))
                                if walk.id == currentID {
                                    Text("Current")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                }
                            }
                            Text(subtitle(for: walk))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            session.deleteWalk(walk, context: modelContext)
                        }
                        Button(walk.id == currentID ? "Clear Watch" : "Use on Watch") {
                            session.setCurrentWalk(walk.id == currentID ? nil : walk.id, context: modelContext)
                        }
                    }
                }
            }
        }
        .navigationTitle("Family Walk")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New walk")
            }
        }
        .sheet(isPresented: $creating) {
            FamilyWalkEditorView(walkID: nil)
        }
    }

    private func subtitle(for walk: FamilyWalk) -> String {
        let names = walk.stopIDs.compactMap { id in places.first { $0.id == id }?.name }
        if names.isEmpty {
            return "No stops yet"
        }
        return names.joined(separator: " → ")
    }
}

struct FamilyWalkDetailView: View {
    let walkID: UUID

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query private var walks: [FamilyWalk]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var memories: [Memory]
    @Query private var settingsRows: [AppSettings]

    @State private var editing = false

    private var walk: FamilyWalk? { walks.first { $0.id == walkID } }
    private var isCurrent: Bool { settingsRows.first?.currentFamilyWalkID == walkID }

    var body: some View {
        Group {
            if let walk {
                List {
                    Section {
                        Text(walk.title.isEmpty ? "Untitled walk" : walk.title)
                            .font(.title3.weight(.semibold))
                        if let notes = walk.notes, notes.isEmpty == false {
                            Text(notes)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Stops") {
                        if walk.stopIDs.isEmpty {
                            Text("Add places to this walk.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(walk.stopIDs.enumerated()), id: \.offset) { index, stopID in
                                if let place = places.first(where: { $0.id == stopID }) {
                                    NavigationLink {
                                        PlaceDetailView(placeID: place.id)
                                    } label: {
                                        HStack {
                                            Text("\(index + 1)")
                                                .font(.caption.weight(.bold))
                                                .frame(width: 24, height: 24)
                                                .background(Color.accentColor.opacity(0.15), in: Circle())
                                            PlaceRowView(place: place, subtitle: stopSubtitle(place))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button(isCurrent ? "This walk is on Apple Watch" : "Use on Apple Watch") {
                            session.setCurrentWalk(isCurrent ? nil : walk.id, context: modelContext)
                        }
                        .disabled(walk.stopIDs.isEmpty)
                        Button("Edit walk") { editing = true }
                    } footer: {
                        Text("Watch shows the next stop, a story at that place, and a haptic when you arrive. Location is never stored.")
                    }
                }
            } else {
                ContentUnavailableView("Walk not found", systemImage: "figure.walk")
            }
        }
        .navigationTitle("Walk")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            FamilyWalkEditorView(walkID: walkID)
        }
    }

    private func stopSubtitle(_ place: Place) -> String {
        let count = MemoryQueries.forPlace(place.id, in: memories).count
        if count == 0 { return place.hasCoordinates ? "On the map" : "Name only" }
        return count == 1 ? "1 memory" : "\(count) memories"
    }
}

struct FamilyWalkEditorView: View {
    var walkID: UUID?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var walks: [FamilyWalk]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var settingsRows: [AppSettings]

    @State private var title = ""
    @State private var notes = ""
    @State private var stopIDs: [UUID] = []
    @State private var makeCurrent = true
    @State private var pickingPlace = false
    @State private var didLoad = false

    private var existing: FamilyWalk? {
        guard let walkID else { return nil }
        return walks.first { $0.id == walkID }
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Walk") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("Use on Apple Watch", isOn: $makeCurrent)
                }

                Section("Stops in order") {
                    if stopIDs.isEmpty {
                        Text("Add homes, cemeteries, or other family places.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(stopIDs.enumerated()), id: \.element) { index, id in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(places.first { $0.id == id }?.name ?? "Missing place")
                                Spacer()
                                if index > 0 {
                                    Button("Up") { move(id, by: -1) }
                                        .font(.caption)
                                }
                                if index < stopIDs.count - 1 {
                                    Button("Down") { move(id, by: 1) }
                                        .font(.caption)
                                }
                                Button("Remove", role: .destructive) {
                                    stopIDs.removeAll { $0 == id }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    Button("Add place") { pickingPlace = true }
                }
            }
            .navigationTitle(existing == nil ? "New walk" : "Edit walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = session.saveWalk(
                            existing: existing,
                            title: title,
                            stopIDs: stopIDs,
                            notes: notes,
                            makeCurrent: makeCurrent,
                            context: modelContext
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: populate)
            .sheet(isPresented: $pickingPlace) {
                PlacePickerSheet(excludedIDs: Set(stopIDs)) { place in
                    stopIDs.append(place.id)
                }
            }
        }
    }

    private func populate() {
        guard didLoad == false else { return }
        didLoad = true
        if let existing {
            title = existing.title
            notes = existing.notes ?? ""
            stopIDs = existing.stopIDs
            makeCurrent = settingsRows.first?.currentFamilyWalkID == existing.id
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = stopIDs.firstIndex(of: id) else { return }
        let next = index + offset
        guard stopIDs.indices.contains(next) else { return }
        stopIDs.swapAt(index, next)
    }
}
