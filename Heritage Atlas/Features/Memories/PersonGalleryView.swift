import HeritageAtlasCore
import SwiftData
import SwiftUI

struct PersonGalleryView: View {
    let personID: UUID

    @Query private var people: [Person]
    @Query private var memories: [Memory]

    @State private var showEditor = false

    private var person: Person? { people.first { $0.id == personID } }

    private var photos: [GalleryItem] {
        var items: [GalleryItem] = []
        if let person, let photoID = person.photoMediaID {
            items.append(GalleryItem(id: photoID, memoryID: nil, title: "Profile photo"))
        }
        for memory in MemoryQueries.photos(for: personID, in: memories) {
            if let mediaID = memory.mediaIDs.first {
                items.append(GalleryItem(id: mediaID, memoryID: memory.id, title: memory.title))
            }
        }
        return items
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "photo.on.rectangle",
                    description: Text("Add a profile photo or a photo memory for \(person?.displayName ?? "this person").")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(photos) { item in
                            if let memoryID = item.memoryID {
                                NavigationLink {
                                    MemoryDetailView(memoryID: memoryID)
                                } label: {
                                    galleryCell(item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                galleryCell(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gallery")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add photo")
            }
        }
        .sheet(isPresented: $showEditor) {
            MemoryEditorView(memoryID: nil, presetPersonID: personID, presetKind: .photo)
        }
    }

    private func galleryCell(_ item: GalleryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MediaImageView(mediaID: item.id)
                .frame(height: 140)
                .clipped()
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct GalleryItem: Identifiable {
    var id: UUID
    var memoryID: UUID?
    var title: String
}
