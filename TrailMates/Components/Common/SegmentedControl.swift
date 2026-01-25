//
//  SegmentedControl.swift
//  TrailMates
//
//  A customizable segmented control component with animated selection.
//
//  Usage:
//  ```swift
//  @State private var selectedSegment = "events"
//  SegmentedControl(
//      options: ["events", "friends", "map"],
//      activeSegment: $selectedSegment
//  )
//  ```

import SwiftUI

/// A custom segmented control with pill-style selection indicator
struct SegmentedControl: View {
    /// Array of segment option strings
    let options: [String]
    /// Binding to the currently active segment
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

// MARK: - Previews
#Preview("Two Options") {
    struct PreviewWrapper: View {
        @State private var selected = "events"
        var body: some View {
            SegmentedControl(
                options: ["events", "friends"],
                activeSegment: $selected
            )
            .padding()
        }
    }
    return PreviewWrapper()
}

#Preview("Three Options") {
    struct PreviewWrapper: View {
        @State private var selected = "all"
        var body: some View {
            SegmentedControl(
                options: ["all", "upcoming", "past"],
                activeSegment: $selected
            )
            .padding()
        }
    }
    return PreviewWrapper()
}
