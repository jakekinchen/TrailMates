//
//  CustomPin.swift
//  TrailMates
//
//  A custom map pin component with dragging animation support.
//
//  Usage:
//  ```swift
//  @State private var isDragging = false
//  CustomPin(isSelected: true, isDragging: $isDragging)
//  ```

import SwiftUI
import MapKit

/// A custom pin marker for map annotations with drag animation
struct CustomPin: View {
    /// Whether the pin is currently selected
    let isSelected: Bool
    /// Binding to track dragging state
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

// MARK: - Previews
#Preview("Normal State") {
    struct PreviewWrapper: View {
        @State private var isDragging = false
        var body: some View {
            CustomPin(isSelected: false, isDragging: $isDragging)
        }
    }
    return PreviewWrapper()
}

#Preview("Dragging State") {
    struct PreviewWrapper: View {
        @State private var isDragging = true
        var body: some View {
            CustomPin(isSelected: true, isDragging: $isDragging)
        }
    }
    return PreviewWrapper()
}

#Preview("Interactive") {
    struct PreviewWrapper: View {
        @State private var isDragging = false
        var body: some View {
            VStack(spacing: 40) {
                CustomPin(isSelected: false, isDragging: $isDragging)

                Toggle("Dragging", isOn: $isDragging)
                    .padding(.horizontal, 40)
            }
        }
    }
    return PreviewWrapper()
}
