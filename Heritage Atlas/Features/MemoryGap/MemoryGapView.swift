import HeritageAtlasCore
import SwiftData
import SwiftUI

struct MemoryGapView: View {
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query private var settingsRows: [AppSettings]

    @State private var recordPersonID: UUID?

    private var locale: KinshipLocale { settingsRows.first?.localeKinship ?? .en }

    private var report: MemoryGapReport {
        MemoryGapAnalyzer.report(
            people: FamilyCalendarSourceBuilder.memoryGapPeople(
                people: people,
                personPlaces: personPlaces,
                memories: memories
            ),
            locale: locale
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(report.coveragePercent)%")
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                    Text("\(report.peopleWithStory) of \(report.peopleTotal) people have a story.")
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(report.coveragePercent), total: 100)
                }
                .padding(.vertical, 4)
            }

            if report.prompts.isEmpty == false {
                Section("Ask next") {
                    ForEach(report.prompts) { prompt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt.question)
                            Button {
                                recordPersonID = prompt.personID
                            } label: {
                                Label("Record", systemImage: "mic.fill")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Missing a story") {
                if report.missingStories.isEmpty {
                    Text("Every person has a story.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.missingStories) { person in
                        HStack {
                            NavigationLink {
                                PersonProfileView(personID: person.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                    Text(person.isLiving ? LocalizedStringKey("Living") : LocalizedStringKey("Remembered"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button("Record") {
                                recordPersonID = person.id
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle("Memory Gap")
        .sheet(isPresented: Binding(
            get: { recordPersonID != nil },
            set: { if !$0 { recordPersonID = nil } }
        )) {
            if let recordPersonID {
                MemoryEditorView(presetPersonID: recordPersonID, presetKind: .story)
            }
        }
    }
}
