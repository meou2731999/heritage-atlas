import HeritageAtlasCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(FamilySession.self) private var session
    @Environment(DeviceLocationSession.self) private var location
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query private var settingsRows: [AppSettings]
    @Query private var memories: [Memory]
    @Query private var walks: [FamilyWalk]
    @Query private var events: [TimelineEvent]

    @State private var path = NavigationPath()
    @State private var editorMode: PersonEditorMode?

    private var settings: AppSettings? { settingsRows.first }
    private var me: Person? {
        guard let meID = settings?.mePersonID else { return nil }
        return people.first { $0.id == meID }
    }

    private var generationCount: Int {
        FamilyMetrics.generationCount(in: session.graph)
    }

    private var recents: [Person] {
        let ids = settings?.recentPersonIDs ?? []
        return ids.compactMap { id in people.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    familyCard
                    if recents.isEmpty == false {
                        recentsSection
                    }
                    nearbySection
                    watchInboxSection
                    memoriesToHearSection
                    discoverSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Heritage Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add person")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PersonProfileView(personID: id)
            }
            .sheet(item: $editorMode) { mode in
                PersonEditorView(mode: mode)
            }
            .onAppear {
                if location.isAuthorized {
                    location.start(heading: false)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Greeting.text())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let me {
                Text(me.displayName)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(2)
            } else {
                Text("Your family")
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(2)
            }
            if me == nil, people.isEmpty {
                Text("Add someone to begin. The first person can be you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var familyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(familySummary)
                .font(.title3.weight(.semibold))
            Group {
                if people.isEmpty {
                    Text("No one in the tree yet.")
                } else {
                    Text("Explore the family tree, search names, or look up how two people are related.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                session.exploreFamily(focus: settings?.mePersonID ?? people.first?.id)
            } label: {
                Label("Explore Family", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(people.isEmpty)

            if people.isEmpty {
                Button {
                    editorMode = .create
                } label: {
                    Label("Add a person", systemImage: "person.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var familySummary: String {
        if people.count == 1 {
            return HeritageLocale.string("Your Family · 1 person · \(generationCount) gen")
        }
        return HeritageLocale.string("Your Family · \(people.count) people · \(generationCount) gen")
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently viewed")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(recents) { person in
                    Button {
                        path.append(person.id)
                    } label: {
                        PersonRowView(
                            person: person,
                            showMeBadge: person.id == settings?.mePersonID
                        )
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if person.id != recents.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Nearby", systemImage: "location.fill")
                    .font(.headline)
                Spacer()
                Button("Map") {
                    session.openFamilyMap()
                }
                .font(.subheadline.weight(.semibold))
            }

            if geocodedPlaces.isEmpty {
                nearbyCard {
                    Text("Add family places with coordinates to see them here and on Family Map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add a place") {
                        session.openFamilyMap()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } else {
                nearbyCard {
                    locationStatus
                    ForEach(Array(nearbyRows.enumerated()), id: \.element.id) { index, row in
                        NavigationLink {
                            PlaceDetailView(placeID: row.id)
                        } label: {
                            HStack {
                                PlaceRowView(
                                    place: row.place,
                                    subtitle: row.subtitle,
                                    role: row.role
                                )
                                if let distance = row.distanceText {
                                    Text(distance)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        if index < nearbyRows.count - 1 {
                            Divider()
                        }
                    }
                    HStack {
                        Button("Family Map") { session.openFamilyMap() }
                        Spacer()
                        Button("Cemetery") { session.openCemeteryMap() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 6)
                }
            }
        }
    }

    private var locationStatus: some View {
        Group {
            if location.isDenied {
                Text("Location is off. Distances are hidden — the map still works with family places stored on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !location.isAuthorized {
                Button("Use location for nearby places") {
                    location.start(heading: false)
                }
                .font(.subheadline.weight(.semibold))
                Text("Optional. Your current location is never stored as family data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var geocodedPlaces: [Place] {
        places.filter(\.hasCoordinates)
    }

    private var nearbyRows: [NearbyPlaceRow] {
        let here = location.coordinate
        let rows: [NearbyPlaceRow] = geocodedPlaces.compactMap { place in
            guard let point = place.geoPoint else { return nil }
            let links = personPlaces.filter { $0.place?.id == place.id }
            let distance = here.map { GeoMath.distanceMeters(from: $0, to: point) }
            return NearbyPlaceRow(
                id: place.id,
                place: place,
                role: links.first?.role,
                subtitle: nearbySubtitle(links: links, distance: nil),
                distance: distance,
                distanceText: distance.map(GeoMath.formatDistanceMeters)
            )
        }
        if here != nil {
            return Array(rows.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }.prefix(5))
        }
        return Array(rows.sorted { $0.place.name.localizedStandardCompare($1.place.name) == .orderedAscending }.prefix(5))
    }

    private func nearbySubtitle(links: [PersonPlace], distance: Double?) -> String {
        let names = Array(Set(links.compactMap { $0.person?.displayName })).sorted()
        let roles = Array(Set(links.map { $0.role.displayName })).sorted()
        var parts: [String] = []
        if !roles.isEmpty { parts.append(roles.prefix(2).joined(separator: " · ")) }
        if !names.isEmpty { parts.append(names.prefix(2).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    private var unassignedWatch: [Memory] {
        MemoryQueries.unassignedWatch(in: memories)
    }

    private var hearable: [Memory] {
        Array(MemoryQueries.hearable(in: memories).prefix(5))
    }

    @ViewBuilder
    private var watchInboxSection: some View {
        if unassignedWatch.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Label("From Apple Watch", systemImage: "applewatch")
                    .font(.headline)
                VStack(spacing: 0) {
                    ForEach(Array(unassignedWatch.enumerated()), id: \.element.id) { index, memory in
                        NavigationLink {
                            MemoryDetailView(memoryID: memory.id)
                        } label: {
                            MemoryRowView(memory: memory, subtitle: HeritageLocale.string("Assign a person"))
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if index < unassignedWatch.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var memoriesToHearSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Memories to hear", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                NavigationLink("Stories") {
                    StoriesListView()
                }
                .font(.subheadline.weight(.semibold))
            }

            if hearable.isEmpty {
                nearbyCard {
                    Text("Record a story on iPhone or Apple Watch. Audio and stories show up here to play offline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        NavigationLink("Add a memory") {
                            MemoriesListView()
                        }
                        NavigationLink("Family stories") {
                            StoriesListView()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } else {
                nearbyCard {
                    ForEach(Array(hearable.enumerated()), id: \.element.id) { index, memory in
                        NavigationLink {
                            MemoryDetailView(memoryID: memory.id)
                        } label: {
                            MemoryRowView(memory: memory)
                        }
                        .buttonStyle(.plain)
                        if index < hearable.count - 1 {
                            Divider()
                        }
                    }
                    HStack {
                        NavigationLink("All memories") {
                            MemoriesListView()
                        }
                        Spacer()
                        NavigationLink("Family stories") {
                            StoriesListView()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 6)
                }
            }
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explore")
                .font(.headline)

            nearbyCard {
                if let event = upcomingEvents.first {
                    NavigationLink {
                        MemorialCalendarView()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.body.weight(.medium))
                            Text(event.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                if memoryGap.coveragePercent < 100, let prompt = memoryGap.prompts.first {
                    NavigationLink {
                        MemoryGapView()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Memory Gap · \(memoryGap.coveragePercent)%")
                                .font(.body.weight(.medium))
                            Text(prompt.question)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                NavigationLink {
                    InsightsView()
                } label: {
                    Label("Insights · \(insights.livingCount) living · \(insights.generationCount) gen", systemImage: "chart.bar")
                }
                NavigationLink {
                    FamilyWalkListView()
                } label: {
                    Label(walkLabel, systemImage: "figure.walk")
                }
                NavigationLink {
                    MemorialCalendarView()
                } label: {
                    Label("Family calendar", systemImage: "calendar")
                }
                NavigationLink {
                    ArchiveImportView()
                } label: {
                    Label("Family Archive · OCR", systemImage: "doc.text.viewfinder")
                }
            }
        }
    }

    private var insights: FamilyInsights {
        FamilyInsightsEngine.compute(
            people: people.map { $0.asNode() },
            graph: session.graph,
            mePersonID: settings?.mePersonID,
            placeCount: places.count,
            burialCount: personPlaces.filter { $0.role == .burial }.count,
            memoryCount: memories.count,
            storyCount: memories.filter { $0.kind == .story }.count
        )
    }

    private var memoryGap: MemoryGapReport {
        MemoryGapAnalyzer.report(
            people: FamilyCalendarSourceBuilder.memoryGapPeople(
                people: people,
                personPlaces: personPlaces,
                memories: memories
            ),
            locale: settings?.localeKinship ?? .en
        )
    }

    private var upcomingEvents: [FamilyCalendarEvent] {
        let source = FamilyCalendarSourceBuilder.make(
            people: people,
            personPlaces: personPlaces,
            memories: memories,
            events: events,
            locale: settings?.localeKinship ?? .en
        )
        return FamilyCalendar.upcoming(from: Date(), days: 21, in: FamilyCalendar.events(from: source))
    }

    private var walkLabel: String {
        if let currentID = settings?.currentFamilyWalkID,
           let walk = walks.first(where: { $0.id == currentID }) {
            return HeritageLocale.string("Family Walk · \(walk.title)")
        }
        if walks.isEmpty {
            return HeritageLocale.string("Family Walk")
        }
        return HeritageLocale.string("Family Walk · \(walks.count)")
    }

    private func nearbyCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NearbyPlaceRow: Identifiable {
    let id: UUID
    let place: Place
    let role: PlaceRole?
    let subtitle: String
    let distance: Double?
    let distanceText: String?
}
