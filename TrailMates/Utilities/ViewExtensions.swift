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
}
