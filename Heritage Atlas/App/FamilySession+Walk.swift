import Foundation
import HeritageAtlasCore
import SwiftData

extension FamilySession {
    func saveWalk(
        existing: FamilyWalk?,
        title: String,
        stopIDs: [UUID],
        notes: String?,
        makeCurrent: Bool,
        context: ModelContext
    ) -> UUID {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesValue = (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil
        let walk: FamilyWalk
        if let existing {
            walk = existing
            walk.title = trimmedTitle
            walk.stopIDs = stopIDs
            walk.notes = notesValue
        } else {
            walk = FamilyWalk(title: trimmedTitle, stopIDs: stopIDs, notes: notesValue)
            context.insert(walk)
        }
        if makeCurrent {
            AppSettings.current(in: context).currentFamilyWalkID = walk.id
        }
        persistDataChange(context: context)
        return walk.id
    }

    func deleteWalk(_ walk: FamilyWalk, context: ModelContext) {
        let settings = AppSettings.current(in: context)
        if settings.currentFamilyWalkID == walk.id {
            settings.currentFamilyWalkID = nil
        }
        context.delete(walk)
        persistDataChange(context: context)
    }

    func setCurrentWalk(_ walkID: UUID?, context: ModelContext) {
        AppSettings.current(in: context).currentFamilyWalkID = walkID
        persistSettingsChange(context: context, rebuildCache: false)
    }

    func setMemorialRemindersEnabled(_ enabled: Bool, context: ModelContext) {
        AppSettings.current(in: context).memorialRemindersEnabled = enabled
        persistSettingsChange(context: context, rebuildCache: false)
    }
}
