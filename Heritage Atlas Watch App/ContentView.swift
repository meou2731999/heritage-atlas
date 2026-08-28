import HeritageAtlasCore
import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var envelopes: [WatchSnapshotEnvelope]

    private var snapshot: WatchSnapshot? {
        try? envelopes.first?.snapshot()
    }

    var body: some View {
        NavigationStack {
            if let snapshot {
                WatchHomeView(snapshot: snapshot)
            } else {
                SnapshotEmptyView()
            }
        }
        .heritageLocale(snapshot?.localeKinship ?? .vi)
    }
}

#Preview("Home") {
    let container = PersistenceController.makeInMemoryWatchContainer()
    let context = ModelContext(container)
    try? WatchSnapshotApplier.apply(WatchSnapshotExplorer.sample(), to: context)
    return ContentView()
        .modelContainer(container)
}

#Preview("Empty") {
    ContentView()
        .modelContainer(PersistenceController.makeInMemoryWatchContainer())
}
