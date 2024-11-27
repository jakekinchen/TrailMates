import SwiftUI
import MapKit
import UIKit

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var eventViewModel: EventViewModel
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var eventType: Event.EventType = .walk
    @State private var isPublic = true
    @State private var showLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var difficulty = 1
    @State private var duration = 60 // minutes
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedLocationInfo: LocationSelection?
    @FocusState private var focusedField: Field?
    @FocusState private var dateFieldIsFocused: Bool

    enum Field: Hashable {
        case title
        case description
        case customTag
        case date
    }
    
    let user: User
    let availableTags = ["Casual", "Fast-Paced", "Scenic", "Training", "Social", "Nature", "Urban"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Event Details").foregroundColor(Color("pine"))) {
                    TextField("Title", text: $title)
                        .foregroundColor(Color("pine"))
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }
                    
                    TextField("Description", text: $description)
                        .foregroundColor(Color("pine"))
                        .focused($focusedField, equals: .description)
                        .submitLabel(.next)
                        .onSubmit {
                           // dateFieldIsFocused = true
                        }
                    
                    FocusableDatePicker(
                        title: "Date & Time",
                        date: $date,
                        minuteInterval: 15
                    )
                    .onChange(of: date) {
                        dateFieldIsFocused = false
                    }
                    
                    Picker("Event Type", selection: $eventType) {
                        Text("Walk").tag(Event.EventType.walk)
                        Text("Run").tag(Event.EventType.run)
                        Text("Bike").tag(Event.EventType.bike)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Location").foregroundColor(Color("pine"))) {
                    LocationSectionView(
                        selectedLocationInfo: $selectedLocationInfo,
                        onTap: handleLocationSelection
                    )
                    .contentShape(Rectangle())
                }
                
                Section(header: Text("Tags").foregroundColor(Color("pine"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(availableTags, id: \.self) { tag in
                                TagButton(
                                    title: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add custom tag", text: $customTag)
                            .focused($focusedField, equals: .customTag)
                            .submitLabel(.done)
                            .onSubmit {
                                addCustomTag()
                            }
                        Button("Add") {
                            addCustomTag()
                        }
                        .disabled(customTag.isEmpty)
                    }
                }
                
                Section(header: Text("Privacy").foregroundColor(Color("pine"))) {
                    Toggle("Public Event", isOn: Binding(
                        get: { !isPublic },
                        set: { isPublic = !$0 }
                    ))
                    .tint(Color("pine"))
                }
                
                Section {
                    Button(action: createEvent) {
                        Text("Create Event")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color("alwaysBeige"))
                            .fontWeight(.semibold)
                    }
                    .listRowBackground(Color("pumpkin"))
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("pine"))
                }
            }
            .onTapGesture {
                focusedField = nil
                dateFieldIsFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(selectedLocation: $selectedLocationInfo)
                .transition(.opacity)
                .animation(.easeInOut, value: showLocationPicker)
                .onDisappear {
                    print("📍 LocationPickerView disappeared with location: \(String(describing: selectedLocationInfo))")
                }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedLocationInfo) { oldValue, newValue in
            print("📍 CreateEventView: Location changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
        }
    }

    
    private func addCustomTag() {
            if !customTag.isEmpty {
                selectedTags.insert(customTag)
                customTag = ""
                DispatchQueue.main.async {
                    focusedField = nil
                }
            }
        }
        
    
    private func createEvent() {
            guard validateInput() else { return }
            
            guard let locationInfo = selectedLocationInfo else {
                alertMessage = "Please select a location"
                showAlert = true
                return
            }
            
            // Create the event asynchronously using Task
            Task {
                try await eventViewModel.createEvent(
                    for: user,
                    title: title,
                    description: description,
                    location: locationInfo.coordinate,
                    date: date,
                    isPublic: isPublic,
                    eventType: eventType,
                    tags: Array(selectedTags)
                )
                
                // Dismiss the view on the main thread
                await MainActor.run {
                    dismiss()
                }
            }
        }
    
    private func validateInput() -> Bool {
        if title.isEmpty {
            alertMessage = "Please enter a title"
            showAlert = true
            return false
        }
        
        return true
    }
    
    private func handleLocationSelection() {
        DispatchQueue.main.async {
            showLocationPicker = true
            print(" Location picker presented with current location: \(String(describing: selectedLocationInfo))")
        }
    }
    
}

struct IntervalDatePicker: UIViewRepresentable {
    @Binding var date: Date
    let minuteInterval: Int
    let title: String
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = minuteInterval
        picker.minimumDate = Date()
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = date
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }
    
    class Coordinator: NSObject {
        let date: Binding<Date>
        
        init(date: Binding<Date>) {
            self.date = date
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            date.wrappedValue = sender.date
        }
    }
}

struct FocusableDatePicker: View {
    let title: String
    @Binding var date: Date
    let minuteInterval: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            IntervalDatePicker(date: $date, minuteInterval: 15, title: "Date & Time")
        }
    }
}

struct LocationSectionView: View {
    @Binding var selectedLocationInfo: LocationSelection?
    let onTap: () -> Void
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude.isFinite && 
               coordinate.longitude.isFinite &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    var body: some View {
        Button(action: onTap) {  // Change to Button instead of using onTapGesture
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedLocationInfo?.name ?? "Select Location")
                        .foregroundColor(selectedLocationInfo == nil ? .gray : Color("pine"))
                        .onAppear {
                            print("📍 LocationSectionView appeared with location: \(String(describing: selectedLocationInfo))")
                        }
                    
                    if let location = selectedLocationInfo {
                        Text("Lat: \(String(format: "%.4f", location.coordinate.latitude)), Long: \(String(format: "%.4f", location.coordinate.longitude))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if let location = selectedLocationInfo,
                   isValidCoordinate(location.coordinate) {
                    Map(position: .constant(MapCameraPosition.region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))), interactionModes: []) {
                        Marker("", coordinate: location.coordinate)
                            .tint(Color("pine"))
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .disabled(true)
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color("pine"))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())  // This ensures the button doesn't have default styling
    }
}

// Update LocationPickerView to handle custom location names
extension LocationPickerView {
    private func getLocationName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let name = placemark.name {
                    components.append(name)
                }
                if let thoroughfare = placemark.thoroughfare {
                    components.append(thoroughfare)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }
                
                return components.isEmpty ? "Selected Location" : components.joined(separator: ", ")
            }
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
        }
        
        return "Selected Location"
    }
    
    private func selectCustomLocation(at coordinate: CLLocationCoordinate2D) {
        Task {
            let locationName = await getLocationName(for: coordinate)
            await MainActor.run {
                selectedLocation = LocationSelection(
                    coordinate: coordinate,
                    name: locationName,
                    isRecommended: false
                )
            }
        }
    }
}

struct DatePickerWrapper: View {
    @Binding var date: Date
    // add minuteInterval
    
        
        var body: some View {
            DatePicker(
                "Date & Time",
                selection: $date,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .ignoresSafeArea(.keyboard)
            .contentShape(Rectangle())
        }
    }

struct TagButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color("pine") : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? Color("beige") : Color("pine"))
                .cornerRadius(16)
        }
    }
}
