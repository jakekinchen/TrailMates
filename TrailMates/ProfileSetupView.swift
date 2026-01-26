import SwiftUI
import PhotosUI
import Combine

// MARK: - ProfileValidationError
enum ProfileValidationError: LocalizedError {
    case missingRequiredFields(String)
    case invalidField(String)
    case noCurrentUser

    var errorDescription: String? {
        switch self {
        case .missingRequiredFields(let message),
             .invalidField(let message):
            return message
        case .noCurrentUser:
            return "No current user found. Please try logging in again."
        }
    }
}

// MARK: - ProfileSetupView
struct ProfileSetupView: View {
    // MARK: - Environment
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var userManager: UserManager

    // MARK: - Constants
    var isEditMode: Bool = false

    // MARK: - State
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var profileImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showCropper = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?

    // MARK: - Field Enum
    enum Field {
        case firstName, lastName, username
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundImage(geometry: geometry)

                VStack(spacing: 0) {
                    headerView

                    VStack(spacing: 20) {
                        titleView
                        profileImageView

                        Spacer()
                            .frame(height: 140)

                        textFieldsView
                        saveButton

                        Spacer()
                    }
                    .offset(y: -keyboardHeight * 0.75)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                }
                .padding(.top)
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        .onAppear(perform: setupView)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Profile Setup"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Select Profile Picture"),
                buttons: [
                    .default(Text("Take a Photo")) {
                        imagePickerSourceType = .camera
                        showImagePicker = true
                    },
                    .default(Text("Choose from Library")) {
                        imagePickerSourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $originalImage, sourceType: imagePickerSourceType)
        }
        .sheet(isPresented: $showCropper) {
            if let image = originalImage {
                ImageCropper(image: image, croppedImage: $profileImage)
            }
        }
        .onChange(of: originalImage) { oldValue, newValue in
            if newValue != nil {
                showCropper = true
            }
        }
    }
}

// MARK: - ProfileSetupView View Builders
private extension ProfileSetupView {
    func backgroundImage(geometry: GeometryProxy) -> some View {
        Image("background")
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(y: 35)
            .ignoresSafeArea()
    }

