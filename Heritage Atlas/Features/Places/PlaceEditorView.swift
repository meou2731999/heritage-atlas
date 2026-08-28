import HeritageAtlasCore
import MapKit
import SwiftData
import SwiftUI

struct PlaceEditorView: View {
    var placeID: UUID?

    @Environment(FamilySession.self) private var session
    @Environment(DeviceLocationSession.self) private var location
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var places: [Place]

    @State private var name = ""
    @State private var notes = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var cameraPosition: MapCameraPosition = .region(PlaceMapRegion.region(fitting: []))
    @State private var didLoad = false

    private var existing: Place? {
        guard let placeID else { return nil }
        return places.first { $0.id == placeID }
    }

    private var parsedLatitude: Double? { PlaceCoordinateText.parse(latitudeText) }
    private var parsedLongitude: Double? { PlaceCoordinateText.parse(longitudeText) }

    private var coordinate: GeoPoint? {
        guard let lat = parsedLatitude, let lon = parsedLongitude else { return nil }
        let point = GeoPoint(latitude: lat, longitude: lon)
        return point.isValid ? point : nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ((latitudeText.isEmpty && longitudeText.isEmpty) || coordinate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $name)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            if let coordinate {
                                Marker(name.isEmpty ? HeritageLocale.string("Place") : name, coordinate: CLLocationCoordinate2D(
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude
                                ))
                            }
                            if location.isAuthorized {
                                UserAnnotation()
                            }
                        }
                        .frame(minHeight: 220)
                        .onTapGesture { position in
                            if let coord = proxy.convert(position, from: .local) {
                                latitudeText = PlaceCoordinateText.format(coord.latitude)
                                longitudeText = PlaceCoordinateText.format(coord.longitude)
                                cameraPosition = .region(PlaceMapRegion.region(
                                    around: GeoPoint(latitude: coord.latitude, longitude: coord.longitude)
                                ))
                            }
                        }
                    }
                    Text("Tap the map to set coordinates. Leave them empty for a named place without a pin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Map")
                }

                Section("Coordinates") {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.decimalPad)
                    Button("Use current location") {
                        useCurrentLocation()
                    }
                    .disabled(!location.isAuthorized && location.isDenied)
                    if !latitudeText.isEmpty || !longitudeText.isEmpty {
                        Button("Clear coordinates", role: .destructive) {
                            latitudeText = ""
                            longitudeText = ""
                        }
                    }
                }
            }
            .navigationTitle(placeID == nil ? LocalizedStringKey("New place") : LocalizedStringKey("Edit place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                populateIfNeeded()
                if location.isAuthorized {
                    location.start(heading: false)
                }
            }
        }
    }

    private func populateIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let existing {
            name = existing.name
            notes = existing.notes ?? ""
            latitudeText = PlaceCoordinateText.format(existing.latitude)
            longitudeText = PlaceCoordinateText.format(existing.longitude)
            if let point = existing.geoPoint {
                cameraPosition = .region(PlaceMapRegion.region(around: point))
            }
        } else if let here = location.coordinate {
            cameraPosition = .region(PlaceMapRegion.region(around: here, span: 0.08))
        }
    }

    private func useCurrentLocation() {
        if !location.isAuthorized {
            location.start(heading: false)
        }
        guard let here = location.coordinate else { return }
        latitudeText = PlaceCoordinateText.format(here.latitude)
        longitudeText = PlaceCoordinateText.format(here.longitude)
        cameraPosition = .region(PlaceMapRegion.region(around: here))
    }

    private func save() {
        _ = session.savePlace(
            existing: existing,
            name: name,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            notes: notes,
            context: modelContext
        )
        dismiss()
    }
}
