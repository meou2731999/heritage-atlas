import Foundation

public enum CloudKitAvailability: Sendable {
    /// True when this device has an iCloud account. Never used to block app launch.
    public static var isICloudAccountAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
