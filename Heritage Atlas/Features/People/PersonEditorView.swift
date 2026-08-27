import HeritageAtlasCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum PersonEditorMode: Identifiable, Hashable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let id): id.uuidString
        }
    }
}

struct PersonEditorView: View {
    let mode: PersonEditorMode
    var onSaved: ((UUID) -> Void)?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]
    @Query private var settingsRows: [AppSettings]

    @State private var draft = PersonDraft()
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var didLoadExisting = false

    init(mode: PersonEditorMode, onSaved: ((UUID) -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create:
            _people = Query(sort: \Person.fullName)
        case .edit(let id):
            let personID = id
            _people = Query(filter: #Predicate<Person> { $0.id == personID })
        }
    }

    private var existing: Person? {
        if case .edit = mode { return people.first }
        return nil
    }

    private var willBecomeMe: Bool {
        if case .create = mode {
            return settingsRows.first?.mePersonID == nil
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        photoControl
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Identity") {
                    TextField("Full name", text: $draft.fullName)
                    TextField("Nickname", text: $draft.nickname)
                    Picker("Gender", selection: $draft.gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                }

                Section("Dates") {
                    Toggle("Birth date", isOn: $draft.hasBirthDate)
                    if draft.hasBirthDate {
                        DatePicker("Born", selection: $draft.birthDate, displayedComponents: .date)
                    }
                    Toggle("Death date", isOn: $draft.hasDeathDate)
                    if draft.hasDeathDate {
                        DatePicker("Died", selection: $draft.deathDate, displayedComponents: .date)
                    }
                }

                Section("About") {
                    TextField("Occupation", text: $draft.occupation)
                    TextField("Tags (comma-separated)", text: $draft.tagsText)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(4...10)
                }

                if willBecomeMe {
                    Section {
                        Text("This first person will be set as Me in Settings. You can change that later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode == .create ? "New person" : "Edit person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!draft.isValid || isSaving)
                }
            }
            .onAppear(perform: populateIfNeeded)
            .onChange(of: existing?.id) { _, _ in
                populateIfNeeded()
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPickerItem(item) }
            }
        }
    }

    private var photoControl: some View {
        VStack(spacing: 10) {
            Group {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else if let existing {
                    PersonAvatarView(person: existing, size: 96)
                } else {
                    PersonAvatarView(
                        name: draft.fullName.isEmpty ? "New" : draft.fullName,
                        gender: draft.gender,
                        size: 96
                    )
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(previewImage == nil && existing?.photoMediaID == nil ? "Add photo" : "Change photo")
            }
            if previewImage != nil || existing?.photoMediaID != nil {
                Button("Remove photo", role: .destructive) {
                    draft.photoData = nil
                    draft.removePhoto = true
                    previewImage = nil
                    pickerItem = nil
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 8)
    }

    private func populateIfNeeded() {
        guard !didLoadExisting, let existing else { return }
        draft = PersonDraft(person: existing)
        didLoadExisting = true
        Task { await loadExistingPhoto(existing) }
    }

    private func loadExistingPhoto(_ person: Person) async {
        guard let mediaID = person.photoMediaID,
              let data = await session.photoData(for: mediaID) else { return }
        previewImage = UIImage(data: data)
    }

    private func loadPickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let compressed = Self.compressPhoto(data)
        draft.photoData = compressed
        draft.removePhoto = false
        if let compressed {
            previewImage = UIImage(data: compressed)
        }
    }

    private static func compressPhoto(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 1400, height: 1400)) ?? image
        return thumbnail.jpegData(compressionQuality: 0.82) ?? data
    }

    private func save() async {
        isSaving = true
        let id = await session.savePerson(existing: existing, draft: draft, context: modelContext)
        isSaving = false
        if let id {
            onSaved?(id)
            dismiss()
        }
    }
}
