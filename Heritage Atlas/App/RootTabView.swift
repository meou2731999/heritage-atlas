import HeritageAtlasCore
import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home
    case tree
    case map
    case search
    case settings
}

enum FamilyMapMode: String, CaseIterable, Hashable {
    case family
    case cemetery

    var title: String {
        switch self {
        case .family: "Family"
        case .cemetery: "Cemetery"
        }
    }
}

struct RootTabView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Tree", systemImage: "point.3.connected.trianglepath.dotted", value: AppTab.tree) {
                FamilyTreeView()
            }
            Tab("Map", systemImage: "map.fill", value: AppTab.map) {
                MapHubView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .task {
            session.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.refresh(context: modelContext)
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryPhoneContainer()
    HeritageAtlasBootstrap.ensureSettings(in: container)
    return RootTabView()
        .modelContainer(container)
        .environment(FamilySession())
        .environment(DeviceLocationSession())
}
