import HeritageAtlasCore
import SwiftData
import SwiftUI

struct PlacesListView: View {
    var burialsOnly = false

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]

    @State private var query = ""
    @State private var editorPlaceID: PlaceEditorTarget?
    @State private var confirmDelete: Place?

    private var filtered: [Place] {
        let burialIDs = Set(personPlaces.filter { $0.role == .burial }.compactMap { $0.place?.id })
        return places.filter { place in
            if burialsOnly, !burialIDs.contains(place.id) { return false }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if needle.isEmpty { return true }
            if place.name.localizedCaseInsensitiveContains(needle) { return true }
            if let notes = place.notes, notes.localizedCaseInsensitiveContains(needle) { return true }
            return false
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    burialsOnly ? LocalizedStringKey("No burial locations") : LocalizedStringKey("No places yet"),
                    systemImage: burialsOnly ? "leaf" : "mappin.and.ellipse",
                    description: Text(
                        burialsOnly
                            ? LocalizedStringKey("Link a person to a place with the Burial role.")
                            : LocalizedStringKey("Add a home, school, or cemetery to put this family on the map.")
                    )
                )
            } else {
                ForEach(filtered) { place in
                    NavigationLink {
                        PlaceDetailView(placeID: place.id)
                    } label: {
                        PlaceRowView(
                            place: place,
                            subtitle: subtitle(for: place),
                            role: primaryRole(for: place)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            confirmDelete = place
                        }
                        Button("Edit") {
                            editorPlaceID = PlaceEditorTarget(placeID: place.id)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Place name")
        .navigationTitle(burialsOnly ? LocalizedStringKey("Burials") : LocalizedStringKey("Places"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorPlaceID = PlaceEditorTarget(placeID: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add place")
            }
        }
        .sheet(item: $editorPlaceID) { target in
            PlaceEditorView(placeID: target.placeID)
        }
        .alert("Delete this place?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let confirmDelete {
                    session.deletePlace(confirmDelete, context: modelContext)
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) {
                confirmDelete = nil
            }
        } message: {
            Text("People will be unlinked from this place. This cannot be undone.")
        }
    }

    private func primaryRole(for place: Place) -> PlaceRole? {
        let roles = personPlaces.filter { $0.place?.id == place.id }.map(\.role)
        if burialsOnly, roles.contains(.burial) { return .burial }
        return roles.first
    }

    private func subtitle(for place: Place) -> String {
        let links = personPlaces.filter { $0.place?.id == place.id }
        let peopleCount = Set(links.compactMap { $0.person?.id }).count
        let roleText = links.map { $0.role.displayName }
        let uniqueRoles = NSOrderedSet(array: roleText).compactMap { $0 as? String }
        var parts: [String] = []
        if !uniqueRoles.isEmpty {
            parts.append(uniqueRoles.prefix(3).joined(separator: " · "))
        }
        if peopleCount > 0 {
            parts.append(peopleCount == 1 ? HeritageLocale.string("1 person") : HeritageLocale.string("\(peopleCount) people"))
        }
        if !place.hasCoordinates {
            parts.append(HeritageLocale.string("No coordinates"))
        }
        return parts.joined(separator: " · ")
    }
}

private struct PlaceEditorTarget: Identifiable {
    var placeID: UUID?
    var id: String { placeID?.uuidString ?? "new" }
}
