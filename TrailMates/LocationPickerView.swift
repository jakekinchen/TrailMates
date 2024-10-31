import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 30.26613, // Austin coordinates
            longitude: -97.75543
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.05,
            longitudeDelta: 0.05
        )
    )
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedMapItem: MKMapItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map
                Map(coordinateRegion: $region, 
                    interactionModes: .all,
                    showsUserLocation: true,
                    annotationItems: searchResults.isEmpty ? [] : [searchResults[0]]) { item in
                    MapMarker(coordinate: item.placemark.coordinate)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Center indicator
                Image(systemName: "plus")
                    .foregroundColor(Color("pine"))
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                    )
                
                // Search bar and results
                VStack {
                    // Search bar
                    HStack {
                        TextField("Search location", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .onChange(of: searchText) { _, newValue in
                                searchLocation(query: newValue)
                            }
                    }
                    .padding(.top)
                    .background(Color("beige"))
                    
                    // Search results
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectLocation(item)
                                    }) {
                                        VStack(alignment: .leading) {
                                            Text(item.name ?? "Unknown Location")
                                                .foregroundColor(Color("pine"))
                                            if let addr = item.placemark.title {
                                                Text(addr)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                    }
                                    Divider()
                                }
                            }
                            .background(Color("beige"))
                        }
                        .background(Color("beige"))
                        .frame(maxHeight: 200)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("pine"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        selectedLocation = region.center
                        dismiss()
                    }
                    .foregroundColor(Color("pine"))
                }
            }
        }
    }
    
    private func searchLocation(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            searchResults = response.mapItems
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedMapItem = item
        region.center = item.placemark.coordinate
        searchText = item.name ?? ""
        searchResults = []
    }
}

struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerView(selectedLocation: .constant(nil))
    }
}