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
                NavigationLink {
                    TodayView(snapshot: snapshot)
                } label: {
                    Label(snapshot.localeKinship == .vi ? "Hôm nay" : "Today", systemImage: "calendar")
                }
                if snapshot.currentWalk != nil {
                    NavigationLink {
                        FamilyWalkView(snapshot: snapshot)
                    } label: {
                        Label(snapshot.localeKinship == .vi ? "Family Walk" : "Family Walk", systemImage: "figure.walk")
                    }
                }
            } footer: {
                Text(memoriesFooter)
            }
        }
        .navigationTitle("Heritage Atlas")
    }

    private var familyFooter: String {
        let living = snapshot.insightsGlance?.livingCount ?? familyCount
        let generations = snapshot.insightsGlance?.generationCount
        if snapshot.localeKinship == .vi {
            if let generations {
                return "\(living) còn sống · \(generations) thế hệ · cache từ iPhone"
            }
            return "\(familyCount) người · cache từ iPhone"
        }
        if let generations {
            return "\(living) living · \(generations) gen · from iPhone"
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
        let today = WatchSnapshotExplorer.todayEvents(in: snapshot).count
        if snapshot.localeKinship == .vi {
            if snapshot.memorialRemindersEnabled == true {
                return "\(featured) nổi bật · \(moments) khoảnh khắc · \(today) hôm nay"
            }
            return "\(featured) nổi bật · \(moments) khoảnh khắc. Bật nhắc giỗ trên iPhone để có Hôm nay."
        }
        if snapshot.memorialRemindersEnabled == true {
            return "\(featured) featured · \(moments) moments · \(today) today"
        }
        return "\(featured) featured · \(moments) moments. Opt in to memorials on iPhone for Today."
    }
}

#Preview {
    NavigationStack {
        WatchHomeView(snapshot: WatchSnapshotExplorer.sample())
    }
}
