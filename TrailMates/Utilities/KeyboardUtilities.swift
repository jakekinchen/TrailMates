//
//  KeyboardUtilities.swift
//  TrailMates
//
//  Keyboard handling utilities for consistent dismissal and management across the app.
//
//  Usage:
//  ```swift
//  // In views with forms/text fields:
//  VStack { ... }
//      .dismissKeyboardOnTap()
//
//  // Or programmatically:
//  Button("Done") {
//      KeyboardUtilities.dismiss()
//  }
//
//  // Track keyboard visibility:
//  @StateObject var keyboard = KeyboardObserver()
//  Text("Keyboard height: \(keyboard.height)")
//  ```

import SwiftUI
import Combine

// MARK: - Keyboard Dismissal

/// Utility for keyboard management
enum KeyboardUtilities {
    /// Dismisses the keyboard programmatically
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Keyboard Observer

/// Observable object that tracks keyboard visibility and height
@MainActor
final class KeyboardObserver: ObservableObject {
    /// Current keyboard height (0 when hidden)
    @Published private(set) var height: CGFloat = 0

    /// Whether the keyboard is currently visible
    @Published private(set) var isVisible: Bool = false

    /// Animation duration for keyboard show/hide
    @Published private(set) var animationDuration: Double = 0.25

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupKeyboardObservers()
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleKeyboardWillShow(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleKeyboardWillHide()
            }
            .store(in: &cancellables)
    }

    private func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            animationDuration = duration
        }

        height = keyboardFrame.height
        isVisible = true
    }

    private func handleKeyboardWillHide() {
        height = 0
        isVisible = false
    }
}

// MARK: - View Modifiers

/// Modifier that dismisses the keyboard when tapping outside of text fields
struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                KeyboardUtilities.dismiss()
            }
    }
}

/// Modifier that adjusts view offset based on keyboard height
struct KeyboardAdaptiveModifier: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()
    let offset: CGFloat

    init(offset: CGFloat = 1.0) {
        self.offset = offset
    }

    func body(content: Content) -> some View {
        content
            .offset(y: -keyboard.height * offset)
            .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.height)
    }
}

/// Modifier that ignores keyboard safe area
struct IgnoreKeyboardSafeAreaModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard)
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a tap gesture that dismisses the keyboard
    /// Useful for forms where tapping outside should dismiss the keyboard
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    /// Adjusts the view offset based on keyboard height
    /// - Parameter offset: Multiplier for keyboard height offset (default 1.0)
    func keyboardAdaptive(offset: CGFloat = 1.0) -> some View {
        modifier(KeyboardAdaptiveModifier(offset: offset))
    }

    /// Ignores the keyboard safe area insets
    func ignoreKeyboardSafeArea() -> some View {
        modifier(IgnoreKeyboardSafeAreaModifier())
    }

    /// Adds a toolbar button to dismiss the keyboard
    /// Useful for number pads and other keyboards without a return key
    func keyboardDismissButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    KeyboardUtilities.dismiss()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Keyboard Dismiss on Tap") {
    VStack(spacing: 20) {
        TextField("Tap outside to dismiss", text: .constant(""))
            .textFieldStyle(.roundedBorder)
            .padding()

        Text("Tap anywhere on this view to dismiss the keyboard")
            .foregroundColor(AppColors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .dismissKeyboardOnTap()
    .background(AppColors.backgroundPrimary)
}

#Preview("Keyboard Adaptive") {
    VStack {
        Spacer()
        TextField("This moves up with keyboard", text: .constant(""))
            .textFieldStyle(.roundedBorder)
            .padding()
    }
    .keyboardAdaptive(offset: 0.5)
    .background(AppColors.backgroundPrimary)
}
