import SwiftUI

// MARK: - FAQItem
struct FAQItem {
    let question: String
    let answer: String
}

// MARK: - HelpCenterView
struct HelpCenterView: View {
    // MARK: - Constants
    private let faqItems: [FAQItem] = [
        FAQItem(
            question: "How do I create an event?",
            answer: """
            To create an event:
            1. Go to the Events tab
            2. Tap the + button in the top right
            3. Fill in the event details
            4. Choose a location on the map
            5. Tap Create to publish your event
            """
        ),
        FAQItem(
            question: "How does location sharing work?",
            answer: """
            Location sharing is privacy-focused and customizable:
            - You control who sees your location
            - Share with friends only
            - Share with event hosts
            - Share with event groups

            Adjust these settings in Privacy Settings.
            """
        ),
        FAQItem(
            question: "How do I add friends?",
            answer: """
            Add friends in several ways:
            1. Search by username or phone number
            2. Import from your contacts
            3. Send friend requests
            4. Accept incoming requests

            Manage your friends in the Friends tab.
            """
        )
    ]

    // MARK: - Body
    var body: some View {
        List {
            faqSection
            contactSupportSection
            feedbackSection
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Help Center")
                    .foregroundColor(AppColors.pine)
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .foregroundColor(AppColors.pine)
        .themedBackground()
    }
}

// MARK: - HelpCenterView Sections
private extension HelpCenterView {
    var faqSection: some View {
        Section(header: Text("Frequently Asked Questions").foregroundColor(AppColors.pine)) {
            ForEach(faqItems, id: \.question) { item in
                NavigationLink(item.question) {
                    FAQDetailView(question: item.question, answer: item.answer)
                }
            }
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }

    var contactSupportSection: some View {
        Section(header: Text("Contact Support").foregroundColor(AppColors.pine)) {
            Link(destination: URL(string: AppConstants.supportEmail)!) {
                HStack {
                    Text("Email Support")
                    Spacer()
                    Image(systemName: "envelope.fill")
                }
            }

            Link(destination: URL(string: AppConstants.supportCenterURL)!) {
                HStack {
                    Text("Visit Support Center")
                    Spacer()
                    Image(systemName: "safari.fill")
                }
            }
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }

    var feedbackSection: some View {
        Section(header: Text("Feedback").foregroundColor(AppColors.pine)) {
            Button(action: {
                // Implement feedback form
            }) {
                HStack {
                    Text("Submit Feedback")
                    Spacer()
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }
}

// MARK: - FAQDetailView
struct FAQDetailView: View {
    // MARK: - Dependencies
    let question: String
    let answer: String

    // MARK: - Body
    var body: some View {
        ZStack {
            AppColors.beige.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(question)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.pine)
                        .padding(.bottom, 8)

                    Text(answer)
                        .foregroundColor(AppColors.pine.opacity(0.8))
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(question)
                        .foregroundColor(AppColors.beige)
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
