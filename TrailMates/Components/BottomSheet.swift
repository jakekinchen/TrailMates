//
//  BottomSheet.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/24/24.
//

import SwiftUI

// MARK: - BottomSheet
struct BottomSheet<Content: View>: View {
    @Binding var isOpen: Bool
    let maxHeight: CGFloat
    let content: Content
    
    @GestureState private var translation: CGFloat = 0
    @State private var position: SheetPosition = .partial
    
    private enum SheetPosition {
        case full, partial, collapsed
    }
    
    private var offset: CGFloat {
        switch position {
        case .full:
            return 0
        case .partial:
            return maxHeight * 0.45 // Shows 45% of sheet
        case .collapsed:
            return maxHeight - 100 // Just above tab bar
        }
    }
    
    private var indicator: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary)
            .frame(width: 40, height: 6)
            .padding(8)
    }
    
    init(isOpen: Binding<Bool>, maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self._isOpen = isOpen
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.clear)
                    .background(
                        ZStack {
                            TransparentBlurView()
                                .blur(radius: 0)
                            
                            // Color tint overlay
                            Color("beige")
                                .opacity(0.75)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    )
                
                // Content
                VStack(spacing: 0) {
                    indicator
                    content
                }
            }
            .frame(width: geometry.size.width, height: maxHeight, alignment: .top)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(offset + translation, 0))
            .animation(.interactiveSpring(), value: position)
            .gesture(
                DragGesture()
                    .updating($translation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let snapDistance = maxHeight * 0.25
                        let verticalDirection = value.predictedEndLocation.y - value.location.y
                        
                        if abs(value.translation.height) < snapDistance {
                            if verticalDirection > 0 {
                                moveDown()
                            } else {
                                moveUp()
                            }
                        } else {
                            if value.translation.height > 0 {
                                moveDown()
                            } else {
                                moveUp()
                            }
                        }
                    }
            )
        }
    }
    
    private func moveUp() {
        switch position {
        case .collapsed:
            position = .partial
        case .partial:
            position = .full
        case .full:
            position = .full
        }
        isOpen = position == .full
    }
    
    private func moveDown() {
        switch position {
        case .full:
            position = .partial
        case .partial:
            position = .collapsed
        case .collapsed:
            position = .collapsed
        }
        isOpen = position == .full
    }
}

