import SwiftUI

struct ARViewScreen: View {
    var body: some View {
        ZStack {
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top bar with title
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
                
                // Additional AR controls can be added here
            }
        }
    }
}

struct ARViewScreen_Previews: PreviewProvider {
    static var previews: some View {
        ARViewScreen()
    }
}