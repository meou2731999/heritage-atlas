import HeritageAtlasCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \FamilyWalk.title) private var walks: [FamilyWalk]
    @Query private var settingsRows: [AppSettings]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query private var events: [TimelineEvent]

    @State private var path = NavigationPath()
    @State private var pickingMe = false
    @State private var confirmSeed = false
    @State private var locale: KinshipLocale = .vi

    private var settings: AppSettings? { settingsRows.first }
    private var me: Person? {
        guard let id = settings?.mePersonID else { return nil }
        return people.first { $0.id == id }
    }

    private var currentWalkTitle: String {
        guard let id = settings?.currentFamilyWalkID else { return HeritageLocale.string("None") }
        return walks.first { $0.id == id }?.title ?? HeritageLocale.string("None")
    }

    private var syncStatusLabel: String {
        if !CloudKitAvailability.isCloudKitSyncEnabled {
            return HeritageLocale.string("Paused")
        }
        return CloudKitAvailability.isICloudAccountAvailable
            ? HeritageLocale.string("Available")
            : HeritageLocale.string("Off this device")
    }

    private var syncFooter: String {
        if !CloudKitAvailability.isCloudKitSyncEnabled {
            return HeritageLocale.string("iCloud sync is paused. Family data stays on this device — the tree, search, and relationships work fully offline.")
        }
        if CloudKitAvailability.isICloudAccountAvailable {
            return HeritageLocale.string("Family data can sync between your devices when iCloud is on. Heritage Atlas never requires sign-in.")
        }
        return HeritageLocale.string("Working locally. iCloud is optional — the family tree, search, and relationships work fully offline.")
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        pickingMe = true
                    } label: {
                        HStack {
                            Text("Me")
                            Spacer()
                            Text(me?.displayName ?? HeritageLocale.string("Not set"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if people.isEmpty {
                        Text("The first person you add becomes Me automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Proband")
                } footer: {
                    Text("Kinship names are computed from Me. You can change this anytime.")
                }

                Section {
                    Picker("Language", selection: $locale) {
                        ForEach(KinshipLocale.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .onChange(of: locale) { _, newValue in
                        session.setKinshipLocale(newValue, context: modelContext)
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("App screens and kinship names use this language.")
                }

                Section {
                    Toggle("Memorial reminders", isOn: Binding(
                        get: { settings?.memorialRemindersEnabled ?? false },
                        set: { enabled in
                            session.setMemorialRemindersEnabled(enabled, context: modelContext)
                            Task {
                                let source = FamilyCalendarSourceBuilder.make(
                                    people: people,
                                    personPlaces: personPlaces,
                                    memories: memories,
                                    events: events,
                                    locale: settings?.localeKinship ?? .en
                                )
                                await MemorialReminderScheduler.refresh(
                                    events: FamilyCalendar.events(from: source),
                                    enabled: enabled,
                                    locale: settings?.localeKinship ?? .en
                                )
                            }
                        }
                    ))
                    NavigationLink {
                        MemorialCalendarView()
                    } label: {
                        Text("Family calendar")
                    }
                    NavigationLink {
                        FamilyWalkListView()
                    } label: {
                        HStack {
                            Text("Family Walk")
                            Spacer()
                            Text(currentWalkTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Today & Walk")
                } footer: {
                    Text("Reminders are off until you opt in. Watch Today and local notifications use this switch — they never require iCloud.")
                }

                Section {
                    HStack {
                        Text("iCloud")
                        Spacer()
                        Text(syncStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                    Text(syncFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sync")
                }

                if let message = session.lastErrorMessage, !message.isEmpty {
                    Section("Status") {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Load sample family") {
                        confirmSeed = true
                    }
                    Text("Adds a three-generation demo family with homes, schools, burial pins, stories, a life timeline, and a Family Walk so you can try the tree, map, Watch glances, and walk. Not loaded automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Developer")
                }

                if let me {
                    Section("Me profile") {
                        NavigationLink(value: me.id) {
                            PersonRowView(person: me, showMeBadge: true)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: UUID.self) { id in
                PersonProfileView(personID: id)
            }
            .sheet(isPresented: $pickingMe) {
                PersonPickerSheet(title: "Who is Me?", allowNone: true) { person in
                    session.setMe(personID: person?.id, context: modelContext)
                }
            }
            .onAppear {
                locale = settings?.localeKinship ?? .vi
            }
            .onChange(of: settings?.localeKinship) { _, newValue in
                if let newValue {
                    locale = newValue
                }
            }
            .confirmationDialog("Load sample family?", isPresented: $confirmSeed, titleVisibility: .visible) {
                Button("Add sample family") {
                    session.seedDemoFamily(context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This adds demo relatives. Existing people are kept.")
            }
        }
    }
}
