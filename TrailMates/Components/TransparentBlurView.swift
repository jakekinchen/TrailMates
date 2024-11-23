//
//  TransparentBlurView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/31/24.
//
import SwiftUI

// MARK: - TransparentBlurView
struct TransparentBlurView: UIViewRepresentable {
    var removeAllFilters: Bool = false
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
