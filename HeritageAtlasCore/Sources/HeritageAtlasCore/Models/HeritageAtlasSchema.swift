import Foundation
import SwiftData

public enum HeritageAtlasSchema {
    public static let version = 1

    public static let cloudKitContainerIdentifier = "iCloud.quan.ba.le.Heritage-Atlas"
    public static let phoneStoreName = "HeritageAtlas"
    public static let watchStoreName = "HeritageAtlasWatch"

    public static var phoneModels: [any PersistentModel.Type] {
        [
            Person.self,
            KinRelationship.self,
            Place.self,
            PersonPlace.self,
            Memory.self,
            TimelineEvent.self,
            FamilyWalk.self,
            MediaRef.self,
            AppSettings.self,
        ]
    }

    public static var watchModels: [any PersistentModel.Type] {
        [WatchSnapshotEnvelope.self]
    }
}
