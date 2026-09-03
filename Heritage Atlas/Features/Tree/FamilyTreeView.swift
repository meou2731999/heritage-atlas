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
    @State private var showPersonPicker = false
    @State private var jumpTarget: JumpKind?
    @State private var showJumpPicker = false
    @State private var canvasRecenterID = 0
    @State private var pendingMenuCommand: TreeMenuCommand?

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

    /// People with no relationships, hidden because the canvas only draws the focused cluster.
    private var unlinkedPeople: [Person] {
        people
            .filter { person in
                person.id != resolvedFocusID && (session.graph.adjacency[person.id] ?? []).isEmpty
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
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
                            recenterID: canvasRecenterID,
                            onFocus: { id in
                                focusPerson(id, resetCamera: false)
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
                        treeBottomChrome(focusID: resolvedFocusID)
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
                PersonEditorView(mode: mode) { savedID in
                    if case .create = mode {
                        focusPerson(savedID)
                    }
                }
            }
            .sheet(isPresented: $showAddRelationship) {
                if let person = currentPerson {
                    AddRelationshipSheet(person: person)
                }
            }
            .sheet(isPresented: $showPersonPicker) {
                PersonPickerSheet(title: "Find person") { person in
                    if let person {
                        focusPerson(person.id)
                    }
                }
            }
            .confirmationDialog(jumpTarget?.title ?? LocalizedStringKey("Jump"), isPresented: $showJumpPicker, titleVisibility: .visible) {
                ForEach(jumpCandidates, id: \.id) { node in
                    Button(node.displayName) {
                        focusPerson(node.id)
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
            .onChange(of: pendingMenuCommand) { _, command in
                guard let command else { return }
                perform(command.action)
            }
        }
    }

    @ViewBuilder
    private func treeBottomChrome(focusID: UUID) -> some View {
        VStack(spacing: 0) {
            if unlinkedPeople.isEmpty == false {
                UnlinkedPeopleBar(people: unlinkedPeople) { id in
                    focusPerson(id)
                }
            }
            TreeJumpBar(
                graph: session.graph,
                focusID: focusID
            ) { kind in
                jump(kind, around: focusID)
            }
        }
        .background(.bar)
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
                Button("Find person", systemImage: "magnifyingglass") {
                    pendingMenuCommand = TreeMenuCommand(.findPerson)
                }
                Divider()
                Button("Recenter", systemImage: "scope") {
                    pendingMenuCommand = TreeMenuCommand(.recenter)
                }
                if settings?.mePersonID != nil {
                    Button("Focus Me", systemImage: "person.crop.circle") {
                        pendingMenuCommand = TreeMenuCommand(.focusMe)
                    }
                }
                Button("Expand all", systemImage: "arrow.up.left.and.arrow.down.right") {
                    pendingMenuCommand = TreeMenuCommand(.expandAll)
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
            focusPerson(only.id)
        } else if people.count > 1 {
            jumpTarget = kind
            showJumpPicker = true
        }
    }

    private func perform(_ action: TreeMenuAction) {
        switch action {
        case .findPerson:
            showPersonPicker = true
        case .recenter:
            canvasRecenterID += 1
        case .focusMe:
            guard let meID = settings?.mePersonID else { return }
            focusPerson(meID)
        case .expandAll:
            collapsedIDs.removeAll()
        }
    }

    private func focusPerson(_ id: UUID, resetCamera: Bool = true) {
        focusID = id
        session.treeFocusID = id
        if resetCamera {
            canvasRecenterID += 1
        }
    }
}

private enum TreeMenuAction: Equatable {
    case findPerson
    case recenter
    case focusMe
    case expandAll
}

private struct TreeMenuCommand: Equatable {
    var id = UUID()
    var action: TreeMenuAction

    init(_ action: TreeMenuAction) {
        self.action = action
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

private struct UnlinkedPeopleBar: View {
    let people: [Person]
    var onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlinked")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(people) { person in
                        Button {
                            onSelect(person.id)
                        } label: {
                            Text(person.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

private struct TreeJumpBar: View {
    let graph: RelationshipGraph
    let focusID: UUID
    var onJump: (JumpKind) -> Void

    var body: some View {
        HStack(spacing: 6) {
            jumpButton(.parents, systemImage: "arrow.up", enabled: !graph.parents(of: focusID).isEmpty)
            jumpButton(.siblings, systemImage: "person.2", enabled: !graph.siblings(of: focusID).isEmpty)
            jumpButton(.spouses, systemImage: "heart", enabled: !graph.spousesAndPartners(of: focusID).isEmpty)
            jumpButton(.children, systemImage: "arrow.down", enabled: !graph.children(of: focusID).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func jumpButton(_ kind: JumpKind, systemImage: String, enabled: Bool) -> some View {
        Button {
            onJump(kind)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                Text(kind.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(kind.title)
    }
}