    @ViewBuilder
    var headerView: some View {
        if !isEditMode {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Color("pine"))
                        .imageScale(.large)
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    var titleView: some View {
        Text(isEditMode ? "Edit Your Profile" : "Set Up Your Profile")
            .font(.custom("SF Pro", size: 28))
            .foregroundColor(Color("alwaysPine"))
            .fontWeight(.medium)
            .padding(.top, isEditMode ? 30 : 10)
    }

    var profileImageView: some View {
        ZStack {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(profileImageOverlay)
                    .contentShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .foregroundColor(Color("alwaysPine"))
                            .font(.system(size: 30))
                    )
            }
        }
        .onTapGesture { showActionSheet = true }
        .padding(.top, 20)
    }

    var profileImageOverlay: some View {
        Circle()
            .fill(Color.white.opacity(0.4))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "camera.fill")
                    .foregroundColor(Color("pine"))
                    .font(.system(size: 30))
            )
    }

    var textFieldsView: some View {
        VStack(spacing: 15) {
            ProfileFloatingLabelTextField(
                placeholder: "First Name",
                text: $firstName,
                textContentType: .givenName,
                field: .firstName,
                focusedField: $focusedField
            )
            ProfileFloatingLabelTextField(
                placeholder: "Last Name",
                text: $lastName,
                textContentType: .familyName,
                field: .lastName,
                focusedField: $focusedField
            )
            ProfileFloatingLabelTextField(
                placeholder: "Username",
                text: $username,
                textContentType: nil,
                autocapitalization: .none,
                field: .username,
                focusedField: $focusedField
            )
        }
        .padding(.horizontal)
    }

    var saveButton: some View {
        Button(action: {
            Task {
                try await saveProfile()
            }
        }) {
            ZStack {
                Text("Save")
                    .font(.custom("SF Pro", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(Color("alwaysBeige"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("pumpkin"))
                    .cornerRadius(25)

                if isLoading {
                    ProgressView()
                }
            }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1)
        .padding(.horizontal)
    }
}

// MARK: - ProfileSetupView Setup
private extension ProfileSetupView {
    func setupView() {
        print("\n ProfileSetupView - Setting up view")
        if let user = userManager.currentUser {
            print("Current User State:")
            print("   First Name: '\(user.firstName)'")
            print("   Last Name: '\(user.lastName)'")
            print("   Username: '\(user.username)'")

            firstName = user.firstName
            lastName = user.lastName
            username = user.username
            if let imageData = user.profileImageData {
                profileImage = UIImage(data: imageData)
                print("   Profile Image: \(profileImage != nil ? "Loaded" : "Failed to load")")
            }
        } else {
            print("No current user available during setup")
        }

        setupKeyboardNotifications()
    }

    func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            keyboardHeight = keyboardFrame.height
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
}

// MARK: - ProfileSetupView Save Profile
private extension ProfileSetupView {
    func saveProfile() async throws {
        print("\n ProfileSetupView - Starting Save Profile")
        print("Current State Variables:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        print("   Has Profile Image: \(profileImage != nil)")

        isLoading = true
        defer { isLoading = false }

        print("\n Validating Inputs...")
        guard await validateInputs() else {
            print("Input validation failed")
            return
        }
        print("Input validation passed")

        print("\n Updating User Profile...")
        try await updateUserProfile()
        print("User profile updated")

        if isEditMode {
            presentationMode.wrappedValue.dismiss()
        } else {
            userManager.persistUserSession()
        }
    }

    func validateInputs() async -> Bool {
        print("\n Validating Profile Inputs")
        print("Current Values:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")

        guard !firstName.isEmpty else {
            print("First name is empty")
            alertMessage = "Please enter a first name."
            showAlert = true
            return false
        }

        guard !lastName.isEmpty else {
            print("Last name is empty")
            alertMessage = "Please enter a last name."
            showAlert = true
            return false
        }

        guard !username.isEmpty else {
            print("Username is empty")
            alertMessage = "Please enter a username."
            showAlert = true
            return false
        }

        let usernameRegex = "^[a-zA-Z0-9_]{1,20}$"
        guard username.range(of: usernameRegex, options: .regularExpression) != nil else {
            print("Username format invalid")
            alertMessage = "Username can only contain letters, numbers, and underscores, and must be between 1-20 characters."
            showAlert = true
            return false
        }

        if await userManager.isUsernameTaken(username) {
            print("Username is already taken")
            alertMessage = "This username is already taken. Please choose another."
            showAlert = true
            return false
        }

        print("All validations passed")
        return true
    }

    func updateUserProfile() async throws {
        print("\n Updating User Profile")
        guard let oldUser = userManager.currentUser else {
            print("Error: No current user available")
            alertMessage = "Error: No user found. Please try logging in again."
            showAlert = true
            throw ProfileValidationError.noCurrentUser
        }

        print("Current User Before Update:")
        print("   ID: \(oldUser.id)")
        print("   First Name: '\(oldUser.firstName)'")
        print("   Last Name: '\(oldUser.lastName)'")
        print("   Username: '\(oldUser.username)'")

        let newUser = oldUser
        newUser.firstName = firstName
        newUser.lastName = lastName
        newUser.username = username

        let isInitialSetup = oldUser.firstName.isEmpty ||
                            oldUser.lastName.isEmpty ||
                            oldUser.username.isEmpty

        if isInitialSetup {
            print("Initial profile setup detected - will force save")
        }

        if let image = profileImage {
            print("Uploading profile image...")
            try await userManager.setProfileImage(image)
            print("Profile image uploaded")
        }

        print("Updated User State:")
        print("   First Name: '\(newUser.firstName)'")
        print("   Last Name: '\(newUser.lastName)'")
        print("   Username: '\(newUser.username)'")

        print("\n Saving updated user...")
        if isInitialSetup {
            try await userManager.saveInitialProfile(updatedUser: newUser)
        } else {
            try await userManager.saveProfile(updatedUser: newUser)
        }
        print("User saved successfully")

        if let updatedUser = userManager.currentUser {
            print("\nUpdating local state with saved user:")
            print("   First Name: '\(updatedUser.firstName)'")
            print("   Last Name: '\(updatedUser.lastName)'")
            print("   Username: '\(updatedUser.username)'")

            firstName = updatedUser.firstName
            lastName = updatedUser.lastName
            username = updatedUser.username

            if let image = try? await userManager.fetchProfileImage(for: updatedUser, forceRefresh: true) {
                profileImage = image
                print("Profile image refreshed")
            }
        }
    }
}

// MARK: - ProfileFloatingLabelTextField
struct ProfileFloatingLabelTextField: View {
    // MARK: - Dependencies
    let placeholder: String
    @Binding var text: String
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType?
    var isEnabled: Bool = true
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var field: ProfileSetupView.Field
    @FocusState.Binding var focusedField: ProfileSetupView.Field?

    // MARK: - Styling
    var backgroundColor: Color = Color("beige")
    var foregroundColor: Color = Color("pine")
    var borderColor: Color = Color("pine")
    var labelColor: Color = Color("pine")
    var backgroundOpacity: Double = 1.0

    // MARK: - State
    @State private var isAnimated = false

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            backgroundRectangle
            floatingLabel
            textField
        }
        .frame(height: 56)
        .onChange(of: text) { oldValue, newValue in
            withAnimation {
                isAnimated = !newValue.isEmpty
            }
        }
        .onAppear {
            isAnimated = !text.isEmpty
        }
    }
}

// MARK: - ProfileFloatingLabelTextField View Builders
private extension ProfileFloatingLabelTextField {
    var backgroundRectangle: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor.opacity(backgroundOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 2)
            )
    }

    var floatingLabel: some View {
        Text(placeholder)
            .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
            .foregroundColor(labelColor.opacity(0.8))
            .offset(y: isAnimated ? -14 : 0)
            .offset(x: isAnimated ? 10 : 10)
            .animation(.spring(response: 0.2), value: isAnimated)
    }

    var textField: some View {
        TextField("", text: $text)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .autocapitalization(autocapitalization)
            .disabled(!isEnabled)
            .focused($focusedField, equals: field)
            .font(.custom("SF Pro", size: 16))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.top, isAnimated ? 8 : 0)
    }
}

// MARK: - ProfileImagePicker
struct ProfileImagePicker: UIViewControllerRepresentable {
    // MARK: - Dependencies
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType

    // MARK: - Environment
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - UIViewControllerRepresentable
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        if sourceType == .camera {
            picker.cameraDevice = .front
            picker.cameraCaptureMode = .photo
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfileImagePicker

        init(_ parent: ProfileImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - ProfileCustomTextFieldStyle
struct ProfileCustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color("beige")))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("pine"), lineWidth: 2))
            .font(.custom("SF Pro", size: 16))
    }
}
