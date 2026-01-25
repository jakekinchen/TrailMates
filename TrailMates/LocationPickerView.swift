// LocationPickerView.swift

import SwiftUI
import MapKit
import os.log

// MARK: - Location Selection Model
struct LocationSelection: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let isRecommended: Bool
    
    static func == (lhs: LocationSelection, rhs: LocationSelection) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name
    }
    
    static func fromLocationItem(_ item: LocationItem) -> LocationSelection {
        LocationSelection(
            coordinate: item.coordinate,
            name: item.title,
            isRecommended: true
        )
    }
}

// MARK: - Map Item Wrapper
struct MapItemWrapper: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    
    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
    
    var name: String {
        mapItem.name ?? "Unknown Location"
    }
    
    var address: String? {
        mapItem.placemark.title
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: LocationSelection?
    @StateObject private var viewModel: LocationPickerViewModel
    
    init(selectedLocation: Binding<LocationSelection?>) {
        self._selectedLocation = selectedLocation
        self._viewModel = StateObject(
            wrappedValue: LocationPickerViewModel(initialLocation: selectedLocation.wrappedValue)
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                UnifiedMapView(
                    mapView: $viewModel.mapView,
                    configuration: MapConfiguration(
                        showUserLocation: true,
                        showRecommendedLocations: true,
                        isLocationPickerEnabled: true,
                        showCustomPin: $viewModel.showCustomPin,
                        isDragging: $viewModel.isDragging,
                        onLocationSelected: viewModel.selectRecommendedLocation,
                        onRegionChanged: { region in
                            viewModel.handleMapRegionChange(region)
                            if viewModel.showCustomPin {
                                Task {
                                    await viewModel.updateCustomLocation(for: region.center)
                                }
                            }
                        }
                    )
                )
                .ignoresSafeArea(edges: .bottom)
                
                if viewModel.showCustomPin {
                    CustomPin(isSelected: false, isDragging: $viewModel.isDragging)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack {
                    Menu {
                        ForEach(Locations.items, id: \.title) { item in
                            Button(item.title) {
                                viewModel.selectRecommendedLocation(item)
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.menuLabel)
                                .foregroundColor(Color("pine"))
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("pine"))
                        }
                        .padding()
                        .background(Color("beige"))
                        .cornerRadius(10)
                    }
                    .padding()
                    
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
                        if let location = viewModel.showCustomPin ? viewModel.currentCustomLocation : viewModel.selectedLocation {
                            selectedLocation = location
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(100))
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(Color("pine"))
                    .disabled(viewModel.showCustomPin ? viewModel.currentCustomLocation == nil : viewModel.selectedLocation == nil)
                }
            }
        }
        .onDisappear {
            viewModel.mapView?.removeFromSuperview()
            viewModel.mapView = nil
        }
    }
}

// MARK: - Coordinate Extensions
extension CLLocationCoordinate2D {
    var stringRepresentation: String {
        return "\(latitude), \(longitude)"
    }
}

extension Event {
    func getLocationName() -> String {
        let recommendedLocation = Locations.items.first {
            abs($0.coordinate.latitude - location.latitude) < 0.0001 &&
            abs($0.coordinate.longitude - location.longitude) < 0.0001
        }
        
        if let recommended = recommendedLocation {
            return recommended.title
        }
        
        return "Custom Location (\(location.stringRepresentation))"
    }
}
