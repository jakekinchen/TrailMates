import SwiftUI
import PhotosUI
import Combine

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

struct ProfileSetupView: View {
    @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var userManager: UserManager
        
        // MARK: - State Properties
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
        //@State private var focusedField: Field?
        @FocusState private var focusedField: Field?
        
        var isEditMode: Bool = false
        
        enum Field {
            case firstName, lastName, username
        }
    
    // MARK: - Subviews
        private var headerView: some View {
            Group {
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
        }
        
        private var titleView: some View {
            Text(isEditMode ? "Edit Your Profile" : "Set Up Your Profile")
                .font(.custom("SF Pro", size: 28))
                .foregroundColor(Color("alwaysPine"))
                .fontWeight(.medium)
                .padding(.top, isEditMode ? 30 : 10)
        }
        
        private var profileImageView: some View {
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
        
        private var profileImageOverlay: some View {
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "camera.fill")
                        .foregroundColor(Color("pine"))
                        .font(.system(size: 30))
                )
        }
        
    private var textFieldsView: some View {
        VStack(spacing: 15) {
            FloatingLabelTextField(
                placeholder: "First Name",
                text: $firstName,
                textContentType: .givenName,
                field: .firstName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Last Name",
                text: $lastName,
                textContentType: .familyName,
                field: .lastName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Username",
                text: $username,
                textContentType: nil,
                autocapitalization: .none,
                field: .username,
                focusedField: $focusedField
            )
        }
        .padding(.horizontal)
        // Place the onChange modifiers here
        .onChange(of: firstName) { oldValue, newValue in
            if !newValue.isEmpty && focusedField == .firstName {
                focusedField = .lastName
            }
        }
        .onChange(of: lastName) { oldValue, newValue in
            if !newValue.isEmpty && focusedField == .lastName {
                focusedField = .username
            }
        }
    }
        
