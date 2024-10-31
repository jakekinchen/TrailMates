//
//  NavigationBarModifier.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/29/24.
//


import SwiftUI

// MARK: - Navigation Bar Modifier
struct NavigationBarModifier: ViewModifier {
    let title: String
    let rightButtonIcon: String?
    let rightButtonAction: (() -> Void)?
    let backgroundColor: Color = Color("beige")
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                HStack {
                    Text(title)
                        .font(Font.custom("Magic Retro", size: 24))
                        .foregroundColor(Color("pine"))
                    Spacer()
                    if let icon = rightButtonIcon, let action = rightButtonAction {
                        Button(action: action) {
                            Image(systemName: icon)
                                .foregroundColor(Color("pine"))
                                .font(.system(size: 24))
                        }
                    }
                }
                .padding()
                .background(backgroundColor.opacity(0.9))
            }
    }
}

// MARK: - Common View Extensions
extension View {
    func withDefaultNavigation(
        title: String,
        rightButtonIcon: String? = nil,
        rightButtonAction: (() -> Void)? = nil
    ) -> some View {
        self.modifier(NavigationBarModifier(
            title: title,
            rightButtonIcon: rightButtonIcon,
            rightButtonAction: rightButtonAction
        ))
    }
}

// MARK: - Other Shared Components
struct SegmentedControl: View {
    let options: [String]
    @Binding var activeSegment: String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { segment in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeSegment = segment
                    }
                }) {
                    Text(segment.capitalized)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            Group {
                                if activeSegment == segment {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color("beige"))
                                        .padding(4)
                                }
                            }
                        )
                        .foregroundColor(
                            activeSegment == segment ? Color("pine") : Color("beige")
                        )
                }
            }
        }
        .background(Color("pine"))
        .cornerRadius(12)
    }
}