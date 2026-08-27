import HeritageAtlasCore
import MapKit
import SwiftData
import SwiftUI

struct MapHubView: View {
    @Environment(FamilySession.self) private var session
    @Environment(DeviceLocationSession.self) private var location
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query(sort: \Person.fullName) private var people: [Person]

    @State private var path = NavigationPath()
    @State private var cameraPosition: MapCameraPosition = .region(PlaceMapRegion.region(fitting: []))
    @State private var latitudeSpan = 8.0
    @State private var selection: String?
    @State private var selectedPin: PlacePin?
    @State private var editorItem: PlaceEditorItem?
    @State private var didFitCamera = false

    private var pins: [PlacePin] {
        PlacePin.build(
            places: places,
            links: personPlaces,
            memories: memories,
            burialOnly: session.mapMode == .cemetery
        )
    }

    var body: some View {
        @Bindable var session = session
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Map", selection: $session.mapMode) {
                    ForEach(FamilyMapMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                FamilyMapCanvas(
                    pins: pins,
                    cameraPosition: $cameraPosition,
                    latitudeSpan: $latitudeSpan,
                    selection: $selection,
                    selectedPin: $selectedPin,
                    showsUserLocation: location.isAuthorized
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(session.mapMode == .cemetery ? "Cemetery" : "Family Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PlacesListView(burialsOnly: session.mapMode == .cemetery)
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel(session.mapMode == .cemetery ? "Burial locations" : "Places")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorItem = PlaceEditorItem(placeID: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add place")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if places.contains(where: { $0.id == id }) {
                    PlaceDetailView(placeID: id)
                } else {
                    PersonProfileView(personID: id)
                }
            }
            .sheet(item: $selectedPin) { pin in
                NavigationStack {
                    PlaceCalloutView(pin: pin, people: people, memories: memories)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editorItem) { item in
                PlaceEditorView(placeID: item.placeID)
            }
            .onAppear {
                if location.isAuthorized {
                    location.start(heading: false)
                }
                fitIfNeeded(force: !didFitCamera)
                focusRequestedPlace()
            }
            .onChange(of: session.mapMode) { _, _ in
                selection = nil
                selectedPin = nil
                fitIfNeeded(force: true)
            }
            .onChange(of: pins.map(\.id)) { _, _ in
                if !didFitCamera {
                    fitIfNeeded(force: true)
                }
            }
            .onChange(of: session.mapFocusPlaceID) { _, _ in
                focusRequestedPlace()
            }
        }
    }

    private func fitIfNeeded(force: Bool) {
        guard force || !didFitCamera else { return }
        cameraPosition = .region(PlaceMapRegion.region(fitting: pins.map(\.point)))
        if let span = GeoMath.boundingBox(points: pins.map(\.point))?.latitudeDelta {
            latitudeSpan = span
        }
        didFitCamera = true
    }

    private func focusRequestedPlace() {
        guard let focusID = session.mapFocusPlaceID,
              let pin = pins.first(where: { $0.id == focusID }) ?? PlacePin.build(
                places: places,
                links: personPlaces,
                memories: memories,
                burialOnly: false
              ).first(where: { $0.id == focusID })
        else { return }
        cameraPosition = .region(PlaceMapRegion.region(around: pin.point))
        selectedPin = pin
        session.mapFocusPlaceID = nil
    }
}

private struct PlaceEditorItem: Identifiable {
    var placeID: UUID?
    var id: String { placeID?.uuidString ?? "new" }
}

struct FamilyMapCanvas: View {
    let pins: [PlacePin]
    @Binding var cameraPosition: MapCameraPosition
    @Binding var latitudeSpan: Double
    @Binding var selection: String?
    @Binding var selectedPin: PlacePin?
    var showsUserLocation: Bool

    private var glyphs: [MapGlyph] {
        let items = pins.map { (id: $0.id, point: $0.point) }
        let clusters = MapClusterer.cluster(
            idsAndCoordinates: items,
            cellDegrees: MapClusterer.cellDegrees(forLatitudeSpan: latitudeSpan)
        )
        let pinsByID = Dictionary(uniqueKeysWithValues: pins.map { ($0.id, $0) })
        return clusters.map { cluster in
            if cluster.isCluster {
                return MapGlyph(
                    id: cluster.id,
                    title: "\(cluster.count) places",
                    coordinate: CLLocationCoordinate2D(
                        latitude: cluster.coordinate.latitude,
                        longitude: cluster.coordinate.longitude
                    ),
                    isCluster: true,
                    count: cluster.count,
                    pinID: nil,
                    memberIDs: cluster.memberIDs,
                    role: .home
                )
            }
            let pin = cluster.memberIDs.first.flatMap { pinsByID[$0] }
            let title: String
            if let pin {
                title = pin.memoryCount == 0 ? pin.name : "\(pin.name) · \(pin.memoryCount)"
            } else {
                title = "Place"
            }
            return MapGlyph(
                id: pin?.id.uuidString ?? cluster.id,
                title: title,
                coordinate: pin?.coordinate ?? CLLocationCoordinate2D(
                    latitude: cluster.coordinate.latitude,
                    longitude: cluster.coordinate.longitude
                ),
                isCluster: false,
                count: 1,
                pinID: pin?.id,
                memberIDs: cluster.memberIDs,
                role: pin?.primaryRole ?? .home
            )
        }
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selection) {
            ForEach(glyphs) { glyph in
                if glyph.isCluster {
                    Annotation(glyph.title, coordinate: glyph.coordinate, anchor: .center) {
                        ClusterBadge(count: glyph.count)
                    }
                    .tag(Optional(glyph.id))
                } else {
                    Marker(glyph.title, systemImage: glyph.role.systemImageName, coordinate: glyph.coordinate)
                        .tint(glyph.role.mapTint)
                        .tag(Optional(glyph.id))
                }
            }
            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            latitudeSpan = context.region.span.latitudeDelta
        }
        .onChange(of: selection) { _, newValue in
            handleSelection(newValue)
        }
        .overlay(alignment: .bottom) {
            if pins.isEmpty {
                emptyBanner
                    .padding()
            }
        }
    }

    private var emptyBanner: some View {
        Text(pins.isEmpty
             ? "Add places with coordinates to see pins here."
             : "")
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func handleSelection(_ id: String?) {
        guard let id, let glyph = glyphs.first(where: { $0.id == id }) else { return }
        if glyph.isCluster {
            let points = pins.filter { glyph.memberIDs.contains($0.id) }.map(\.point)
            let focus = points.isEmpty
                ? [GeoPoint(latitude: glyph.coordinate.latitude, longitude: glyph.coordinate.longitude)]
                : points
            cameraPosition = .region(PlaceMapRegion.region(fitting: focus))
            selection = nil
        } else if let pinID = glyph.pinID {
            selectedPin = pins.first { $0.id == pinID }
        }
    }
}

private struct ClusterBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color.accentColor, in: Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 2)
            }
            .shadow(radius: 2, y: 1)
    }
}