        private var saveButton: some View {
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

    // MARK: - Body
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: 35)
                        .ignoresSafeArea()
                    
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
                Alert(title: Text("Profile Setup"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(title: Text("Select Profile Picture"), buttons: [
                    .default(Text("Take a Photo")) {
                        imagePickerSourceType = .camera
                        showImagePicker = true
                    },
                    .default(Text("Choose from Library")) {
                        imagePickerSourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .cancel()
                ])
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $originalImage, sourceType: imagePickerSourceType)
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
        
        // MARK: - Setup
        private func setupView() {
            print("\n🔄 ProfileSetupView - Setting up view")
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
                print("⚠️ No current user available during setup")
            }
            
            setupKeyboardNotifications()
        }
        
        private func setupKeyboardNotifications() {
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
    

    struct FloatingLabelTextField: View {
        let placeholder: String
        @Binding var text: String
        var textContentType: UITextContentType?
        var keyboardType: UIKeyboardType = .default
        var contentType: UITextContentType?
        var isEnabled: Bool = true
        var autocapitalization: UITextAutocapitalizationType = .sentences
        var field: ProfileSetupView.Field
        @FocusState.Binding var focusedField: ProfileSetupView.Field?
        
        // Color customization
        var backgroundColor: Color = Color("beige")
        var foregroundColor: Color = Color("pine")
        var borderColor: Color = Color("pine")
        var labelColor: Color = Color("pine")
        var backgroundOpacity: Double = 1.0
        
        @State private var isAnimated = false
        
        var body: some View {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor.opacity(backgroundOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 2)
                    )
                
                // Floating Label
                Text(placeholder)
                    .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
                    .foregroundColor(labelColor.opacity(0.8))
                    .offset(y: isAnimated ? -14 : 0)
                    .offset(x: isAnimated ? 10 : 10)
                    .animation(.spring(response: 0.2), value: isAnimated)
                
                // Text Field
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

    struct ImagePicker: UIViewControllerRepresentable {
        @Binding var selectedImage: UIImage?
        var sourceType: UIImagePickerController.SourceType
        @Environment(\.presentationMode) var presentationMode

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

        class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: ImagePicker

            init(_ parent: ImagePicker) {
                self.parent = parent
            }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
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

    // Custom TextField Style
    struct CustomTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color("beige")))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color("pine"), lineWidth: 2))
                .font(.custom("SF Pro", size: 16))
        }
    }

    // MARK: - Save Profile Function
    private func saveProfile() async throws {
            print("\n📝 ProfileSetupView - Starting Save Profile")
            print("Current State Variables:")
            print("   First Name: '\(firstName)'")
            print("   Last Name: '\(lastName)'")
            print("   Username: '\(username)'")
            print("   Has Profile Image: \(profileImage != nil)")
            
            isLoading = true
            defer { isLoading = false }
            
            print("\n🔍 Validating Inputs...")
            guard await validateInputs() else {
                print("❌ Input validation failed")
                return
            }
            print("✅ Input validation passed")
            
            print("\n🔄 Updating User Profile...")
            try await updateUserProfile()
            print("✅ User profile updated")
            
            if isEditMode {
                presentationMode.wrappedValue.dismiss()
            } else {
                // For initial profile setup, persist the session and let ContentView handle navigation
                userManager.persistUserSession()
            }
        }

    // Input Validation
    private func validateInputs() async -> Bool {
        print("\n🔍 Validating Profile Inputs")
        print("Current Values:")
        print("   First Name: '\(firstName)'")
        print("   Last Name: '\(lastName)'")
        print("   Username: '\(username)'")
        
        // First name validation
        guard !firstName.isEmpty else {
            print("❌ First name is empty")
            alertMessage = "Please enter a first name."
            showAlert = true
            return false
        }
        
        // Last name validation
        guard !lastName.isEmpty else {
            print("❌ Last name is empty")
            alertMessage = "Please enter a last name."
            showAlert = true
            return false
        }
        
        // Username presence validation
        guard !username.isEmpty else {
            print("❌ Username is empty")
            alertMessage = "Please enter a username."
            showAlert = true
            return false
        }
        
        // Username format validation
        let usernameRegex = "^[a-zA-Z0-9_]{1,20}$"
        guard username.range(of: usernameRegex, options: .regularExpression) != nil else {
            print("❌ Username format invalid")
            alertMessage = "Username can only contain letters, numbers, and underscores, and must be between 1-20 characters."
            showAlert = true
            return false
        }
        
        // Check if username is taken
        if await userManager.isUsernameTaken(username) {
            print("❌ Username is already taken")
            alertMessage = "This username is already taken. Please choose another."
            showAlert = true
            return false
        }
        
        print("✅ All validations passed")
        return true
    }

    // Create or Update User
    private func updateUserProfile() async throws {
        print("\n🔄 Updating User Profile")
        guard let oldUser = userManager.currentUser else {
            print("❌ Error: No current user available")
            alertMessage = "Error: No user found. Please try logging in again."
            showAlert = true
            throw ProfileValidationError.noCurrentUser
        }
        
        print("Current User Before Update:")
        print("   ID: \(oldUser.id)")
        print("   First Name: '\(oldUser.firstName)'")
        print("   Last Name: '\(oldUser.lastName)'")
        print("   Username: '\(oldUser.username)'")
        
        // Create a new user object with updated fields
        let newUser = oldUser
        newUser.firstName = firstName
        newUser.lastName = lastName
        newUser.username = username
        
        // Detect if this is initial setup
        let isInitialSetup = oldUser.firstName.isEmpty || 
                            oldUser.lastName.isEmpty || 
                            oldUser.username.isEmpty
        
        if isInitialSetup {
            print("📝 Initial profile setup detected - will force save")
        }
        
        // Handle profile image first if it exists
        if let image = profileImage {
            print("📸 Uploading profile image...")
            try await userManager.setProfileImage(image)
            print("✅ Profile image uploaded")
        }
        
        print("Updated User State:")
        print("   First Name: '\(newUser.firstName)'")
        print("   Last Name: '\(newUser.lastName)'")
        print("   Username: '\(newUser.username)'")
        
        // Save updated user info - force save for initial setup
        print("\n💾 Saving updated user...")
        if isInitialSetup {
            // Use a special save method that forces the update
            try await userManager.saveInitialProfile(updatedUser: newUser)
        } else {
            try await userManager.saveProfile(updatedUser: newUser)
        }
        print("✅ User saved successfully")
        
        // Update the local state with the latest user data
        if let updatedUser = userManager.currentUser {
            print("\nUpdating local state with saved user:")
            print("   First Name: '\(updatedUser.firstName)'")
            print("   Last Name: '\(updatedUser.lastName)'")
            print("   Username: '\(updatedUser.username)'")
            
            firstName = updatedUser.firstName
            lastName = updatedUser.lastName
            username = updatedUser.username
            
            // Fetch the latest profile image
            if let image = try? await userManager.fetchProfileImage(for: updatedUser, forceRefresh: true) {
                profileImage = image
                print("✅ Profile image refreshed")
            }
        }
    }
}
