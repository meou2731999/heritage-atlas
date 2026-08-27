import HeritageAtlasCore
import SwiftUI

struct NearbyPlacesView: View {
    let snapshot: WatchSnapshot

    @State private var location = DeviceLocationSession()
    @State private var hapticTracker = ApproachHapticTracker()

    private var isVI: Bool { snapshot.localeKinship == .vi }

    private var ranked: [WatchDistantPlace] {
        WatchSnapshotExplorer.rankedPlaces(
            snapshot.nearbyPlaces,
            from: location.coordinate,
            headingDegrees: location.headingDegrees
        )
    }

    var body: some View {
        List {
            if snapshot.nearbyPlaces.isEmpty {
                ContentUnavailableView(
                    isVI ? "Chưa có nơi" : "No places",
                    systemImage: "location.slash",
                    description: Text(isVI
                        ? "Thêm nơi có tọa độ trên iPhone. Watch dùng snapshot offline."
                        : "Add places with coordinates on iPhone. This list is from the offline snapshot.")
                )
            } else {
                statusSection
                if let closest = ranked.first {
                    Section(isVI ? "Gần nhất" : "Closest") {
                        compassRow(closest)
                    }
                }
                Section(isVI ? "Gia đình gần đây" : "Family nearby") {
                    ForEach(ranked) { row in
                        NavigationLink {
                            WatchPlaceGlanceView(snapshot: snapshot, place: row.place, showsNavigate: false)
                        } label: {
                            placeRow(row)
                        }
                    }
                }
            }
        }
        .navigationTitle(isVI ? "Gần đây" : "Nearby")
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

    @ViewBuilder
    private var statusSection: some View {
        if location.isDenied {
            Section {
                Text(isVI
                     ? "Chưa có quyền vị trí. Danh sách vẫn dùng snapshot trên Watch."
                     : "Location is off. The list still uses the snapshot on this watch.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if !location.isAuthorized {
            Section {
                Button(isVI ? "Bật vị trí" : "Enable location") {
                    location.start(heading: true)
                }
                Text(isVI
                     ? "Để hiện khoảng cách và hướng. Vị trí không lưu."
                     : "Used for distance and heading. Location is not stored.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compassRow(_ row: WatchDistantPlace) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HeadingCompass(relativeDegrees: row.relativeBearingDegrees)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.place.name)
                        .font(.headline)
                    if let role = row.place.role {
                        Text(role.localizedName(snapshot.localeKinship))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(row.distanceMeters.map(GeoMath.formatDistanceMeters) ?? (isVI ? "Chưa có GPS" : "No GPS yet"))
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func placeRow(_ row: WatchDistantPlace) -> some View {
        HStack {
            HeadingCompass(relativeDegrees: row.relativeBearingDegrees)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.place.name)
                if let role = row.place.role {
                    Text(role.localizedName(snapshot.localeKinship))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(row.distanceMeters.map(GeoMath.formatDistanceMeters) ?? "—")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
        NearbyPlacesView(snapshot: WatchSnapshotExplorer.sample())
    }
}