private struct PlaceCalloutView: View {
    let pin: PlacePin
    let people: [Person]
    let memories: [Memory]

    private var linkedPeople: [Person] {
        let byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        return pin.personIDs.compactMap { byID[$0] }
    }

    private var linkedMemories: [Memory] {
        MemoryQueries.forPlace(pin.id, in: memories)
    }

    var body: some View {
        List {
            Section {
                Label(pin.name, systemImage: pin.primaryRole.systemImageName)
                Text(pin.roles.map(\.displayName).joined(separator: " · "))
                    .foregroundStyle(.secondary)
                Text("\(pin.personIDs.count) people · \(pin.memoryCount) \(pin.memoryCount == 1 ? "memory" : "memories")")
                    .foregroundStyle(.secondary)
            }
            Section("People") {
                if linkedPeople.isEmpty {
                    Text("No people linked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linkedPeople) { person in
                        NavigationLink {
                            PersonProfileView(personID: person.id)
                        } label: {
                            PersonRowView(person: person)
                        }
                    }
                }
            }
            Section("Memories") {
                if linkedMemories.isEmpty {
                    Text("0 memories")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(linkedMemories.count) \(linkedMemories.count == 1 ? "memory" : "memories")")
                        .foregroundStyle(.secondary)
                    ForEach(linkedMemories) { memory in
                        NavigationLink {
                            MemoryDetailView(memoryID: memory.id)
                        } label: {
                            MemoryRowView(memory: memory)
                        }
                    }
                }
            }
            Section {
                NavigationLink("Open place") {
                    PlaceDetailView(placeID: pin.id)
                }
            }
        }
        .navigationTitle(pin.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryPhoneContainer()
    MapHubView()
        .modelContainer(container)
        .environment(FamilySession())
        .environment(DeviceLocationSession())
}
