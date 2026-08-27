import HeritageAtlasCore
import SwiftUI

struct FavoritesView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        List {
            if snapshot.favorites.isEmpty {
                ContentUnavailableView(
                    snapshot.localeKinship == .vi ? "Chưa có yêu thích" : "No favorites",
                    systemImage: "heart"
                )
            } else {
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
        .navigationTitle(snapshot.localeKinship == .vi ? "Yêu thích" : "Favorites")
    }
}

#Preview {
    NavigationStack {
        FavoritesView(snapshot: WatchSnapshotExplorer.sample())
    }
}
