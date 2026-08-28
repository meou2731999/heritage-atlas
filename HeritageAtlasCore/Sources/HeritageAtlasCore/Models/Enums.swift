import Foundation

public enum Gender: String, Codable, Sendable, CaseIterable {
    case male
    case female
    case unknown
}

public enum KinRelationshipKind: String, Codable, Sendable, CaseIterable {
    case parent
    case spouse
    case partner
    case adoptiveParent
    case stepParent
}

public enum PlaceRole: String, Codable, Sendable, CaseIterable {
    case born
    case childhoodHome
    case school
    case workplace
    case wedding
    case hospital
    case home
    case burial

    public func localizedName(_ locale: KinshipLocale) -> String {
        switch (self, locale) {
        case (.born, .vi): "Nơi sinh"
        case (.born, .en): "Born"
        case (.childhoodHome, .vi): "Nhà thời thơ ấu"
        case (.childhoodHome, .en): "Childhood home"
        case (.school, .vi): "Trường"
        case (.school, .en): "School"
        case (.workplace, .vi): "Nơi làm việc"
        case (.workplace, .en): "Workplace"
        case (.wedding, .vi): "Đám cưới"
        case (.wedding, .en): "Wedding"
        case (.hospital, .vi): "Bệnh viện"
        case (.hospital, .en): "Hospital"
        case (.home, .vi): "Nhà"
        case (.home, .en): "Home"
        case (.burial, .vi): "Nơi an táng"
        case (.burial, .en): "Burial"
        }
    }

    public var systemImageName: String {
        switch self {
        case .born: "staroflife"
        case .childhoodHome: "figure.and.child.holdinghands"
        case .school: "graduationcap"
        case .workplace: "briefcase"
        case .wedding: "heart"
        case .hospital: "cross.case"
        case .home: "house"
        case .burial: "leaf"
        }
    }
}

public enum MemoryKind: String, Codable, Sendable, CaseIterable {
    case photo
    case audio
    case text
    case document
    case event
    case story

    public func localizedName(_ locale: KinshipLocale) -> String {
        switch (self, locale) {
        case (.photo, .vi): "Ảnh"
        case (.photo, .en): "Photo"
        case (.audio, .vi): "Âm thanh"
        case (.audio, .en): "Audio"
        case (.text, .vi): "Chữ"
        case (.text, .en): "Text"
        case (.document, .vi): "Tài liệu"
        case (.document, .en): "Document"
        case (.event, .vi): "Sự kiện"
        case (.event, .en): "Event"
        case (.story, .vi): "Câu chuyện"
        case (.story, .en): "Story"
        }
    }

    public var systemImageName: String {
        switch self {
        case .photo: "photo"
        case .audio: "waveform"
        case .text: "text.alignleft"
        case .document: "doc"
        case .event: "calendar"
        case .story: "book"
        }
    }

    public var isHearable: Bool {
        self == .audio || self == .story
    }
}

public enum TimelineEventKind: String, Codable, Sendable, CaseIterable {
    case born
    case moved
    case married
    case child
    case died
    case custom

    public func localizedName(_ locale: KinshipLocale) -> String {
        switch (self, locale) {
        case (.born, .vi): "Sinh"
        case (.born, .en): "Born"
        case (.moved, .vi): "Chuyển đến"
        case (.moved, .en): "Moved"
        case (.married, .vi): "Kết hôn"
        case (.married, .en): "Married"
        case (.child, .vi): "Con"
        case (.child, .en): "Child"
        case (.died, .vi): "Mất"
        case (.died, .en): "Died"
        case (.custom, .vi): "Khác"
        case (.custom, .en): "Custom"
        }
    }

    public var systemImageName: String {
        switch self {
        case .born: "staroflife"
        case .moved: "arrow.triangle.swap"
        case .married: "heart"
        case .child: "figure.and.child.holdinghands"
        case .died: "leaf"
        case .custom: "bookmark"
        }
    }

    /// Life milestones Watch should prefer when packing a few glanceable moments.
    public var watchMomentWeight: Int {
        switch self {
        case .born, .died: 50
        case .married: 40
        case .child: 30
        case .moved: 15
        case .custom: 10
        }
    }
}

public enum MediaKind: String, Codable, Sendable, CaseIterable {
    case photo
    case audio
    case document
    case thumbnail
}

public enum KinshipLocale: String, Codable, Sendable, CaseIterable {
    case vi
    case en

    public var locale: Locale {
        switch self {
        case .vi: Locale(identifier: "vi")
        case .en: Locale(identifier: "en")
        }
    }
}

/// In-app language used by String Catalog lookups (`String(localized:)`).
/// SwiftUI `Text("…")` follows `.environment(\.locale)` separately.
public enum HeritageLocale: Sendable {
    nonisolated(unsafe) public static var kinship: KinshipLocale = .vi

    public static var locale: Locale { kinship.locale }

    public static func string(
        _ key: String.LocalizationValue,
        locale kinshipLocale: KinshipLocale = kinship
    ) -> String {
        String(localized: key, bundle: .main, locale: kinshipLocale.locale)
    }
}

extension TimelineEventKind {
    /// Uses the current locale for canned born/died titles stored in another language.
    public func resolvedTitle(_ stored: String, locale: KinshipLocale) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return localizedName(locale) }
        if KinshipLocale.allCases.contains(where: { localizedName($0) == trimmed }) {
            return localizedName(locale)
        }
        return trimmed
    }
}
