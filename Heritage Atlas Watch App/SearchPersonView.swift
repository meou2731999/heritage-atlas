import HeritageAtlasCore
import SwiftUI

struct SearchPersonView: View {
    let snapshot: WatchSnapshot
    @State private var query = ""

    private var results: [WatchPerson] {
        WatchSnapshotExplorer.search(query, in: snapshot)
    }

    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass"
                )
            } else {
                ForEach(results) { person in
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
        .searchable(text: $query, prompt: "Name, nickname, kinship")
        .navigationTitle("Search")
    }
}

#Preview {
    NavigationStack {
        SearchPersonView(snapshot: WatchSnapshotExplorer.sample())
    }
}
