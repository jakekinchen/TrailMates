import SwiftUI

struct PermissionCard: View {
    let title: String
    let description: String
    let iconName: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(Color("pumpkin"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("pine"))
                    
                    Spacer()
                    
                    statusIcon
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var statusIcon: some View {
        switch status {
        case .granted:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
        case .notRequested:
            return Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }
}