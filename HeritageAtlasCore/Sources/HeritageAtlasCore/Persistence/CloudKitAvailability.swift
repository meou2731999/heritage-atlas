import Foundation

public enum CloudKitAvailability: Sendable {
    /// CloudKit and remote-notification push need a paid Apple Developer Program membership.
    /// Set this to `true` (and restore iCloud entitlements) when the team has one.
    public static let isCloudKitSyncEnabled = false

    /// True when this device has an iCloud account *and* CloudKit sync is enabled.
    /// Never used to block app launch.
    public static var isICloudAccountAvailable: Bool {
        isCloudKitSyncEnabled && FileManager.default.ubiquityIdentityToken != nil
    }
}
