//
//  SectionHeader.swift
//  TrailMates
//
//  Reusable section header for pinned LazyVStack sections.
//
//  Usage:
//  ```swift
//  Section(header: SectionHeader(title: "My Section")) {
//      // section content
//  }
//  ```
//

import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
                .padding(.horizontal)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(Color("beige"))
    }
}
