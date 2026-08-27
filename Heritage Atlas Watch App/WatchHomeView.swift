import HeritageAtlasCore
import SwiftUI

struct WatchHomeView: View {
    let snapshot: WatchSnapshot

    private var familyCount: Int {
        WatchSnapshotExplorer.indexedPeople(in: snapshot).count
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SearchPersonView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Tìm người" : "Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    FavoritesView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Yêu thích" : "Favorites", systemImage: "heart.fill")
                }
            } header: {
                Text(snapshot.localeKinship == .vi ? "Gia đình" : "Family")
            } footer: {
                Text(familyFooter)
            }

            if !snapshot.favorites.isEmpty {
                Section(snapshot.localeKinship == .vi ? "Yêu thích" : "Favorites") {
                    ForEach(snapshot.favorites) { person in
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

            Section {
                NavigationLink {
                    NearbyPlacesView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Gần đây" : "Nearby", systemImage: "location.fill")
                }
                NavigationLink {
                    CemeteryModeView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Nghĩa trang" : "Cemetery", systemImage: "leaf.fill")
                }
            } footer: {
                Text(placesFooter)
            }

            Section {
                NavigationLink {
                    RecordStoryView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Ghi chuyện" : "Record story", systemImage: "mic.fill")
                }
                NavigationLink {
                    FeaturedMomentsView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Kỷ niệm" : "Moments", systemImage: "star.fill")
                }
                laterRow(
                    title: snapshot.localeKinship == .vi ? "Hôm nay" : "Today",
                    systemImage: "calendar"
                )
            } footer: {
                Text(memoriesFooter)
            }
        }
        .navigationTitle("Heritage Atlas")
    }

    private var familyFooter: String {
        if snapshot.localeKinship == .vi {
            return "\(familyCount) người · cache từ iPhone"
        }
        return "\(familyCount) people · from iPhone"
    }

    private var placesFooter: String {
        let nearby = snapshot.nearbyPlaces.count
        let cemetery = snapshot.cemeteryPins.isEmpty ? snapshot.burialPlaces.count : snapshot.cemeteryPins.count
        if snapshot.localeKinship == .vi {
            return "\(nearby) nơi · \(cemetery) nghĩa trang · offline"
        }
        return "\(nearby) places · \(cemetery) cemetery pins · offline"
    }

    private var memoriesFooter: String {
        let featured = snapshot.featuredMemories.count
        let moments = WatchSnapshotExplorer.timelineMoments(in: snapshot).count
        if snapshot.localeKinship == .vi {
            return "\(featured) nổi bật · \(moments) khoảnh khắc · ghi về iPhone. Hôm nay sẽ có ở phase sau."
        }
        return "\(featured) featured · \(moments) moments · recordings go to iPhone. Today comes in a later phase."
    }

    private func laterRow(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(snapshot.localeKinship == .vi ? "Sau" : "Soon")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.tertiary)
        .disabled(true)
    }
}

#Preview {
    NavigationStack {
        WatchHomeView(snapshot: WatchSnapshotExplorer.sample())
    }
}
