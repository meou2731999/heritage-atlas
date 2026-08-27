import Foundation
import SwiftData

@Model
public final class AppSettings {
    /// Well-known id for the single settings row. Not unique-constrained (CloudKit forbids it).
    public var id: UUID = AppSettings.singletonID
    public var mePersonID: UUID?
    public var localeKinship: KinshipLocale = KinshipLocale.vi
    public var memorialRemindersEnabled: Bool = false
    public var favoritePersonIDs: [UUID] = []
    public var recentPersonIDs: [UUID] = []
    public var currentFamilyWalkID: UUID?

    public init(
        id: UUID = AppSettings.singletonID,
        mePersonID: UUID? = nil,
        localeKinship: KinshipLocale = .vi,
        memorialRemindersEnabled: Bool = false,
        favoritePersonIDs: [UUID] = [],
        recentPersonIDs: [UUID] = [],
        currentFamilyWalkID: UUID? = nil
    ) {
        self.id = id
        self.mePersonID = mePersonID
        self.localeKinship = localeKinship
        self.memorialRemindersEnabled = memorialRemindersEnabled
        self.favoritePersonIDs = favoritePersonIDs
        self.recentPersonIDs = recentPersonIDs
        self.currentFamilyWalkID = currentFamilyWalkID
    }
}

extension AppSettings {
    public static let singletonID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    @MainActor
    public static func current(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
