import HeritageAtlasCore
import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query private var settingsRows: [AppSettings]

    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var editorMode: PersonEditorMode?

    private var filtered: [Person] {
        people.filter { PersonSearch.matches($0, query: query) }
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
                }

                Section {
                    if people.isEmpty {
                        ContentUnavailableView(
                            "No people yet",
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text("Add someone to search names and nicknames.")
                        )
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        ForEach(filtered) { person in
                            NavigationLink(value: person.id) {
                                PersonRowView(
                                    person: person,
                                    showMeBadge: person.id == settingsRows.first?.mePersonID
                                )
                            }
                        }
                    }
                } header: {
                    Text(query.isEmpty ? "Everyone" : "Names matching “\(query)”")
                }
            }
            .searchable(text: $query, prompt: "Name or nickname")
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
            .navigationDestination(for: UUID.self) { id in
                PersonProfileView(personID: id)
            }
            .sheet(item: $editorMode) { mode in
                PersonEditorView(mode: mode)
            }
        }
    }
}
