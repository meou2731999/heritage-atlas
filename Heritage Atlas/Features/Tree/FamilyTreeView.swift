import HeritageAtlasCore
import SwiftData
import SwiftUI

struct FamilyTreeView: View {
    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var settingsRows: [AppSettings]

    @State private var path = NavigationPath()
    @State private var focusID: UUID?
    @State private var collapsedIDs: Set<UUID> = []
    @State private var editorMode: PersonEditorMode?
    @State private var showAddRelationship = false
    @State private var jumpTarget: JumpKind?
    @State private var showJumpPicker = false

    private var settings: AppSettings? { settingsRows.first }
    private var photoIDs: [UUID: UUID] {
        Dictionary(uniqueKeysWithValues: people.compactMap { person in
            guard let photo = person.photoMediaID else { return nil }
            return (person.id, photo)
        })
    }

    private var resolvedFocusID: UUID? {
        if let focusID, session.graph.people[focusID] != nil { return focusID }
        if let me = settings?.mePersonID, session.graph.people[me] != nil { return me }
        return people.first?.id
    }

    private var layout: TreeLayout {
        guard let resolvedFocusID else { return .empty }
        return TreeLayoutEngine.layout(
            graph: session.graph,
            focusID: resolvedFocusID,
            collapsedIDs: collapsedIDs
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if people.isEmpty {
                    emptyState
                } else if let resolvedFocusID {
                    VStack(spacing: 0) {
                        FamilyTreeCanvasView(
                            layout: layout,
                            focusID: resolvedFocusID,
                            photoIDs: photoIDs,
                            onFocus: { id in
                                focusID = id
                                session.treeFocusID = id
                            },
                            onOpenProfile: { id in
                                path.append(id)
                            },
                            onToggleCollapse: { id in
                                if collapsedIDs.contains(id) {
                                    collapsedIDs.remove(id)
                                } else {
                                    collapsedIDs.insert(id)
                                }
                            }
                        )
                        TreeJumpBar(
                            graph: session.graph,
                            focusID: resolvedFocusID
                        ) { kind in
                            jump(kind, around: resolvedFocusID)
                        }
                    }
                }
            }
            .navigationTitle("Family Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(for: UUID.self) { id in
                PersonProfileView(personID: id)
            }
            .sheet(item: $editorMode) { mode in
                PersonEditorView(mode: mode)
            }
            .sheet(isPresented: $showAddRelationship) {
                if let person = currentPerson {
                    AddRelationshipSheet(person: person)
                }
            }
            .confirmationDialog(jumpTarget?.title ?? LocalizedStringKey("Jump"), isPresented: $showJumpPicker, titleVisibility: .visible) {
                ForEach(jumpCandidates, id: \.id) { node in
                    Button(node.displayName) {
                        focusID = node.id
                        session.treeFocusID = node.id
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                if focusID == nil {
                    focusID = session.treeFocusID ?? settings?.mePersonID ?? people.first?.id
                }
                session.refresh(context: modelContext)
            }
            .onChange(of: session.treeFocusID) { _, newValue in
                if let newValue {
                    focusID = newValue
                }
            }
        }
    }

    private var currentPerson: Person? {
        guard let resolvedFocusID else { return nil }
        return people.first { $0.id == resolvedFocusID }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No family yet", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
            Text("Add a person to start the tree. The first person can be set as Me.")
        } actions: {
            Button("Add a person") {
                editorMode = .create
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Recenter", systemImage: "scope") {
                    focusID = session.treeFocusID ?? settings?.mePersonID ?? focusID
                    session.treeFocusID = focusID
                }
                if let meID = settings?.mePersonID {
                    Button("Focus Me", systemImage: "person.crop.circle") {
                        focusID = meID
                        session.treeFocusID = meID
                    }
                }
                Button("Expand all", systemImage: "arrow.up.left.and.arrow.down.right") {
                    collapsedIDs.removeAll()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let resolvedFocusID {
                Button {
                    path.append(resolvedFocusID)
                } label: {
                    Image(systemName: "person.crop.rectangle")
                }
                .accessibilityLabel("Open profile")
            }
            Button {
                editorMode = .create
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add person")
            if currentPerson != nil {
                Button {
                    showAddRelationship = true
                } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Add relationship")
            }
        }
    }

    private var jumpCandidates: [PersonNode] {
        guard let jumpTarget, let resolvedFocusID else { return [] }
        return jumpTarget.people(in: session.graph, focusID: resolvedFocusID)
    }

    private func jump(_ kind: JumpKind, around focus: UUID) {
        let people = kind.people(in: session.graph, focusID: focus)
        if people.count == 1, let only = people.first {
            focusID = only.id
            session.treeFocusID = only.id
        } else if people.count > 1 {
            jumpTarget = kind
            showJumpPicker = true
        }
    }
}

private enum JumpKind: String, Identifiable {
    case parents
    case siblings
    case spouses
    case children

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .parents: "Parents"
        case .siblings: "Siblings"
        case .spouses: "Spouse"
        case .children: "Children"
        }
    }

    func people(in graph: RelationshipGraph, focusID: UUID) -> [PersonNode] {
        switch self {
        case .parents: graph.sortedParents(graph.parents(of: focusID))
        case .siblings: graph.sortedByBirth(graph.siblings(of: focusID))
        case .spouses: graph.sortedByBirth(graph.spousesAndPartners(of: focusID))
        case .children: graph.sortedByBirth(graph.children(of: focusID))
        }
    }
}

private struct TreeJumpBar: View {
    let graph: RelationshipGraph
    let focusID: UUID
    var onJump: (JumpKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            jumpButton(.parents, systemImage: "arrow.up", enabled: !graph.parents(of: focusID).isEmpty)
            jumpButton(.siblings, systemImage: "person.2", enabled: !graph.siblings(of: focusID).isEmpty)
            jumpButton(.spouses, systemImage: "heart", enabled: !graph.spousesAndPartners(of: focusID).isEmpty)
            jumpButton(.children, systemImage: "arrow.down", enabled: !graph.children(of: focusID).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func jumpButton(_ kind: JumpKind, systemImage: String, enabled: Bool) -> some View {
        Button {
            onJump(kind)
        } label: {
            Label(kind.title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }
}
