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
                    Label("Search people", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    FavoritesView(snapshot: snapshot)
                } label: {
                    Label("Favorites", systemImage: "heart.fill")
                }
            } header: {
                Text("Family")
            } footer: {
                Text(familyFooter)
            }

            if !snapshot.favorites.isEmpty {
                Section("Favorites") {
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
                    Label("Nearby", systemImage: "location.fill")
                }
                NavigationLink {
                    CemeteryModeView(snapshot: snapshot)
                } label: {
                    Label("Cemetery", systemImage: "leaf.fill")
                }
            } footer: {
                Text(placesFooter)
            }

            Section {
                NavigationLink {
                    RecordStoryView(snapshot: snapshot)
                } label: {
                    Label("Record story", systemImage: "mic.fill")
                }
                NavigationLink {
                    FeaturedMomentsView(snapshot: snapshot)
                } label: {
                    Label("Moments", systemImage: "star.fill")
                }
                NavigationLink {
                    TodayView(snapshot: snapshot)
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                if snapshot.currentWalk != nil {
                    NavigationLink {
                        FamilyWalkView(snapshot: snapshot)
                    } label: {
                        Label("Family Walk", systemImage: "figure.walk")
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
        if let generations {
            return String(localized: "\(living) living · \(generations) gen · from iPhone", locale: snapshot.localeKinship.locale)
        }
        return String(localized: "\(familyCount) people · from iPhone", locale: snapshot.localeKinship.locale)
    }

    private var placesFooter: String {
        let nearby = snapshot.nearbyPlaces.count
        let cemetery = snapshot.cemeteryPins.isEmpty ? snapshot.burialPlaces.count : snapshot.cemeteryPins.count
        return String(localized: "\(nearby) places · \(cemetery) cemetery pins · offline", locale: snapshot.localeKinship.locale)
    }

    private var memoriesFooter: String {
        let featured = snapshot.featuredMemories.count
        let moments = WatchSnapshotExplorer.timelineMoments(in: snapshot).count
        let today = WatchSnapshotExplorer.todayEvents(in: snapshot).count
        if snapshot.memorialRemindersEnabled == true {
            return String(localized: "\(featured) featured · \(moments) moments · \(today) today", locale: snapshot.localeKinship.locale)
        }
        return String(localized: "\(featured) featured · \(moments) moments. Opt in to memorials on iPhone for Today.", locale: snapshot.localeKinship.locale)
    }
}

#Preview {
    NavigationStack {
        WatchHomeView(snapshot: WatchSnapshotExplorer.sample())
    }
}
