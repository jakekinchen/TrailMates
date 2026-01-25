//
//  TransparentBlurView.swift
//  TrailMates
//
//  A glass-morphism blur effect view using UIVisualEffectView.
//
//  Usage:
//  ```swift
//  // Basic usage
//  TransparentBlurView()
//
//  // With tint color
//  TransparentBlurView(tintColor: .systemBlue)
//
//  // Remove all filters (no blur)
//  TransparentBlurView(removeAllFilters: true)
//  ```

import SwiftUI

/// A UIViewRepresentable that provides a glass-morphism blur effect
struct TransparentBlurView: UIViewRepresentable {
    /// When true, removes all backdrop filters
    var removeAllFilters: Bool = false
    /// Optional tint color overlay
    var tintColor: UIColor?

    func makeUIView(context: Context) -> TransparentBlurViewHelper {
        return TransparentBlurViewHelper(removeAllFilters: removeAllFilters, tintColor: tintColor)
    }

    func updateUIView(_ uiView: TransparentBlurViewHelper, context: Context) {
    }
}

// Helper
class TransparentBlurViewHelper: UIVisualEffectView {
    init(removeAllFilters: Bool, tintColor: UIColor?) {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        
        if subviews.indices.contains(1) {
            subviews[1].alpha = 0
        }
        
        if let tintColor = tintColor {
            backgroundColor = tintColor.withAlphaComponent(0.2)
        }
        
        if let backdropLayer = layer.sublayers?.first {
            if removeAllFilters {
                backdropLayer.filters = []
            } else {
                backdropLayer.filters?.removeAll(where: { filter in
                    String(describing: filter) != "gaussianBlur"
                })
            }
        }
        
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    }
}

// MARK: - Previews
#Preview("Default Blur") {
    ZStack {
        LinearGradient(
            colors: [Color("pine"), Color("pumpkin")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        TransparentBlurView()
            .frame(width: 200, height: 200)
            .cornerRadius(20)
    }
}

#Preview("With Tint") {
    ZStack {
        Image(systemName: "map.fill")
            .font(.system(size: 200))
            .foregroundColor(Color("pine"))

        TransparentBlurView(tintColor: UIColor(named: "pine"))
            .frame(width: 150, height: 150)
            .cornerRadius(16)
    }
}
