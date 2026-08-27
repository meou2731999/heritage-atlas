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
                    snapshot.localeKinship == .vi ? "Không có kết quả" : "No matches",
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
        .searchable(text: $query, prompt: snapshot.localeKinship == .vi ? "Tên, biệt danh, xưng hô" : "Name, nickname, kinship")
        .navigationTitle(snapshot.localeKinship == .vi ? "Tìm" : "Search")
    }
}

#Preview {
    NavigationStack {
        SearchPersonView(snapshot: WatchSnapshotExplorer.sample())
    }
}
