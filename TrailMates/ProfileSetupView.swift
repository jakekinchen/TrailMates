import SwiftUI
import PhotosUI
import Combine

struct ProfileSetupView: View {
    @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var userManager: UserManager
        
        // MARK: - State Properties
        @State private var firstName: String = ""
        @State private var lastName: String = ""
        @State private var username: String = ""
        let phoneNumber: String? = nil
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
                .fill(Color.black.opacity(0.4))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
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
            if let user = userManager.currentUser {
                firstName = user.firstName
                lastName = user.lastName
                username = user.username
                if let imageData = user.profileImageData {
                    profileImage = UIImage(data: imageData)
                }
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
        var autocapitalization: UITextAutocapitalizationType = .sentences
        var field: ProfileSetupView.Field
        @FocusState.Binding var focusedField: ProfileSetupView.Field?
        
        @State private var isAnimated = false
        
        var body: some View {
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("beige"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("pine"), lineWidth: 2)
                    )
                
                // Floating Label
                Text(placeholder)
                    .font(.custom("SF Pro", size: isAnimated ? 12 : 16))
                    .foregroundColor(Color("pine").opacity(0.8))
                    .offset(y: isAnimated ? -14 : 0)
                    .offset(x: isAnimated ? 10 : 10)
                    .animation(.spring(response: 0.2), value: isAnimated)
                
                // Text Field
                TextField("", text: $text)
                    .textContentType(textContentType)
                    .autocapitalization(autocapitalization)
                    .focused($focusedField, equals: field)
                    .font(.custom("SF Pro", size: 16))
                    .foregroundColor(Color("pine"))
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

    // Save Profile Function
    private func saveProfile() async throws {
            isLoading = true
            defer { isLoading = false }
            
            guard await validateInputs() else { return }
            
            try await updateUserProfile()
            
            if isEditMode {
                presentationMode.wrappedValue.dismiss()
            }
        }

    // Input Validation
    private func validateInputs() async -> Bool {
            // First name validation
            guard !firstName.isEmpty else {
                alertMessage = "Please enter a first name."
                showAlert = true
                return false
            }
        
            // Last name validation
            guard !lastName.isEmpty else {
                alertMessage = "Please enter a last name."
                showAlert = true
                return false
            }
            
            // Username presence validation
            guard !username.isEmpty else {
                alertMessage = "Please enter a username."
                showAlert = true
                return false
            }
            
            // Username format validation
            let usernameRegex = "^[a-zA-Z0-9_]{1,20}$"
            guard username.range(of: usernameRegex, options: .regularExpression) != nil else {
                alertMessage = "Username can only contain letters, numbers, and underscores, and must be between 1-20 characters."
                showAlert = true
                return false
            }
            
            // Check if username is taken
            if await userManager.isUsernameTaken(username) {
                alertMessage = "This username is already taken. Please choose another."
                showAlert = true
                return false
            }
            
            return true
        }

    // Create or Update User
    // In ProfileSetupView
    private func updateUserProfile() async throws {
        if var currentUser = userManager.currentUser {
            // Update existing user
            currentUser.firstName = firstName
            currentUser.lastName = lastName
            currentUser.username = username
            if let image = profileImage {
                currentUser.profileImageData = image.jpegData(compressionQuality: 0.8)
            }
            
            try await userManager.saveProfile(updatedUser: currentUser)
        } else {
            // Let UserManager handle new user creation through the login method
            guard let phoneNumber = phoneNumber else {
                fatalError("Phone number is required for new user creation")
            }
            
            // First login/create the user
            await userManager.login(phoneNumber: phoneNumber)
            
            // After login, update the user's profile information
            if var user = userManager.currentUser {
                user.firstName = firstName
                user.lastName = lastName
                user.username = username
                if let image = profileImage {
                    user.profileImageData = image.jpegData(compressionQuality: 0.8)
                }
                
                try await userManager.saveProfile(updatedUser: user)
            }
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
            // Preview for profile editing
            ProfileSetupView(isEditMode: true)
                .environmentObject(UserManager())
        }
    }
}
