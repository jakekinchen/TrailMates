import SwiftUI
import MapKit

struct MapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.26613, longitude: -97.75543), // Austin, TX coordinates
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var showFriendsList = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                Marker("Austin", coordinate: CLLocationCoordinate2D(latitude: 30.26613, longitude: -97.75543))
                    .tint(.green)
            }
            .edgesIgnoringSafeArea(.all)
            
            // Green overlay for trail areas (currently disabled)
            // Uncomment and modify as needed when ready to implement
            /*
            Path { path in
                path.addRect(CGRect(x: 0, y: UIScreen.main.bounds.height * 0.6, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.2))
            }
            .fill(Color.green.opacity(0.3))
            */
            
            // Friend's location pin
            Image("friendProfilePic") // Replace with actual image name
                .resizable()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
                .position(x: UIScreen.main.bounds.width * 0.6, y: UIScreen.main.bounds.height * 0.4)
            
            VStack {
                HStack {
                    Text("TrailMates")
                        .font(.custom("MagicRetro", size: 24))
                        .foregroundColor(Color("pine"))
                    Spacer()
                    Image(systemName: "bell")
                        .foregroundColor(Color("pine"))
                }
                .padding()
                .background(Color("beige").opacity(0.9))
                
                Spacer()
                
                // Friends list card
                VStack {
                    HStack {
                        Text("Friends")
                            .font(.headline)
                            .foregroundColor(Color("pine"))
                        Spacer()
                        Button(action: {
                            // Action to add friends
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(Color("pine"))
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Active")
                            .foregroundColor(Color("pine"))
                        Spacer()
                        Text("1")
                            .foregroundColor(.purple)
                    }
                    
                    HStack {
                        Image("friendProfilePic") // Replace with actual image name
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text("Collin Nelson")
                                .foregroundColor(Color("pine"))
                            Text("Now")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Inactive")
                            .foregroundColor(Color("pine"))
                        Spacer()
                    }
                    
                    HStack {
                        Image("nancyProfilePic") // Replace with actual image name
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        Text("Nancy Melancon")
                            .foregroundColor(Color("pine"))
                        Spacer()
                    }
                }
                .padding()
                .background(Color("beige").opacity(0.9))
                .cornerRadius(15)
                .padding()
            }
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}