import HeritageAtlasCore
import SwiftData
import SwiftUI

struct RelationshipLookupView: View {
    @Environment(FamilySession.self) private var session
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var settingsRows: [AppSettings]

    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var picking: PickingSide?
    @State private var path = NavigationPath()

    private var settings: AppSettings? { settingsRows.first }
    private var locale: KinshipLocale { settings?.localeKinship ?? .vi }

    private var fromPerson: Person? { people.first { $0.id == fromID } }
    private var toPerson: Person? { people.first { $0.id == toID } }

    var body: some View {
        List {
            Section("People") {
                Button {
                    picking = .from
                } label: {
                    pickerRow(title: "Person A", person: fromPerson)
                }
                Button {
                    picking = .to
                } label: {
                    pickerRow(title: "Person B", person: toPerson)
                }
                if settings?.mePersonID != nil {
                    Button("Person A is Me") {
                        fromID = settings?.mePersonID
                    }
                }
            }

            Section("Relationship") {
                resultBlock
            }

            if let fromID, let toID, fromID != toID {
                Section {
                    NavigationLink(value: fromID) {
                        Text("Open \(fromPerson?.displayName ?? "person A")")
                    }
                    NavigationLink(value: toID) {
                        Text("Open \(toPerson?.displayName ?? "person B")")
                    }
                }
            }
        }
        .navigationTitle("Relationship")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            PersonProfileView(personID: id)
        }
        .sheet(item: $picking) { side in
            PersonPickerSheet(title: side == .from ? "Person A" : "Person B") { person in
                guard let person else { return }
                switch side {
                case .from: fromID = person.id
                case .to: toID = person.id
                }
            }
        }
        .onAppear {
            if fromID == nil {
                fromID = settings?.mePersonID ?? people.first?.id
            }
        }
    }

    @ViewBuilder
    private var resultBlock: some View {
        if people.count < 2 {
            Text("Add at least two people to look up a relationship.")
                .foregroundStyle(.secondary)
        } else if fromID == nil || toID == nil {
            Text("Choose two people.")
                .foregroundStyle(.secondary)
        } else if fromID == toID {
            Text("That’s the same person.")
                .foregroundStyle(.secondary)
        } else if let fromID, let toID {
            let path = session.graph.shortestPath(from: fromID, to: toID)
            if let path {
                let naming = KinshipNamer.name(path: path, graph: session.graph, locale: locale)
                VStack(alignment: .leading, spacing: 12) {
                    Text(naming.term)
                        .font(.title3.weight(.semibold))
                    Text(naming.pathExplanation)
                        .foregroundStyle(.secondary)
                    pathGlance(path)
                    HStack(alignment: .top, spacing: 16) {
                        callCard(
                            title: "You call them",
                            subtitle: fromPerson?.displayName ?? "A",
                            value: naming.youCallThem
                        )
                        callCard(
                            title: "They call you",
                            subtitle: toPerson?.displayName ?? "B",
                            value: naming.theyCallYou
                        )
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("No relationship path connects these two people.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pickerRow(title: String, person: Person?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let person {
                Text(person.displayName)
                    .foregroundStyle(.primary)
            } else {
                Text("Choose")
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func pathGlance(_ path: KinPath) -> some View {
        let names = path.personIDs.compactMap { id in
            people.first { $0.id == id }?.displayName ?? session.graph.person(id)?.displayName
        }
        let hops = path.hops
        var parts: [String] = []
        for index in names.indices {
            parts.append(names[index])
            if index < hops.count {
                parts.append(hops[index].glanceArrow)
            }
        }
        return Text(parts.joined(separator: " "))
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
    }

    private func callCard(title: String, subtitle: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum PickingSide: String, Identifiable {
    case from
    case to
    var id: String { rawValue }
}
