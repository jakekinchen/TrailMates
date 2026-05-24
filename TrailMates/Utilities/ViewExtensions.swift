//
//  Ext.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/21/24.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }
}

struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var overlayColor: Color {
        switch colorScheme {
        case .dark: return Color.black.opacity(0.4)
        default: return Color.white.opacity(0.4)
        }
    }

    func body(content: Content) -> some View {
        ZStack {
            Color("beige").ignoresSafeArea()
            content
                .scrollContentBackground(.hidden)
                .background(overlayColor)
        }
    }
}
