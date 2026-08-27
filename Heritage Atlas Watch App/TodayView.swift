import HeritageAtlasCore
import SwiftUI

struct TodayView: View {
    let snapshot: WatchSnapshot

    private var isVI: Bool { snapshot.localeKinship == .vi }

    private var optedIn: Bool { snapshot.memorialRemindersEnabled == true }

    private var events: [WatchCalendarEvent] {
        WatchSnapshotExplorer.todayEvents(in: snapshot)
    }

    var body: some View {
        List {
            if optedIn == false {
                ContentUnavailableView(
                    isVI ? "Hôm nay tắt" : "Today is off",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(isVI
                        ? "Bật Memorial reminders trên iPhone để xem sinh nhật, giỗ và ngày cưới ở đây."
                        : "Turn on Memorial reminders on iPhone to see birthdays, giỗ, and weddings here.")
                )
            } else if events.isEmpty {
                ContentUnavailableView(
                    isVI ? "Hôm nay yên" : "Nothing today",
                    systemImage: "calendar",
                    description: Text(isVI
                        ? "Không có sinh nhật, giỗ hay ngày cưới hôm nay."
                        : "No birthdays, memorials, or weddings today.")
                )
            } else {
                Section(isVI ? "Hôm nay" : "Today") {
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
                Section(isVI ? "Gia đình" : "Family") {
                    LabeledContent(isVI ? "Còn sống" : "Living", value: "\(glance.livingCount)")
                    LabeledContent(isVI ? "Thế hệ" : "Generations", value: "\(glance.generationCount)")
                }
            }
        }
        .navigationTitle(isVI ? "Hôm nay" : "Today")
    }

    private func subtitle(_ event: WatchCalendarEvent) -> String {
        let kind = event.kind.localizedName(snapshot.localeKinship)
        if let years = event.years {
            return isVI ? "\(kind) · \(years) năm" : "\(kind) · \(years) years"
        }
        return kind
    }
}

#Preview {
    NavigationStack {
        TodayView(snapshot: WatchSnapshotExplorer.sample())
    }
}
