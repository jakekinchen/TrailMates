import SwiftUI
import MapKit

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var eventViewModel: EventViewModel
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var eventType: Event.EventType = .walk
    @State private var isPrivate = false
    @State private var showLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let user: User
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details").foregroundColor(Color("pine"))) {
                    TextField("Title", text: $title)
                        .foregroundColor(Color("pine"))
                    
                    TextField("Description", text: $description)
                        .foregroundColor(Color("pine"))
                    
                    DatePicker("Date & Time",
                             selection: $date,
                             in: Date()...,
                             displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(Color("pine"))
                    
                    Picker("Event Type", selection: $eventType) {
                        Text("Walk").tag(Event.EventType.walk)
                        Text("Run").tag(Event.EventType.run)
                        Text("Bike").tag(Event.EventType.bike)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Location").foregroundColor(Color("pine"))) {
                    Button(action: {
                        showLocationPicker = true
                    }) {
                        HStack {
                            Text(selectedLocation == nil ? "Select Location" : "Location Selected")
                                .foregroundColor(selectedLocation == nil ? .gray : Color("pine"))
                            Spacer()
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color("pine"))
                        }
                    }
                }
                
                Section(header: Text("Privacy").foregroundColor(Color("pine"))) {
                    Toggle("Private Event", isOn: $isPrivate)
                        .tint(Color("pine"))
                }
                
                Section {
                    Button(action: createEvent) {
                        Text("Create Event")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color("beige"))
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
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(selectedLocation: $selectedLocation)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func createEvent() {
        guard validateInput() else { return }
        
        guard let location = selectedLocation else {
            alertMessage = "Please select a location"
            showAlert = true
            return
        }
        
        eventViewModel.createEvent(
            for: user,
            title: title,
            description: description,
            location: location,
            date: date,
            isPrivate: isPrivate
        )
        
        dismiss()
    }
    
    private func validateInput() -> Bool {
        if title.isEmpty {
            alertMessage = "Please enter a title"
            showAlert = true
            return false
        }
        
        if description.isEmpty {
            alertMessage = "Please enter a description"
            showAlert = true
            return false
        }
        
        return true
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.26613, longitude: -97.75543),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, interactionModes: .all) { }
                .overlay(
                    Image(systemName: "mappin")
                        .font(.title)
                        .foregroundColor(Color("pine"))
                )
                .navigationTitle("Select Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            selectedLocation = region.center
                            dismiss()
                        }
                        .foregroundColor(Color("pine"))
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(Color("pine"))
                    }
                }
        }
    }
}