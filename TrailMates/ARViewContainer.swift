import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Check if AR configuration is supported
        guard ARWorldTrackingConfiguration.isSupported else {
            return arView
        }
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        // Add any AR content here
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}