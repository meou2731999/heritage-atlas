import HeritageAtlasCore
import SwiftData
import SwiftUI

@main
struct Heritage_Atlas_Watch_AppApp: App {
    let container: ModelContainer

    init() {
        let container = PersistenceController.makeWatchContainer()
        self.container = container
        WatchConnectivityService.shared.activate()
        WatchConnectivityService.shared.onSnapshotReceived = { snapshot in
            Task { @MainActor in
                try? WatchSnapshotApplier.apply(snapshot, to: container.mainContext)
            }
        }
        WatchConnectivityService.shared.onAudioFileTransferFinished = { url, error in
            if error == nil, url.lastPathComponent.contains("heritage-watch") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
