import HeritageAtlasCore
import SwiftUI

struct TodayView: View {
    let snapshot: WatchSnapshot

    private var optedIn: Bool { snapshot.memorialRemindersEnabled == true }

    private var events: [WatchCalendarEvent] {
        WatchSnapshotExplorer.todayEvents(in: snapshot)
    }

    var body: some View {
        List {
            if optedIn == false {
                ContentUnavailableView(
                    "Today is off",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Turn on Memorial reminders on iPhone to see birthdays, giỗ, and weddings here.")
                )
            } else if events.isEmpty {
                ContentUnavailableView(
                    "Nothing today",
                    systemImage: "calendar",
                    description: Text("No birthdays, memorials, or weddings today.")
                )
            } else {
                Section("Today") {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                            Text(subtitle(event))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let glance = snapshot.insightsGlance {
                Section("Family") {
                    LabeledContent("Living", value: "\(glance.livingCount)")
                    LabeledContent("Generations", value: "\(glance.generationCount)")
                }
            }
        }
        .navigationTitle("Today")
    }

    private func subtitle(_ event: WatchCalendarEvent) -> String {
        let kind = event.kind.localizedName(snapshot.localeKinship)
        if let years = event.years {
            return String(localized: "\(kind) · \(years) years", locale: snapshot.localeKinship.locale)
        }
        return kind
    }
}

#Preview {
    NavigationStack {
        TodayView(snapshot: WatchSnapshotExplorer.sample())
    }
}
