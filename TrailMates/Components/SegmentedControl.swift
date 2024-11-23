//
//  SegmentedControl.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/29/24.
//

import SwiftUI

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
