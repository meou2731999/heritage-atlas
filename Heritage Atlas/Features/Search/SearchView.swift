import HeritageAtlasCore
import SwiftData
import SwiftUI

private enum SearchDestination: Hashable {
    case person(UUID)
    case place(UUID)
    case memory(UUID)
}

struct SearchView: View {
    @Environment(FamilySession.self) private var session
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]
    @Query private var personPlaces: [PersonPlace]
    @Query private var memories: [Memory]
    @Query private var settingsRows: [AppSettings]

    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var editorMode: PersonEditorMode?

    private var locale: KinshipLocale { settingsRows.first?.localeKinship ?? .en }

    private var result: FamilySearchResult {
        FamilySearch.search(query: query, in: searchContext, locale: locale)
    }

    private var searchContext: FamilySearchContext {
        let cache = session.relationshipCache
        return FamilySearchContext(
            people: people.map { person in
                let entry = cache.entry(for: person.id)
                return FamilySearchPerson(
                    id: person.id,
                    fullName: person.fullName,
                    nickname: person.nickname,
                    occupation: person.occupation,
                    tags: person.tags,
                    kinshipTerm: entry?.naming.term,
                    youCallThem: entry?.naming.youCallThem,
                    theyCallYou: entry?.naming.theyCallYou,
                    kinshipCode: entry?.code
                )
            },
            places: places.map { FamilySearchPlace(id: $0.id, name: $0.name, notes: $0.notes) },
            links: personPlaces.compactMap { link in
                guard let personID = link.person?.id, let placeID = link.place?.id else { return nil }
                return FamilySearchLink(personID: personID, placeID: placeID, role: link.role)
            },
            memories: memories.map {
                FamilySearchMemory(id: $0.id, title: $0.title, body: $0.body, personIDs: $0.personIDs, placeIDs: $0.placeIDs)
            },
            herePlaceID: session.mapFocusPlaceID
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink {
                        RelationshipLookupView()
                    } label: {
                        Label("How are two people related?", systemImage: "arrow.left.arrow.right")
                    }
                    NavigationLink {
                        MemoriesListView()
                    } label: {
                        Label("Memories", systemImage: "waveform")
                    }
                    NavigationLink {
                        StoriesListView()
                    } label: {
                        Label("Family stories", systemImage: "book")
                    }
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("Insights", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        MemorialCalendarView()
                    } label: {
                        Label("Family calendar", systemImage: "calendar")
                    }
                    NavigationLink {
                        MemoryGapView()
                    } label: {
                        Label("Memory Gap", systemImage: "square.dashed")
                    }
                    NavigationLink {
                        FamilyWalkListView()
                    } label: {
                        Label("Family Walk", systemImage: "figure.walk")
                    }
                    NavigationLink {
                        ArchiveImportView()
                    } label: {
                        Label("Family Archive", systemImage: "doc.text.viewfinder")
                    }
                }

                if let title = result.answerTitle, result.answerHits.isEmpty == false {
                    Section(title) {
                        ForEach(result.answerHits) { hit in
                            searchRow(hit)
                        }
                    }
                }

                Section {
                    if people.isEmpty && places.isEmpty && memories.isEmpty {
                        ContentUnavailableView(
                            "Nothing to search yet",
                            systemImage: "magnifyingglass",
                            description: Text("Add people, places, or memories. Try “Huế”, “ông nội”, or “who is buried here?”")
                        )
                    } else if result.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        if result.people.isEmpty == false, result.answerTitle == nil {
                            ForEach(result.people) { hit in
                                searchRow(hit)
                            }
                        }
                    }
                } header: {
                    Text(peopleHeader)
                }

                if result.places.isEmpty == false {
                    Section("Places") {
                        ForEach(result.places) { hit in
                            searchRow(hit)
                        }
                    }
                }

                if result.memories.isEmpty == false {
                    Section("Memories") {
                        ForEach(result.memories) { hit in
                            searchRow(hit)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Name, place, Huế, ông nội…")
            .navigationTitle("Search")
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
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
                case .person(let id):
                    PersonProfileView(personID: id)
                case .place(let id):
                    PlaceDetailView(placeID: id)
                case .memory(let id):
                    MemoryDetailView(memoryID: id)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PersonProfileView(personID: id)
            }
            .sheet(item: $editorMode) { mode in
                PersonEditorView(mode: mode)
            }
        }
    }

    private var peopleHeader: String {
        if query.isEmpty { return "Everyone" }
        if result.answerTitle != nil { return "People" }
        return "Matching “\(query)”"
    }

    @ViewBuilder
    private func searchRow(_ hit: FamilySearchHit) -> some View {
        if let personID = hit.personID {
            NavigationLink(value: SearchDestination.person(personID)) {
                hitLabel(hit, systemImage: "person")
            }
        } else if let placeID = hit.placeID {
            NavigationLink(value: SearchDestination.place(placeID)) {
                hitLabel(hit, systemImage: "mappin")
            }
        } else if let memoryID = hit.memoryID {
            NavigationLink(value: SearchDestination.memory(memoryID)) {
                hitLabel(hit, systemImage: "waveform")
            }
        } else {
            hitLabel(hit, systemImage: "magnifyingglass")
        }
    }

    private func hitLabel(_ hit: FamilySearchHit, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.title)
                if hit.subtitle.isEmpty == false {
                    Text(hit.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
