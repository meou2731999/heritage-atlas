import Foundation
import SwiftData

public enum PersistenceController: Sendable {
    /// iPhone source of truth. Works fully offline. CloudKit is attached only when iCloud is available;
    /// if CloudKit configuration fails, the same local store is opened with `cloudKitDatabase: .none`.
    public static func makePhoneContainer() -> ModelContainer {
        prepareApplicationSupportDirectory()
        let schema = Schema(HeritageAtlasSchema.phoneModels)

        if CloudKitAvailability.isICloudAccountAvailable {
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [phoneConfiguration(schema: schema, cloudKit: .private(HeritageAtlasSchema.cloudKitContainerIdentifier))]
                )
            } catch {
                // iCloud signed in but container/entitlements unavailable — continue locally.
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: [phoneConfiguration(schema: schema, cloudKit: .none)]
            )
        } catch {
            let memory = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    /// Watch cache only. Never uses CloudKit.
    public static func makeWatchContainer() -> ModelContainer {
        prepareApplicationSupportDirectory()
        let schema = Schema(HeritageAtlasSchema.watchModels)
        let configuration = ModelConfiguration(
            HeritageAtlasSchema.watchStoreName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let memory = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    public static func makeInMemoryPhoneContainer() -> ModelContainer {
        let schema = Schema(HeritageAtlasSchema.phoneModels)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryWatchContainer() -> ModelContainer {
        let schema = Schema(HeritageAtlasSchema.watchModels)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private static func phoneConfiguration(
        schema: Schema,
        cloudKit: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        ModelConfiguration(
            HeritageAtlasSchema.phoneStoreName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKit
        )
    }

    private static func prepareApplicationSupportDirectory() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    }
}
