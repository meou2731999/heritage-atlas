import HeritageAtlasCore
import SwiftData
import SwiftUI

@main
struct Heritage_AtlasApp: App {
    let container: ModelContainer
    @State private var session = FamilySession()
    @State private var locationSession = DeviceLocationSession()

    init() {
        let container = PersistenceController.makePhoneContainer()
        self.container = container
        HeritageAtlasBootstrap.ensureSettings(in: container)
        WatchConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(session)
                .environment(locationSession)
                .onAppear {
                    session.bindWatchConnectivity(container: container)
                }
        }
        .modelContainer(container)
    }
}
