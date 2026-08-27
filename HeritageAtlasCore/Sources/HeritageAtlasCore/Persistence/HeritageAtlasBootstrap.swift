import Foundation
import SwiftData

@MainActor
public enum HeritageAtlasBootstrap {
    /// Ensures a settings row exists so the phone container is usable immediately, offline, with no iCloud.
    public static func ensureSettings(in container: ModelContainer) {
        let context = ModelContext(container)
        _ = AppSettings.current(in: context)
        try? context.save()
    }
}
