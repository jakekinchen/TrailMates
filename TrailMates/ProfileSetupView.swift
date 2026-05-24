import SwiftUI
import PhotosUI
import Combine

// MARK: - ProfileSetupView
struct ProfileSetupView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager

    // MARK: - Constants
    var isEditMode: Bool = false

    // MARK: - State
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var profileImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var hasSelectedNewProfileImage = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showCropper = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
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

                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        titleView
                        profileImageView
                        textFieldsView
                        saveButton
                    }
                    .padding(.top)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        .task {
            await setupView()
        }
        .alert("Profile Setup", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Select Profile Picture", isPresented: $showActionSheet) {
            Button("Take a Photo") {
                imagePickerSourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Library") {
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $originalImage, sourceType: imagePickerSourceType)
        }
        .sheet(isPresented: $showCropper) {
            if let image = originalImage {
                ImageCropper(
                    image: image,
                    croppedImage: Binding(
                        get: { profileImage },
                        set: { newImage in
                            profileImage = newImage
                            hasSelectedNewProfileImage = newImage != nil
                        }
                    )
                )
            }
        }
        .onChange(of: originalImage) { _, newValue in
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
                    dismiss()
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
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
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
        .accessibilityLabel("Choose profile photo")
        .accessibilityHint("Double tap to select a profile photo")
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
            FloatingLabelTextField(
                placeholder: "First Name",
                text: $firstName,
                textContentType: .givenName,
                colorStyle: .standard,
                field: .firstName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Last Name",
                text: $lastName,
                textContentType: .familyName,
                colorStyle: .standard,
                field: .lastName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Username",
                text: $username,
                autocapitalization: .none,
                colorStyle: .standard,
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
    @MainActor
    func setupView() async {
        #if DEBUG
        print("\n ProfileSetupView - Setting up view")
        #endif
        if let user = userManager.currentUser {
            #if DEBUG
            print("Current User State:")
            print("   First Name: '\(user.firstName)'")
            print("   Last Name: '\(user.lastName)'")
            print("   Username: '\(user.username)'")
            #endif

            firstName = user.firstName
            lastName = user.lastName
            username = user.username
            if let imageData = user.profileImageData,
               let image = UIImage(data: imageData) {
                profileImage = image
                #if DEBUG
                print("   Profile Image: Loaded from local data")
                #endif
            } else if let image = try? await userManager.fetchProfileImage(for: user, forceRefresh: true) {
                profileImage = image
                #if DEBUG
                print("   Profile Image: Loaded from provider")
                #endif
            } else {
                #if DEBUG
                print("   Profile Image: Not available")
                #endif
            }
        } else {
            #if DEBUG
            print("No current user available during setup")
            #endif
        }
    }
}

// MARK: - ProfileSetupView Save Profile
private extension ProfileSetupView {
    func saveProfile() async throws {
        #if DEBUG
        print("\n ProfileSetupView - Starting Save Profile")
        print("Current State Variables:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        print("   Has Profile Image: \(profileImage != nil)")
        #endif

        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        print("\n Validating Inputs...")
        #endif
        guard await validateInputs() else {
            #if DEBUG
            print("Input validation failed")
            #endif
            return
        }
        #if DEBUG
        print("Input validation passed")
        #endif

        #if DEBUG
        print("\n Updating User Profile...")
        #endif
        try await updateUserProfile()
        #if DEBUG
        print("User profile updated")
        #endif

        if isEditMode {
            dismiss()
        } else {
            userManager.persistUserSession()
        }
    }

    func validateInputs() async -> Bool {
        #if DEBUG
        print("\n Validating Profile Inputs")
        print("Current Values:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        #endif

        guard !firstName.isEmpty else {
            #if DEBUG
            print("First name is empty")
            #endif
            alertMessage = "Please enter a first name."
            showAlert = true
            return false
        }

        guard !lastName.isEmpty else {
            #if DEBUG
            print("Last name is empty")
            #endif
            alertMessage = "Please enter a last name."
            showAlert = true
            return false
        }

        guard !username.isEmpty else {
            #if DEBUG
            print("Username is empty")
            #endif
            alertMessage = "Please enter a username."
            showAlert = true
            return false
        }

        let usernameRegex = "^[a-zA-Z0-9_]{1,20}$"
        guard username.range(of: usernameRegex, options: .regularExpression) != nil else {
            #if DEBUG
            print("Username format invalid")
            #endif
            alertMessage = "Username can only contain letters, numbers, and underscores, and must be between 1-20 characters."
            showAlert = true
            return false
        }

        if await userManager.isUsernameTaken(username) {
            #if DEBUG
            print("Username is already taken")
            #endif
            alertMessage = "This username is already taken. Please choose another."
            showAlert = true
            return false
        }

        #if DEBUG
        print("All validations passed")
        #endif
        return true
    }

    func updateUserProfile() async throws {
        #if DEBUG
        print("\n Updating User Profile")
        #endif
        guard let oldUser = userManager.currentUser else {
            #if DEBUG
            print("Error: No current user available")
            #endif
            alertMessage = "Error: No user found. Please try logging in again."
            showAlert = true
            throw AppError.notAuthenticated()
        }

        #if DEBUG
        print("Current User Before Update:")
        print("   ID: \(oldUser.id)")
        print("   First Name: '\(oldUser.firstName)'")
        print("   Last Name: '\(oldUser.lastName)'")
        print("   Username: '\(oldUser.username)'")
        #endif

        let wasProfileIncomplete = oldUser.firstName.isEmpty ||
                                  oldUser.lastName.isEmpty ||
                                  oldUser.username.isEmpty

        let user = oldUser
        user.firstName = firstName
        user.lastName = lastName
        user.username = username

        #if DEBUG
        if wasProfileIncomplete {
            print("Initial profile setup detected - will force save")
        }
        #endif

        if hasSelectedNewProfileImage, let image = profileImage {
            #if DEBUG
            print("Uploading profile image...")
            #endif
            try await userManager.setProfileImage(image)
            #if DEBUG
            print("Profile image uploaded")
            #endif
        }

        #if DEBUG
        print("Updated User State:")
        print("   First Name: '\(user.firstName)'")
        print("   Last Name: '\(user.lastName)'")
        print("   Username: '\(user.username)'")
        print("\n Saving updated user...")
        #endif
        if wasProfileIncomplete {
            try await userManager.saveInitialProfile(updatedUser: user)
        } else {
            try await userManager.saveProfile(updatedUser: user)
        }
        #if DEBUG
        print("User saved successfully")
        #endif

        if let updatedUser = userManager.currentUser {
            #if DEBUG
            print("\nUpdating local state with saved user:")
            print("   First Name: '\(updatedUser.firstName)'")
            print("   Last Name: '\(updatedUser.lastName)'")
            print("   Username: '\(updatedUser.username)'")
            #endif

            firstName = updatedUser.firstName
            lastName = updatedUser.lastName
            username = updatedUser.username

            if let image = try? await userManager.fetchProfileImage(for: updatedUser, forceRefresh: true) {
                profileImage = image
                #if DEBUG
                print("Profile image refreshed")
                #endif
            }
        }
    }
}

// MARK: - ProfileImagePicker
struct ProfileImagePicker: UIViewControllerRepresentable {
    // MARK: - Dependencies
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

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
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
