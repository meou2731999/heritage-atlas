import HeritageAtlasCore
import SwiftData
import SwiftUI

enum RelativeRole: String, CaseIterable, Identifiable {
    case parent
    case child
    case spouse
    case partner
    case adoptiveParent
    case adoptiveChild
    case stepParent
    case stepChild

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parent: "Parent"
        case .child: "Child"
        case .spouse: "Spouse"
        case .partner: "Partner"
        case .adoptiveParent: "Adoptive parent"
        case .adoptiveChild: "Adopted child"
        case .stepParent: "Step-parent"
        case .stepChild: "Step-child"
        }
    }

    var kind: KinRelationshipKind {
        switch self {
        case .parent, .child: .parent
        case .spouse: .spouse
        case .partner: .partner
        case .adoptiveParent, .adoptiveChild: .adoptiveParent
        case .stepParent, .stepChild: .stepParent
        }
    }

    /// Stored edge is `from` → `to`. Child roles invert so the current person is the parent.
    var currentIsFrom: Bool {
        switch self {
        case .child, .spouse, .partner, .adoptiveChild, .stepChild:
            return true
        case .parent, .adoptiveParent, .stepParent:
            return false
        }
    }
}

struct AddRelationshipSheet: View {
    let person: Person
    var onFinished: (() -> Void)?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var people: [Person]

    @State private var role: RelativeRole = .parent
    @State private var query = ""
    @State private var showNewPerson = false

    private var candidates: [Person] {
        people
            .filter { $0.id != person.id }
            .filter { PersonSearch.matches($0, query: query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("This person is their") {
                    Picker("Relationship", selection: $role) {
                        ForEach(RelativeRole.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        showNewPerson = true
                    } label: {
                        Label("Create new person", systemImage: "person.badge.plus")
                    }
                }

                Section("Choose existing") {
                    if candidates.isEmpty {
                        Text(query.isEmpty ? "No other people yet." : "No matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                link(to: candidate)
                            } label: {
                                PersonRowView(person: candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Name or nickname")
            .navigationTitle("Add relationship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showNewPerson) {
                PersonEditorView(mode: .create) { newID in
                    let id = newID
                    let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })
                    if let other = try? modelContext.fetch(descriptor).first {
                        link(to: other)
                    }
                }
            }
        }
    }

    private func link(to other: Person) {
        let from = role.currentIsFrom ? person : other
        let to = role.currentIsFrom ? other : person
        session.addRelationship(from: from, to: to, kind: role.kind, context: modelContext)
        onFinished?()
        dismiss()
    }
}

struct PersonPickerSheet: View {
    let title: String
    var excludedIDs: Set<UUID> = []
    var allowNone = false
    var onSelect: (Person?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var people: [Person]
    @State private var query = ""

    private var filtered: [Person] {
        people
            .filter { !excludedIDs.contains($0.id) }
            .filter { PersonSearch.matches($0, query: query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if allowNone {
                    Button("None") {
                        onSelect(nil)
                        dismiss()
                    }
                }
                ForEach(filtered) { person in
                    Button {
                        onSelect(person)
                        dismiss()
                    } label: {
                        PersonRowView(person: person)
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "Name or nickname")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
