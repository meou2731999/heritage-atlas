import HeritageAtlasCore
import SwiftData
import SwiftUI

struct PersonPlaceEditorView: View {
    var person: Person?
    var place: Place?
    var existing: PersonPlace?

    @Environment(FamilySession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]

    @State private var selectedPersonID: UUID?
    @State private var selectedPlaceID: UUID?
    @State private var role: PlaceRole = .home
    @State private var yearFromText = ""
    @State private var yearToText = ""
    @State private var pickingPerson = false
    @State private var pickingPlace = false
    @State private var creatingPlace = false
    @State private var didLoad = false

    private var selectedPerson: Person? {
        let id = selectedPersonID ?? person?.id ?? existing?.person?.id
        return people.first { $0.id == id }
    }

    private var selectedPlace: Place? {
        let id = selectedPlaceID ?? place?.id ?? existing?.place?.id
        return places.first { $0.id == id }
    }

    private var canSave: Bool {
        selectedPerson != nil && selectedPlace != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    Button {
                        pickingPerson = true
                    } label: {
                        HStack {
                            Text("Person")
                            Spacer()
                            Text(selectedPerson?.displayName ?? "Choose")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(person != nil && existing == nil)
                }

                Section("Place") {
                    Button {
                        pickingPlace = true
                    } label: {
                        HStack {
                            Text("Place")
                            Spacer()
                            Text(selectedPlace?.name ?? "Choose")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(place != nil && existing == nil)
                    Button("New place") {
                        creatingPlace = true
                    }
                }

                Section("Role") {
                    Picker("Role", selection: $role) {
                        ForEach(PlaceRole.allCases, id: \.self) { value in
                            Label(value.displayName, systemImage: value.systemImageName).tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Years") {
                    TextField("From (year)", text: $yearFromText)
                        .keyboardType(.numberPad)
                    TextField("To (year)", text: $yearToText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(existing == nil ? "Link place" : "Edit link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: populateIfNeeded)
            .sheet(isPresented: $pickingPerson) {
                PersonPickerSheet(title: "Person") { person in
                    selectedPersonID = person?.id
                }
            }
            .sheet(isPresented: $pickingPlace) {
                PlacePickerSheet { place in
                    selectedPlaceID = place.id
                }
            }
            .sheet(isPresented: $creatingPlace) {
                PlaceEditorView(placeID: nil)
            }
        }
    }

    private func populateIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        selectedPersonID = existing?.person?.id ?? person?.id
        selectedPlaceID = existing?.place?.id ?? place?.id
        role = existing?.role ?? .home
        if let year = existing?.yearFrom { yearFromText = String(year) }
        if let year = existing?.yearTo { yearToText = String(year) }
    }

    private func save() {
        guard let selectedPerson, let selectedPlace else { return }
        session.savePersonPlace(
            existing: existing,
            person: selectedPerson,
            place: selectedPlace,
            role: role,
            yearFrom: Int(yearFromText.trimmingCharacters(in: .whitespacesAndNewlines)),
            yearTo: Int(yearToText.trimmingCharacters(in: .whitespacesAndNewlines)),
            context: modelContext
        )
        dismiss()
    }
}

struct PlacePickerSheet: View {
    var excludedIDs: Set<UUID> = []
    var onSelect: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Place.name) private var places: [Place]
    @State private var query = ""

    private var filtered: [Place] {
        places.filter { place in
            if excludedIDs.contains(place.id) { return false }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if needle.isEmpty { return true }
            return place.name.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView("No places", systemImage: "mappin.slash")
                } else {
                    ForEach(filtered) { place in
                        Button {
                            onSelect(place)
                            dismiss()
                        } label: {
                            PlaceRowView(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "Place name")
            .navigationTitle("Choose place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
