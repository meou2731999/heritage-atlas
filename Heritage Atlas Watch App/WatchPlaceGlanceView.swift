import HeritageAtlasCore
import SwiftUI

struct WatchPlaceGlanceView: View {
    let snapshot: WatchSnapshot
    let place: WatchPlace
    var showsNavigate = true

    @State private var location = DeviceLocationSession()

    private var ranked: WatchDistantPlace? {
        WatchSnapshotExplorer.rankedPlaces(
            [place],
            from: location.coordinate,
            headingDegrees: location.headingDegrees
        ).first
    }

    private var people: [WatchPerson] {
        WatchSnapshotExplorer.people(for: place, in: snapshot)
    }

    var body: some View {
        List {
            Section {
                Text(place.name)
                    .font(.headline)
                if let role = place.role {
                    Text(role.localizedName(snapshot.localeKinship))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    HeadingCompass(relativeDegrees: ranked?.relativeBearingDegrees)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ranked?.distanceMeters.map(GeoMath.formatDistanceMeters) ?? HeritageLocale.string("No GPS yet"))
                            .font(.headline)
                        Text("From iPhone snapshot")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !people.isEmpty {
                Section("People") {
                    ForEach(people) { person in
                        NavigationLink {
                            PersonGlanceView(snapshot: snapshot, person: person)
                        } label: {
                            WatchPersonRow(
                                person: person,
                                relationship: WatchSnapshotExplorer.relationship(for: person.id, in: snapshot)
                            )
                        }
                    }
                }
            }

            if showsNavigate, place.hasCoordinates {
                Section {
                    Button {
                        WatchMaps.navigate(to: place)
                    } label: {
                        Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                } footer: {
                    Text("Opens Apple Maps. Place data is already on this watch.")
                }
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            location.start(heading: true)
        }
        .onDisappear {
            location.stop()
        }
    }
}
