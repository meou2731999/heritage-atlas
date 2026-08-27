import HeritageAtlasCore
import SwiftData
import SwiftUI

struct MemorialCalendarView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query private var events: [TimelineEvent]
    @Query private var settingsRows: [AppSettings]

    @State private var remindersEnabled = false

    private var locale: KinshipLocale { settingsRows.first?.localeKinship ?? .en }

    private var source: FamilyCalendarSource {
        FamilyCalendarSourceBuilder.make(
            people: people,
            personPlaces: personPlaces,
            memories: memories,
            events: events,
            locale: locale
        )
    }

    private var calendarEvents: [FamilyCalendarEvent] {
        FamilyCalendar.events(from: source)
    }

    private var today: [FamilyCalendarEvent] {
        FamilyCalendar.occurring(on: Date(), in: calendarEvents)
    }

    private var upcoming: [FamilyCalendarEvent] {
        FamilyCalendar.upcoming(from: Date(), days: 45, in: calendarEvents)
    }

    private var memorials: [FamilyMemorialSummary] {
        FamilyCalendar.memorialSummaries(from: source)
    }

    var body: some View {
        List {
            Section {
                Toggle("Memorial reminders", isOn: $remindersEnabled)
            } footer: {
                Text("Off by default. When on, this iPhone can notify you on birthdays, giỗ, and wedding anniversaries, and Apple Watch shows Today.")
            }

            if today.isEmpty == false {
                Section("Today") {
                    ForEach(today) { event in
                        eventRow(event)
                    }
                }
            }

            Section("Upcoming") {
                if upcoming.isEmpty {
                    Text("No birthdays, giỗ, or weddings in the next 45 days.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcoming) { event in
                        eventRow(event)
                    }
                }
            }

            Section("Remembered") {
                if memorials.isEmpty {
                    Text("Add a death date or burial place to remember someone here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memorials, id: \.personID) { summary in
                        NavigationLink {
                            PersonProfileView(personID: summary.personID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.personName)
                                    .font(.body.weight(.medium))
                                Text(memorialSubtitle(summary))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Family calendar")
        .onAppear {
            remindersEnabled = settingsRows.first?.memorialRemindersEnabled ?? false
        }
        .onChange(of: remindersEnabled) { _, enabled in
            session.setMemorialRemindersEnabled(enabled, context: modelContext)
            Task {
                await MemorialReminderScheduler.refresh(events: calendarEvents, enabled: enabled)
            }
        }
    }

    private func eventRow(_ event: FamilyCalendarEvent) -> some View {
        NavigationLink {
            if let personID = event.personID {
                PersonProfileView(personID: personID)
            } else {
                EmptyView()
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                    Text(event.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: event.kind.systemImageName)
            }
        }
    }

    private func memorialSubtitle(_ summary: FamilyMemorialSummary) -> String {
        var parts: [String] = []
        if let death = PersonLifeSpan.longDate(summary.deathDate) {
            parts.append("Giỗ · \(death)")
        }
        if let burial = summary.burialPlaceName {
            parts.append(burial)
        }
        let remembered = summary.rememberedByCount == 1 ? "1 memory" : "\(summary.rememberedByCount) memories"
        parts.append(remembered)
        return parts.joined(separator: " · ")
    }
}
