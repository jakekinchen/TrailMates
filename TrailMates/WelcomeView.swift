// MARK: - WelcomeMapView.swift
// MARK: - WelcomeMapView.swift
import SwiftUI
import MapKit

// Add this struct at the top of the file
struct NonInteractiveMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isUserInteractionEnabled = false
        
        // Set initial region
        mapView.setRegion(MapConfiguration.defaultRegion, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
}

struct WelcomeView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showSignInOptions = false
    let onComplete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Map Layer
                NonInteractiveMapView()
                    .ignoresSafeArea()
                
                // Glass effect layer
                ZStack {
                    TransparentBlurView(removeAllFilters: false, tintColor: UIColor(named: "beige"))
                        .opacity(0.8)
                    
                    Color("beige")
                        .opacity(0.8)
                }
                .ignoresSafeArea()
                
                // Content Layer
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        
                        VStack(spacing: 20) {
                            Text("Welcome to the TrailMates ATX Community")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(Color("pine"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("TrailMates connects you with friends on the Town Lake Trail. Coordinate events with your friends to go walking, running, or biking!")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Color("pine").opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .allowsHitTesting(false)
                        
                        // Focused map
                        Map(position: .constant(MapCameraPosition.region(MapConfiguration.defaultRegion)), 
                            interactionModes: []) {
                            // Add any markers or overlays here if needed
                        }
                        .frame(height: 200)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 30)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        Spacer()
                        
                        Button(action: {
                            onComplete()
                        }) {
                            Text("Get Started")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("pumpkin"))
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                    }
            }
        }
    }
}
