import HeritageAtlasCore
import MapKit
import SwiftData
import SwiftUI

struct PlaceDetailView: View {
    let placeID: UUID

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var memories: [Memory]

    @State private var showEditor = false
    @State private var showPersonPlaceEditor = false
    @State private var editingLink: PersonPlace?
    @State private var confirmDelete = false

    private var place: Place? { places.first { $0.id == placeID } }

    private var links: [PersonPlace] {
        personPlaces
            .filter { $0.place?.id == placeID }
            .sorted { lhs, rhs in
                let left = lhs.person?.displayName ?? ""
                let right = rhs.person?.displayName ?? ""
                if left != right { return left.localizedStandardCompare(right) == .orderedAscending }
                return lhs.role.displayName < rhs.role.displayName
            }
            }

    var body: some View {
        Group {
            if let place {
                content(place)
            } else {
                ContentUnavailableView("Place not found", systemImage: "mappin.slash")
            }
        }
        .navigationTitle(place?.name ?? HeritageLocale.string("Place"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { showEditor = true }
                    if place?.hasCoordinates == true {
                        Button("Show on Family Map", systemImage: "map") {
                            session.openFamilyMap(focusPlaceID: placeID)
                        }
                        if links.contains(where: { $0.role == .burial }) {
                            Button("Show on Cemetery Map", systemImage: "leaf") {
                                session.openCemeteryMap(focusPlaceID: placeID)
                            }
                        }
                        Button("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond") {
                            openInMaps()
                        }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            PlaceEditorView(placeID: placeID)
        }
        .sheet(isPresented: $showPersonPlaceEditor) {
            if let place {
                PersonPlaceEditorView(person: nil, place: place, existing: nil)
            }
        }
        .sheet(item: $editingLink) { link in
            PersonPlaceEditorView(person: link.person, place: place, existing: link)
        }
        .alert("Delete this place?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let place {
                    session.deletePlace(place, context: modelContext)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("People will be unlinked from this place. This cannot be undone.")
        }
    }

    @ViewBuilder
    private func content(_ place: Place) -> some View {
        List {
            if place.hasCoordinates, let latitude: Double = place.latitude, let longitude = place.longitude {
                Section {
                    Map(initialPosition: .region(PlaceMapRegion.region(
                        around: GeoPoint(latitude: latitude, longitude: longitude)
                    ))) {
                        Marker(place.name, systemImage: (links.first?.role ?? .home).systemImageName, coordinate: CLLocationCoordinate2D(
                            latitude: latitude,
                            longitude: longitude
                        ))
                        .tint((links.first?.role ?? .home).mapTint)
                    }
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    Button("Open in Maps") { openInMaps() }
                }
            } else {
                Section {
                    Text("No coordinates yet. Add them to drop a pin on Family Map and send this place to Apple Watch.")
                        .foregroundStyle(.secondary)
                    Button("Add coordinates") { showEditor = true }
                }
            }

            if let notes = place.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            Section {
                if links.isEmpty {
                    Text("No people linked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(links) { link in
                        if let person = link.person {
                            NavigationLink {
                                PersonProfileView(personID: person.id)
                            } label: {
                                PersonRowView(
                                    person: person,
                                    subtitle: linkSubtitle(link)
                                )
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Edit") { editingLink = link }
                                Button("Remove", role: .destructive) {
                                    session.deletePersonPlace(link, context: modelContext)
                                }
                            }
                        } else {
                            Text(link.role.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    showPersonPlaceEditor = true
                } label: {
                    Label("Link a person", systemImage: "person.badge.plus")
                }
            } header: {
                Text("People")
            }

            let linkedMemories = MemoryQueries.forPlace(placeID, in: memories)
            Section {
                if linkedMemories.isEmpty {
                    Text("No memories linked to this place yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linkedMemories) { memory in
                        NavigationLink {
                            MemoryDetailView(memoryID: memory.id)
                        } label: {
                            MemoryRowView(memory: memory)
                        }
                    }
                }
                NavigationLink {
                    MemoriesListView(placeID: placeID)
                } label: {
                    Label("All memories", systemImage: "waveform")
                }
            } header: {
                Text("Memories · \(linkedMemories.count)")
            }
        }
    }

    private func linkSubtitle(_ link: PersonPlace) -> String {
        var parts: [String] = [link.role.displayName]
        let years: String = PlaceYears.format(from: link.yearFrom, to: link.yearTo)
        if !years.isEmpty { parts.append(years) }
        return parts.joined(separator: " · ")
    }

    private func openInMaps() {
        guard let place, let latitude: Double = place.latitude, let longitude: Double = place.longitude else { return }
        let item: MKMapItem = MKMapItem(
            location: CLLocation(latitude: latitude, longitude: longitude),
            address: nil
        )
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}
