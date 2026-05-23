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
                ZStack {
                    // Single glass background that covers the entire area
                    TransparentBlurView()
                        .background(backgroundColor.opacity(0.65))
                        .edgesIgnoringSafeArea(.top)
                    
                    // Content
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
                }
                .frame(height: 60)
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
