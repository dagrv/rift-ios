import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import Combine

struct NewTransactionView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @State private var isExpense = true
    @State private var amountString = ""
    @State private var title = ""
    @State private var category = "Other"
    @State private var date = Date()
    @State private var note = ""

    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    @State private var tags: [String] = []
    @State private var tagInput = ""

    @State private var locationName = ""
    @State private var locationAddress = ""
    @State private var locationLatitude: Double = 0.0
    @State private var locationLongitude: Double = 0.0
    @State private var showLocationPicker = false

    private var categories: [String] {
        isExpense ? CategoryData.expenseCategories : CategoryData.incomeCategories
    }

    private var amount: Double { Double(amountString) ?? 0 }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                amountSection
                detailsSection
                tagSection
                locationSection
                photoSection
                noteSection
            }
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: isExpense) {
                category = categories.first ?? "Other"
            }
            .onChange(of: photoItem) {
                Task {
                    if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedImage = UIImage(data: data)
                        }
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(image: $selectedImage).ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet(
                    locationName: $locationName,
                    locationAddress: $locationAddress,
                    locationLatitude: $locationLatitude,
                    locationLongitude: $locationLongitude
                )
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $isExpense) {
                Text("Expense").tag(true)
                Text("Income").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var currencySymbol: String {
        switch currencyCode {
        case "EUR": return "€"
        case "JPY": return "¥"
        default:    return "$"
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                if currencyCode != "EUR" {
                    Text(currencySymbol)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                }
                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundStyle(isExpense ? .red : .green)
                if currencyCode == "EUR" {
                    Text(currencySymbol)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }
            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
        }
    }

    private var tagSection: some View {
        Section("Tags") {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)")
                                    .font(.subheadline).fontWeight(.medium)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.primary)
                    .font(.subheadline)
                TextField("Add tag…", text: $tagInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { addTag() }
                    .submitLabel(.done)
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        tagInput = ""
    }

    private var photoSection: some View {
        Section("Photo") {
            if let image = selectedImage {
                HStack(spacing: 14) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Photo attached")
                        .font(.subheadline)
                    Spacer()
                    Button(role: .destructive) {
                        selectedImage = nil
                        photoItem = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showPhotoSourceDialog = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, .primary)
                            .font(.system(size: 22))
                        Text("Add Photo")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Location (optional)") {
            if !locationName.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "map.circle.fill")
                        .foregroundStyle(.primary)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locationName)
                            .font(.subheadline).fontWeight(.medium)
                        if !locationAddress.isEmpty {
                            Text(locationAddress)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) {
                        locationName = ""
                        locationAddress = ""
                        locationLatitude = 0
                        locationLongitude = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showLocationPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, .primary)
                            .font(.system(size: 22))
                        Text("Add Location")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("Add a note…", text: $note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Actions

    private func save() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        let transaction = Transaction(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            date: date,
            isExpense: isExpense,
            note: note,
            imageData: imageData,
            tags: tags,
            locationName: locationName,
            locationAddress: locationAddress,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude
        )
        // Navigate to Overview first so the balance animation plays on-screen
        NotificationCenter.default.post(name: .switchToOverview, object: nil)
        resetForm()
        // Insert after the tab switch settles so SwiftData triggers the visible balance update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            modelContext.insert(transaction)
        }
    }

    private func resetForm() {
        title = ""
        amountString = ""
        note = ""
        date = Date()
        category = categories.first ?? "Other"
        selectedImage = nil
        photoItem = nil
        tags = []
        tagInput = ""
        locationName = ""
        locationAddress = ""
        locationLatitude = 0.0
        locationLongitude = 0.0
    }
}

// MARK: - Location Search Completer (real-time typeahead via MKLocalSearchCompleter)

final class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { suggestions = [] }
        completer.queryFragment = trimmed
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    @Binding var locationName: String
    @Binding var locationAddress: String
    @Binding var locationLatitude: Double
    @Binding var locationLongitude: Double

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = LocationSearchCompleter()
    @State private var searchText = ""
    @State private var selectedItem: MKMapItem? = nil
    @State private var isResolving = false
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var selectedAddressString: String = ""
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {

                    // ── Map — 60% ─────────────────────────────────────────
                    Map(position: $cameraPosition) {
                        if let item = selectedItem, let coord = selectedCoordinate {
                            Marker(item.name ?? "Location", coordinate: coord)
                                .tint(.red)
                        }
                    }
                    .frame(height: geo.size.height * 0.60)

                    // ── Search bar ────────────────────────────────────────
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15, weight: .medium))
                        TextField("Search place or address…", text: $searchText)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, q in
                                completer.update(query: q)
                            }
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 11))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // ── Results / selected / idle (40%) ───────────────────
                    Group {
                        if isResolving {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                        } else if !completer.suggestions.isEmpty {
                            List(completer.suggestions, id: \.self) { suggestion in
                                Button { resolveSuggestion(suggestion) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.system(size: 20))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.subheadline).fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                            .listStyle(.plain)

                        } else if let item = selectedItem {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.13))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name ?? "Selected location")
                                        .font(.subheadline).fontWeight(.semibold)
                                    if !selectedAddressString.isEmpty {
                                        Text(selectedAddressString)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button { selectedItem = nil; selectedCoordinate = nil; selectedAddressString = ""; searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.green.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                            Spacer()

                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: searchText.isEmpty
                                      ? "mappin.and.ellipse" : "mappin.slash")
                                    .font(.system(size: 26)).foregroundStyle(.secondary)
                                Text(searchText.isEmpty
                                     ? "Search for a place or address above"
                                     : "No results — try a different term")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    // ── Buttons ───────────────────────────────────────────
                    Divider()
                    HStack(spacing: 12) {
                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.subheadline).fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color(.systemFill),
                                            in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.primary)
                        }
                        Button {
                            guard let item = selectedItem else { return }
                            locationName      = item.name ?? ""
                            locationAddress   = selectedAddressString
                            locationLatitude  = selectedCoordinate?.latitude ?? 0
                            locationLongitude = selectedCoordinate?.longitude ?? 0
                            dismiss()
                        } label: {
                            Text("Confirm")
                                .font(.subheadline).fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    selectedItem != nil
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.18),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .foregroundStyle(
                                    selectedItem != nil ? Color.white : Color.secondary
                                )
                        }
                        .disabled(selectedItem == nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.background)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    /// Resolve an autocomplete suggestion → full MKMapItem with coordinates.
    /// The suggestion already carries a formatted address in its subtitle — no need
    /// to touch MKMapItem.placemark (deprecated in iOS 26) or MKAddressRepresentations.
    private func resolveSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isResolving = true
        completer.suggestions = []
        let address = suggestion.subtitle.isEmpty ? suggestion.title : suggestion.subtitle
        let request = MKLocalSearch.Request(completion: suggestion)
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isResolving = false
                if let item = response?.mapItems.first {
                    selectItem(item, address: address)
                }
            }
        }
    }

    private func selectItem(_ item: MKMapItem, address: String = "") {
        let coord = item.location.coordinate
        selectedItem = item
        selectedCoordinate = coord
        selectedAddressString = address.isEmpty ? (item.name ?? "") : address
        searchText = ""
        withAnimation(.spring(response: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            ))
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let switchToOverview = Notification.Name("switchToOverview")
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NewTransactionView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
