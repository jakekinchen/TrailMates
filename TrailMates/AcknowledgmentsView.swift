import SwiftUI

// MARK: - AcknowledgmentsView
struct AcknowledgmentsView: View {
    // MARK: - Body
    var body: some View {
        List {
            openSourceSection
            assetsSection
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Acknowledgements")
                    .foregroundColor(Color("pine"))
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
    }
}

// MARK: - AcknowledgmentsView Sections
private extension AcknowledgmentsView {
    var openSourceSection: some View {
        Section(header: Text("Open Source Libraries").foregroundColor(Color("pine"))) {
            acknowledgmentRow(title: "Firebase", description: "Mobile and web application development platform")
            acknowledgmentRow(title: "SwiftUI", description: "User interface framework by Apple")
        }
        .listRowBackground(Color("beige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }

    var assetsSection: some View {
        Section(header: Text("Assets").foregroundColor(Color("pine"))) {
            acknowledgmentRow(title: "SF Symbols", description: "Icons by Apple Inc.")
        }
        .listRowBackground(Color("beige").opacity(0.9))
        .foregroundColor(Color("pine"))
    }
}

// MARK: - AcknowledgmentsView Helpers
private extension AcknowledgmentsView {
    func acknowledgmentRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("pine"))
            Text(description)
                .font(.caption)
                .foregroundColor(Color("pine").opacity(0.7))
        }
    }
}
