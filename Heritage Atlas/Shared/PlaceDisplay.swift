import HeritageAtlasCore
import SwiftUI

extension PlaceRole {
    var displayName: String { localizedName(.en) }

    var mapTint: Color {
        switch self {
        case .home, .childhoodHome: Color(red: 0.36, green: 0.52, blue: 0.58)
        case .school: Color.orange
        case .workplace: Color.indigo
        case .wedding: Color.pink
        case .hospital, .born: Color(red: 0.75, green: 0.35, blue: 0.42)
        case .burial: Color(red: 0.45, green: 0.48, blue: 0.42)
        }
    }
}

enum PlaceYears {
    static func format(from: Int?, to: Int?) -> String {
        switch (from, to) {
        case (let from?, let to?): return "\(from)–\(to)"
        case (let from?, nil): return "\(from)–"
        case (nil, let to?): return "–\(to)"
        default: return ""
        }
    }
}

enum PlaceCoordinateText {
    static func parse(_ text: String) -> Double? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.6f", value)
    }
}

extension Place {
    var geoPoint: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
