import HeritageAtlasCore
import SwiftUI

struct CemeteryModeView: View {
    let snapshot: WatchSnapshot

    @State private var location = DeviceLocationSession()
    @State private var hapticTracker = ApproachHapticTracker()

    private var isVI: Bool { snapshot.localeKinship == .vi }

    private var pins: [WatchPlace] {
        snapshot.cemeteryPins.isEmpty ? snapshot.burialPlaces : snapshot.cemeteryPins
    }

    private var ranked: [WatchDistantPlace] {
        WatchSnapshotExplorer.rankedPlaces(
            pins,
            from: location.coordinate,
            headingDegrees: location.headingDegrees
        )
    }

    var body: some View {
        List {
            if pins.isEmpty {
                ContentUnavailableView(
                    isVI ? "Chưa có nghĩa trang" : "No cemetery pins",
                    systemImage: "leaf",
                    description: Text(isVI
                        ? "Gắn vai trò an táng trên iPhone. Watch dẫn đường từ snapshot, không cần mạng."
                        : "Link burial places on iPhone. Guidance uses the local snapshot — no network.")
                )
            } else {
                if location.isDenied {
                    Section {
                        Text(isVI
                             ? "Không có GPS. Danh sách tổ tiên vẫn hiện từ snapshot."
                             : "No GPS. Ancestors still list from the snapshot.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if !location.isAuthorized {
                    Section {
                        Button(isVI ? "Bật vị trí" : "Enable location") {
                            location.start(heading: true)
                        }
                    }
                }

                Section(isVI ? "An táng theo khoảng cách" : "Burials by distance") {
                    ForEach(ranked) { row in
                        NavigationLink {
                            WatchPlaceGlanceView(snapshot: snapshot, place: row.place, showsNavigate: true)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    HeadingCompass(relativeDegrees: row.relativeBearingDegrees)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.place.name)
                                        Text(peopleSummary(row.place))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Text(row.distanceMeters.map(GeoMath.formatDistanceMeters) ?? (isVI ? "Chưa có GPS" : "No GPS yet"))
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(isVI ? "Nghĩa trang" : "Cemetery")
        .onAppear {
            location.start(heading: true)
        }
        .onDisappear {
            location.stop()
        }
        .onChange(of: location.currentLocation?.timestamp) { _, _ in
            fireHaptics()
        }
    }

    private func peopleSummary(_ place: WatchPlace) -> String {
        let people = WatchSnapshotExplorer.people(for: place, in: snapshot)
        if people.isEmpty {
            return isVI ? "Chưa gắn người" : "No people linked"
        }
        let labels = people.map { person in
            if let term = WatchSnapshotExplorer.relationship(for: person.id, in: snapshot)?.term {
                return "\(person.displayName) · \(term)"
            }
            return person.displayName
        }
        return labels.joined(separator: ", ")
    }

    private func fireHaptics() {
        guard location.coordinate != nil else { return }
        var distances: [UUID: Double] = [:]
        for row in ranked {
            if let meters = row.distanceMeters {
                distances[row.place.id] = meters
            }
        }
        for event in hapticTracker.events(for: distances) {
            WatchApproachHaptics.play(event.band)
        }
    }
}

#Preview {
    NavigationStack {
        CemeteryModeView(snapshot: WatchSnapshotExplorer.sample())
    }
}
