import HeritageAtlasCore
import SwiftData
import SwiftUI

struct PersonProfileView: View {
    let personID: UUID

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var relationships: [KinRelationship]
    @Query private var personPlaces: [PersonPlace]
    @Query private var settingsRows: [AppSettings]
    @Query private var memories: [Memory]

    @State private var editorMode: PersonEditorMode?
    @State private var showAddRelationship = false
    @State private var showPersonPlaceEditor = false
    @State private var editingPersonPlace: PersonPlace?
    @State private var confirmDelete = false

    private var person: Person? { people.first { $0.id == personID } }
    private var settings: AppSettings? { settingsRows.first }
    private var isMe: Bool { settings?.mePersonID == personID }

    var body: some View {
        Group {
            if let person {
                profile(person)
            } else {
                ContentUnavailableView("Person not found", systemImage: "person.slash")
            }
        }
        .navigationTitle(person?.displayName ?? HeritageLocale.string("Person"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        editorMode = .edit(personID)
                    }
                    Button("Set as Me", systemImage: "person.crop.circle") {
                        session.setMe(personID: personID, context: modelContext)
                    }
                    Button("Add relationship", systemImage: "person.2") {
                        showAddRelationship = true
                    }
                    Button(favoriteTitle, systemImage: session.isFavorite(personID: personID, context: modelContext) ? "heart.fill" : "heart") {
                        session.toggleFavorite(personID: personID, context: modelContext)
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            PersonEditorView(mode: mode)
        }
        .sheet(isPresented: $showAddRelationship) {
            if let person {
                AddRelationshipSheet(person: person)
            }
        }
        .sheet(isPresented: $showPersonPlaceEditor) {
            if let person {
                PersonPlaceEditorView(person: person, place: nil, existing: nil)
            }
        }
        .sheet(item: $editingPersonPlace) { link in
            PersonPlaceEditorView(person: person, place: link.place, existing: link)
        }
        .alert("Delete this person?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    guard let person else { return }
                    await session.deletePerson(person, context: modelContext)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their profile and relationships will be removed from this family. This cannot be undone.")
        }
        .onAppear {
            session.recordRecent(personID: personID, context: modelContext)
        }
    }

    @ViewBuilder
    private func profile(_ person: Person) -> some View {
        List {
            Section {
                header(person)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if let naming = kinshipNaming {
                Section("Relationship to you") {
                    kinshipCard(naming)
                }
            }

            Section("Details") {
                detailRow("Full name", person.fullName)
                if let nickname = person.nickname, !nickname.isEmpty {
                    detailRow("Nickname", nickname)
                }
                detailRow("Gender", person.gender.displayName)
                detailRow("Born", PersonLifeSpan.longDate(person.birthDate) ?? "—")
                detailRow("Died", PersonLifeSpan.longDate(person.deathDate) ?? (person.isLiving ? HeritageLocale.string("Living") : "—"))
                if let occupation = person.occupation, !occupation.isEmpty {
                    detailRow("Occupation", occupation)
                }
            }

            if !person.tags.isEmpty {
                Section("Tags") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(person.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }

            if let notes = person.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            placesSection(person)

            memorialSection(person)

            memorySection(person)

            relativesSection(person)

            Section {
                Button("Edit person") {
                    editorMode = .edit(personID)
                }
            }
        }
    }

    private func header(_ person: Person) -> some View {
        VStack(spacing: 12) {
            PersonAvatarView(person: person, size: 96)
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(person.displayName)
                        .font(.title2.weight(.semibold))
                    if isMe {
                        Text("Me")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                if person.nickname != nil, person.fullName != person.displayName {
                    Text(person.fullName)
                        .foregroundStyle(.secondary)
                }
                if !person.lifeYearsText.isEmpty {
                    Text(person.lifeYearsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var kinshipNaming: KinshipNaming? {
        guard settings?.mePersonID != nil, settings?.mePersonID != personID else { return nil }
        return session.relationshipCache.entry(for: personID)?.naming
    }

    private func kinshipCard(_ naming: KinshipNaming) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(naming.term)
                .font(.headline)
            Text(naming.pathExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                labeledValue("You call", naming.youCallThem)
                Spacer()
                labeledValue("They call you", naming.theyCallYou)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func labeledValue(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
        }
    }

    @ViewBuilder
    private func placesSection(_ person: Person) -> some View {
        let links = personPlaces
            .filter { $0.person?.id == person.id }
            .sorted { $0.role.displayName < $1.role.displayName }
        Section {
            if links.isEmpty {
                Text("No places yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(links) { link in
                    if let place = link.place {
                        NavigationLink {
                            PlaceDetailView(placeID: place.id)
                        } label: {
                            PlaceRowView(
                                place: place,
                                subtitle: placeSubtitle(link),
                                role: link.role
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Edit") { editingPersonPlace = link }
                            Button("Remove", role: .destructive) {
                                session.deletePersonPlace(link, context: modelContext)
                            }
                        }
                    }
                }
            }
            Button {
                showPersonPlaceEditor = true
            } label: {
                Label("Add place", systemImage: "mappin.and.ellipse")
            }
        } header: {
            Text("Places")
        }
    }

    @ViewBuilder
    private func memorialSection(_ person: Person) -> some View {
        let links = personPlaces.filter { $0.person?.id == person.id }
        let burial = links.first { $0.role == .burial }
        let linked = MemoryQueries.forPerson(person.id, in: memories)
        let stories = linked.filter { $0.kind == .story }
        if person.isLiving == false || burial != nil {
            Section("Memorial") {
                if let death = PersonLifeSpan.longDate(person.deathDate) {
                    detailRow("Giỗ", death)
                }
                if let burial, let place = burial.place {
                    NavigationLink {
                        PlaceDetailView(placeID: place.id)
                    } label: {
                        PlaceRowView(place: place, subtitle: HeritageLocale.string("Burial"), role: .burial)
                    }
                }
                detailRow("Remembered by", linked.isEmpty ? HeritageLocale.string("No memories yet") : HeritageLocale.string("\(linked.count) memories · \(stories.count) stories"))
                if stories.isEmpty {
                    NavigationLink {
                        MemoryGapView()
                    } label: {
                        Label("Record a story", systemImage: "mic")
                    }
                }
            }
        }
    }

    private var favoriteTitle: LocalizedStringKey {
        session.isFavorite(personID: personID, context: modelContext) ? "Remove Watch favorite" : "Add Watch favorite"
    }

    @ViewBuilder
    private func memorySection(_ person: Person) -> some View {
        let linked = MemoryQueries.forPerson(person.id, in: memories)
        let photos = MemoryQueries.photos(for: person.id, in: memories)
        Section {
            NavigationLink {
                LifeTimelineView(personID: person.id)
            } label: {
                Label("Life Timeline", systemImage: "calendar")
            }
            NavigationLink {
                PersonGalleryView(personID: person.id)
            } label: {
                Label(photos.isEmpty && person.photoMediaID == nil ? LocalizedStringKey("Gallery") : LocalizedStringKey("Gallery · \(photos.count + (person.photoMediaID == nil ? 0 : 1))"), systemImage: "photo.on.rectangle")
            }
            if linked.isEmpty {
                Text("No memories yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(linked.prefix(4))) { memory in
                    NavigationLink {
                        MemoryDetailView(memoryID: memory.id)
                    } label: {
                        MemoryRowView(memory: memory)
                    }
                }
            }
            NavigationLink {
                MemoriesListView(personID: person.id)
            } label: {
                Label("All memories", systemImage: "waveform")
            }
        } header: {
            Text("Memories")
        }
    }

    private func placeSubtitle(_ link: PersonPlace) -> String {
        var parts = [link.role.displayName]
        let years = PlaceYears.format(from: link.yearFrom, to: link.yearTo)
        if !years.isEmpty { parts.append(years) }
        return parts.joined(separator: " · ")
    }

    private func detailRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func relativesSection(_ person: Person) -> some View {
        let groups = RelativeGroups.build(
            person: person,
            allPeople: people,
            relationships: relationships,
            graph: session.graph
        )
        Section {
            if groups.isEmpty {
                Text("No relationships yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    ForEach(group.rows) { row in
                        NavigationLink {
                            PersonProfileView(personID: row.personID)
                        } label: {
                            if let relative = row.person {
                                PersonRowView(person: relative, subtitle: group.title)
                            } else {
                                Text(row.fallbackName ?? group.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if let relationship = row.relationship {
                                Button("Remove", role: .destructive) {
                                    session.deleteRelationship(relationship, context: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            Button {
                showAddRelationship = true
            } label: {
                Label("Add relationship", systemImage: "plus")
            }
        } header: {
            Text("Relatives")
        }
    }
}

private struct RelativeGroups {
    struct Group: Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    struct Row: Identifiable {
        var id: UUID { personID }
        let personID: UUID
        let person: Person?
        let relationship: KinRelationship?
        let fallbackName: String?
    }

    static func build(
        person: Person,
        allPeople: [Person],
        relationships: [KinRelationship],
        graph: RelationshipGraph
    ) -> [Group] {
        let peopleByID = Dictionary(uniqueKeysWithValues: allPeople.map { ($0.id, $0) })
        let parentKinds: Set<KinRelationshipKind> = [.parent, .adoptiveParent, .stepParent]

        func edge(from: UUID, to: UUID, kinds: Set<KinRelationshipKind>) -> KinRelationship? {
            relationships.first { rel in
                kinds.contains(rel.kind)
                    && rel.fromPerson?.id == from
                    && rel.toPerson?.id == to
            }
        }

        func coupleEdge(a: UUID, b: UUID, kind: KinRelationshipKind) -> KinRelationship? {
            relationships.first { rel in
                rel.kind == kind && (
                    (rel.fromPerson?.id == a && rel.toPerson?.id == b)
                        || (rel.fromPerson?.id == b && rel.toPerson?.id == a)
                )
            }
        }

        func rows(for nodes: [PersonNode], title: String, relationship: (PersonNode) -> KinRelationship?) -> Group? {
            let items: [Row] = graph.sortedByBirth(nodes).map { node in
                Row(
                    personID: node.id,
                    person: peopleByID[node.id],
                    relationship: relationship(node),
                    fallbackName: node.displayName
                )
            }
            guard !items.isEmpty else { return nil }
            return Group(title: title, rows: items)
        }

        var groups: [Group] = []
        if let g = rows(for: graph.parents(of: person.id), title: HeritageLocale.string("Parents"), relationship: { node in
            parentKinds.compactMap { kind in edge(from: node.id, to: person.id, kinds: [kind]) }.first
        }) { groups.append(g) }

        if let g = rows(for: graph.siblings(of: person.id), title: HeritageLocale.string("Siblings"), relationship: { _ in nil }) {
            groups.append(g)
        }

        let spouses = graph.spousesAndPartners(of: person.id).filter { graph.hop(from: person.id, to: $0.id) == .spouse }
        if let g = rows(for: spouses, title: HeritageLocale.string("Spouse"), relationship: { node in
            coupleEdge(a: person.id, b: node.id, kind: .spouse)
        }) { groups.append(g) }

        let partners = graph.spousesAndPartners(of: person.id).filter { graph.hop(from: person.id, to: $0.id) == .partner }
        if let g = rows(for: partners, title: HeritageLocale.string("Partner"), relationship: { node in
            coupleEdge(a: person.id, b: node.id, kind: .partner)
        }) { groups.append(g) }

        if let g = rows(for: graph.children(of: person.id), title: HeritageLocale.string("Children"), relationship: { node in
            parentKinds.compactMap { kind in edge(from: person.id, to: node.id, kinds: [kind]) }.first
        }) { groups.append(g) }

        return groups
    }
}
