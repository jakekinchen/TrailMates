# TrailMates Codebase Guidelines

This document outlines the core architectural patterns and rules to be consistently followed in the TrailMates codebase.

---

## 1. Singleton Pattern

- **Usage**: Managers and core services should be singletons with private initializers.

**Correct:**

    class SomeManager: ObservableObject {
        static let shared = SomeManager()
        private init() { }
    }

**Incorrect:**

    let manager = SomeManager()

---

## 2. DataProvider Pattern

- **Data Access**: Utilize a `DataProvider` protocol with dependency injection for all data operations.

**Correct:**

    class SomeViewModel {
        private let dataProvider: DataProvider
        init(dataProvider: DataProvider = FirebaseDataProvider.shared) {
            self.dataProvider = dataProvider
        }
    }

**Incorrect:**

    class SomeViewModel {
        private let db = Firestore.firestore()
    }

---

## 3. Actor Isolation

- **ViewModels and UI Classes**: Use `@MainActor` for proper actor isolation.

**Correct:**

    @MainActor
    class SomeViewModel: ObservableObject {
        @Published private(set) var state: ViewState
    }

**Incorrect:**

    class SomeViewModel: ObservableObject {
        @Published var state: ViewState
    }

---

## 4. ViewModel Patterns

- **Consistency**: Follow the `UserManager` pattern for all ViewModels.

**Correct:**

    class EventViewModel: ObservableObject {
        static let shared = EventViewModel()
        private let dataProvider: DataProvider
        private init(dataProvider: DataProvider = FirebaseDataProvider.shared) {
            self.dataProvider = dataProvider
        }
    }

---

## 5. State Management

- **Controlled Access**: Use `private(set)` with `@Published` properties.

**Correct:**

    @Published private(set) var events: [Event] = []

**Incorrect:**

    @Published var events: [Event] = []

---

## 6. Error Handling

- **Async/Await**: Implement proper error handling with `async` functions.

**Correct:**

    func fetchEvents() async throws -> [Event] {
        try await dataProvider.fetchEvents()
    }

**Incorrect:**

    func fetchEvents(completion: @escaping ([Event]?) -> Void) {
        // ...
    }

---

## 7. Preview Support

- **Mock Data**: Support SwiftUI previews using mock data providers.

**Correct:**

    static var preview: SomeViewModel = {
        let viewModel = SomeViewModel(dataProvider: MockDataProvider())
        // Setup preview state
        return viewModel
    }()

---

## 8. Initialization

- **Lazy Initialization**: Use `initializeIfNeeded` methods with error handling.

**Correct:**

    func initializeIfNeeded() async throws {
        guard !hasInitialized else { return }
        try await setup()
        hasInitialized = true
    }

**Incorrect:**

    init() {
        setup()
    }

---

## 9. Location Management

- **Pattern**: Use consistent patterns with async permission handling.

**Correct:**

    @MainActor
    class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
        func requestLocationPermission() async -> CLAuthorizationStatus {
            await withCheckedContinuation { continuation in
                // Implementation
            }
        }
    }

---

## 10. Model Architecture

- **Immutability and Utilities**: Create immutable models with utility extensions.

**Correct:**

    struct Event: Codable, Identifiable {
        let id: UUID
        let title: String
        let dateTime: Date
    }

    extension Event {
        func isUpcoming() -> Bool {
            dateTime > Date()
        }
    }

---

## 11. SwiftUI View Patterns

- **Organized Structure**: Follow a consistent structure in views.

    struct ContentView: View {
        // Property Wrappers
        @StateObject private var viewModel: ViewModel
        @EnvironmentObject private var userManager: UserManager

        // State Variables
        @State private var isLoading = false

        // Computed Properties
        private var isValid: Bool { /* ... */ }

        // View Body
        var body: some View { /* ... */ }

        // Subviews
        private var contentView: some View { /* ... */ }

        // Helper Methods
        private func loadData() { /* ... */ }
    }

---

## 12. Shared Types Pattern

- **Common Definitions**: Use shared types for enums and constants.

**SharedTypes.swift:**

    enum Field: Hashable {
        case phone
        case verification
    }

**Usage in views:**

    @FocusState private var focusedField: Field?

---

## 13. View-Specific Styling

- **Settings Views**: Use minimal styling with system backgrounds and pine accents.
- **Main Features**: Use branded styling with beige backgrounds and pine accents.
- **Navigation Bars**: Apply consistent navigation styles.

**Correct:**

    .withDefaultNavigation(
        title: "Title",
        rightButtonIcon: "bell",
        rightButtonAction: { /* ... */ }
    )

---

## 14. Loading State Management

- **Centralized State**: Use a single `isLoading` state per view.

    @State private var isLoading = false

- **Loading Overlay:**

    .overlay {
        if isLoading {
            ProgressView()
        }
    }

- **Async Pattern**: Use `defer` for state cleanup in async functions.

    func loadContent() async {
        isLoading = true
        defer { isLoading = false }
        // Async work
    }

---

## 15. Actor Isolation in Deinitializers

- **Cleanup**: Wrap `deinit` code in a `Task` with `@MainActor`.

    @MainActor
    class SomeManager: ObservableObject {
        deinit {
            Task { @MainActor in
                // Cleanup code
            }
        }
    }

---

## 16. Navigation and State Management

- **State Ownership**: Keep state local; avoid unnecessary prop drilling.

**Correct:**

    struct DetailView: View {
        @State private var localState: String = ""
    }

**Incorrect:**

    struct ParentView: View {
        @State private var sharedState: String = ""
        var body: some View {
            ChildView(sharedState: $sharedState)
        }
    }

---

## 17. Additional Guidelines

- **Firebase Access**: Only through `FirebaseDataProvider`; never directly in views or view models.
- **State Updates**: Perform UI updates on the main thread using `@MainActor`.
- **Error Messages**: Provide user-friendly, localized messages.
- **Dependency Injection**: Use protocols for dependencies to facilitate testing.
- **Memory Management**: Use `[weak self]` in closures; clean up observers.
- **Async Operations**: Prefer `async/await`; manage loading states properly.
- **View Structure**: Keep views focused; extract reusable components.
- **Documentation**: Document public interfaces and complex implementations.
- **Location Services**: Use async permission requests; handle updates on the main thread.
- **Model Design**: Make models `Codable`; use immutable properties; provide utility methods.
- **SwiftUI Best Practices**: Consistent view organization; proper use of property wrappers.
- **Background Tasks**: Handle background updates properly; clean up in `deinit`.

---

By adhering to these guidelines, we ensure a consistent, maintainable, and scalable codebase that follows best practices and supports robust testing.