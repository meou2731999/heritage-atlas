import HeritageAtlasCore
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(FamilySession.self) private var session
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query private var settingsRows: [AppSettings]

    private var insights: FamilyInsights {
        FamilyInsightsEngine.compute(
            people: people.map { $0.asNode() },
            graph: session.graph,
            mePersonID: settingsRows.first?.mePersonID,
            placeCount: places.count,
            burialCount: personPlaces.filter { $0.role == .burial }.count,
            memoryCount: memories.count,
            storyCount: memories.filter { $0.kind == .story }.count
        )
    }

    var body: some View {
        List {
            Section("Family") {
                metric("Living", "\(insights.livingCount)")
                metric("Remembered", "\(insights.deceasedCount)")
                metric("People", "\(insights.peopleCount)")
                metric("Generations", "\(insights.generationCount)")
            }

            Section("Places & memories") {
                metric("Places", "\(insights.placeCount)")
                metric("Burials", "\(insights.burialCount)")
                metric("Memories", "\(insights.memoryCount)")
                metric("Stories", "\(insights.storyCount)")
            }

            if let oldest = insights.oldestAncestor {
                Section("Oldest ancestor") {
                    NavigationLink {
                        PersonProfileView(personID: oldest.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(oldest.name)
                            if let birth = PersonLifeSpan.longDate(oldest.birthDate) {
                                Text("Born \(birth)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let largest = insights.largestGeneration {
                Section {
                    ForEach(largest.people) { person in
                        NavigationLink {
                            PersonProfileView(personID: person.id)
                        } label: {
                            Text(person.name)
                        }
                    }
                } header: {
                    Text("Largest generation · \(largest.count)")
                }
            }
        }
        .navigationTitle("Insights")
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
