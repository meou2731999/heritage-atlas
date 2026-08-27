import Foundation
import HeritageAtlasCore
import SwiftUI

extension Person {
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return fullName.isEmpty ? "Unnamed" : fullName
    }

    var lifeYearsText: String {
        PersonLifeSpan.format(birth: birthDate, death: deathDate)
    }

    var initials: String {
        PersonName.initials(from: fullName.isEmpty ? displayName : fullName)
    }
}

enum PersonName {
    static func initials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "?" }
        if parts.count == 1 {
            return String(first).uppercased()
        }
        guard let last = parts.last?.first else {
            return String(first).uppercased()
        }
        return String([first, last]).uppercased()
    }
}

enum PersonLifeSpan {
    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func format(birth: Date?, death: Date?) -> String {
        switch (birth, death) {
        case (nil, nil):
            return ""
        case (let birth?, nil):
            return "\(yearFormatter.string(from: birth))–"
        case (nil, let death?):
            return "–\(yearFormatter.string(from: death))"
        case (let birth?, let death?):
            return "\(yearFormatter.string(from: birth))–\(yearFormatter.string(from: death))"
        }
    }

    static func longDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        return dateFormatter.string(from: date)
    }
}

extension Gender {
    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unknown: "Unknown"
        }
    }

    var avatarTint: Color {
        switch self {
        case .male: Color(red: 0.36, green: 0.52, blue: 0.58)
        case .female: Color(red: 0.62, green: 0.42, blue: 0.40)
        case .unknown: Color(red: 0.50, green: 0.48, blue: 0.44)
        }
    }
}

extension KinshipLocale {
    var displayName: String {
        switch self {
        case .vi: "Tiếng Việt"
        case .en: "English"
        }
    }
}

extension KinRelationshipKind {
    var displayName: String {
        switch self {
        case .parent: "Parent"
        case .spouse: "Spouse"
        case .partner: "Partner"
        case .adoptiveParent: "Adoptive parent"
        case .stepParent: "Step-parent"
        }
    }
}

enum PersonSearch {
    static func matches(_ person: Person, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        if person.fullName.lowercased().contains(needle) { return true }
        if let nickname = person.nickname?.lowercased(), nickname.contains(needle) {
            return true
        }
        return false
    }
}

enum Greeting {
    static func text(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
