import HeritageAtlasCore
import SwiftUI

struct FamilyWalkView: View {
    let snapshot: WatchSnapshot

    @State private var location: DeviceLocationSession = DeviceLocationSession()
    @State private var hapticTracker: ApproachHapticTracker = ApproachHapticTracker()

    private var walk: WatchFamilyWalk? { snapshot.currentWalk }

    private var stops: [WatchPlace] {
        WatchSnapshotExplorer.walkStops(in: snapshot)
    }

    private var distances: [UUID: Double] {
        guard let here: GeoPoint = location.coordinate else { return [:] }
        var result: [UUID: Double] = [:]
        for place: WatchPlace in stops {
            if let point: GeoPoint = place.geoPoint {
                result[place.id] = GeoMath.distanceMeters(from: here, to: point)
            }
        }
        return result
    }

    private var progress: FamilyWalkProgress {
        FamilyWalkNavigator.progress(stopIDs: walk?.stopIDs ?? stops.map(\.id), distances: distances)
    }

    private var herePlace: WatchPlace? {
        guard let id: UUID = progress.hereStopID else { return nil }
        return stops.first { $0.id == id }
    }

    private var currentPlace: WatchPlace? {
        guard let id: UUID = progress.currentStopID else { return nil }
        return stops.first { $0.id == id }
    }

    private var nextPlace: WatchPlace? {
        guard let id: UUID = progress.upcomingStopID else { return nil }
        return stops.first { $0.id == id }
    }

    private var currentStory: WatchMemory? {
        WatchSnapshotExplorer.walkMemory(
            for: progress.hereStopID ?? progress.currentStopID,
            in: snapshot
        )
    }

    var body: some View {
        List {
            if walk == nil || stops.isEmpty {
                ContentUnavailableView(
                    "No Family Walk",
                    systemImage: "figure.walk",
                    description: Text("Create a tour on iPhone and choose Use on Apple Watch.")
                )
            } else {
                Section {
                    Text(walk?.title ?? "")
                        .font(.headline)
                    if progress.isComplete {
                        Text("You reached every stop")
                            .foregroundStyle(.secondary)
                    } else if let herePlace {
                        Text("You’re here")
                            .font(.headline)
                        currentStopCard(herePlace)
                    } else if let currentPlace {
                        currentStopCard(currentPlace)
                    }
                }

                if let story: WatchMemory = currentStory {
                    Section("Story") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.title)
                            if let preview = story.bodyPreview {
                                Text(preview)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let audio = story.audioPreview, audio.isEmpty == false {
                                WatchClipPlayer(data: audio)
                            }
                        }
                    }
                }

                if let nextPlace: WatchPlace, progress.isComplete == false {
                    Section("Next") {
                        NavigationLink {
                            WatchPlaceGlanceView(snapshot: snapshot, place: nextPlace, showsNavigate: true)
                        } label: {
                            Text(nextPlace.name)
                        }
                    }
                }

                Section("Stops") {
                    ForEach(Array(progress.stops.enumerated()), id: \.element.id) { _, state in
                        if let place: WatchPlace = stops.first(where: { $0.id == state.placeID }) {
                            NavigationLink {
                                WatchPlaceGlanceView(snapshot: snapshot, place: place, showsNavigate: true)
                            } label: {
                                HStack {
                                    Text("\(state.index + 1)")
                                        .font(.caption.weight(.bold))
                                    Text(place.name)
                                    Spacer()
                                    if progress.hereStopID == state.placeID {
                                        Text("Here")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    } else if state.placeID == progress.upcomingStopID {
                                        Text("Next")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else if state.isCurrent, progress.youAreHere == false {
                                        Text("Now")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else if state.isArrived {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Walk")
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

    private func currentStopCard(_ place: WatchPlace) -> some View {
        let ranked: WatchDistantPlace? = WatchSnapshotExplorer.rankedPlaces(
            [place],
            from: location.coordinate,
            headingDegrees: location.headingDegrees
        ).first
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HeadingCompass(relativeDegrees: ranked?.relativeBearingDegrees)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.headline)
                    Text(ranked?.distanceMeters.map(GeoMath.formatDistanceMeters) ?? HeritageLocale.string("No GPS yet"))
                        .font(.caption.weight(.semibold))
                    Text("Haptic when you arrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func fireHaptics() {
        guard distances.isEmpty == false else { return }
        for event: ApproachEvent in hapticTracker.events(for: distances) {
            WatchApproachHaptics.play(event.band)
        }
    }
}

#Preview {
    NavigationStack {
        FamilyWalkView(snapshot: WatchSnapshotExplorer.sample())
    }
}
