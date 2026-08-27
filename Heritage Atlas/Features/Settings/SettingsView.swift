import HeritageAtlasCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var settingsRows: [AppSettings]

    @State private var path = NavigationPath()
    @State private var pickingMe = false
    @State private var confirmSeed = false
    @State private var locale: KinshipLocale = .vi

    private var settings: AppSettings? { settingsRows.first }
    private var me: Person? {
        guard let id = settings?.mePersonID else { return nil }
        return people.first { $0.id == id }
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
                            Text(me?.displayName ?? "Not set")
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
                    Picker("Kinship language", selection: $locale) {
                        ForEach(KinshipLocale.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .onChange(of: locale) { _, newValue in
                        session.setKinshipLocale(newValue, context: modelContext)
                    }
                } header: {
                    Text("Address terms")
                } footer: {
                    Text("Vietnamese (Chú, Bác, Cậu…) or English (Uncle, Aunt…).")
                }

                Section {
                    HStack {
                        Text("iCloud")
                        Spacer()
                        Text(CloudKitAvailability.isICloudAccountAvailable ? "Available" : "Off this device")
                            .foregroundStyle(.secondary)
                    }
                    Text(CloudKitAvailability.isICloudAccountAvailable
                         ? "Family data can sync between your devices when iCloud is on. Heritage Atlas never requires sign-in."
                         : "Working locally. iCloud is optional — the family tree, search, and relationships work fully offline.")
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
                    Text("Adds a three-generation demo family with homes, schools, burial pins, stories, and a life timeline so you can try the tree, map, and Watch glances. Not loaded automatically.")
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
