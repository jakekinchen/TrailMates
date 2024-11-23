import SwiftUI
import MapKit

struct CustomPin: View {
    let isSelected: Bool
    @Binding var isDragging: Bool
    
    private let strokeLength: CGFloat = 18
    private let circleSize: CGFloat = 10
    private let topCircleSize: CGFloat = 22
    
    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color("pine"))
                .frame(width: topCircleSize, height: topCircleSize)
            
            Rectangle()
                .fill(Color("pine"))
                .frame(width: 3, height: strokeLength)
                .offset(y: isDragging ? -10 : 0)
            
            Circle()
                .fill(Color("pine").opacity(0.3))
                .frame(width: circleSize, height: circleSize)
                .opacity(isDragging ? 1 : 0)
                .scaleEffect(isDragging ? 1 : 0.5)
                .offset(y: isDragging ? -10 : 0)
        }
        .shadow(color: .black.opacity(0.2), radius: isDragging ? 4 : 0, y: isDragging ? 2 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}
