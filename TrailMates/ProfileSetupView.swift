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

    // MARK: - ViewModel
    @StateObject private var viewModel: ProfileSetupViewModel

    // MARK: - State
    @State private var originalImage: UIImage?
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showCropper = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @FocusState private var focusedField: Field?

    init(isEditMode: Bool = false) {
        self.isEditMode = isEditMode
        _viewModel = StateObject(wrappedValue: ProfileSetupViewModel(userManager: UserManager.shared))
    }

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
            await viewModel.setupFromCurrentUser()
        }
        .alert("Profile Setup", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
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
                        get: { viewModel.profileImage },
                        set: { newImage in
                            viewModel.profileImage = newImage
                            viewModel.hasSelectedNewProfileImage = newImage != nil
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
                        .foregroundColor(AppColors.pine)
                        .imageScale(.large)
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    var titleView: some View {
        Text(isEditMode ? "Edit Your Profile" : "Set Up Your Profile")
            .font(AppTypography.titleMedium)
            .foregroundColor(AppColors.alwaysPine)
            .padding(.top, isEditMode ? 30 : 10)
    }

    var profileImageView: some View {
        ZStack {
            if let image = viewModel.profileImage {
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
                            .foregroundColor(AppColors.alwaysPine)
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
                    .foregroundColor(AppColors.pine)
                    .font(.system(size: 30))
            )
    }

    var textFieldsView: some View {
        VStack(spacing: 15) {
            FloatingLabelTextField(
                placeholder: "First Name",
                text: $viewModel.firstName,
                textContentType: .givenName,
                colorStyle: .standard,
                field: .firstName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Last Name",
                text: $viewModel.lastName,
                textContentType: .familyName,
                colorStyle: .standard,
                field: .lastName,
                focusedField: $focusedField
            )
            FloatingLabelTextField(
                placeholder: "Username",
                text: $viewModel.username,
                autocapitalization: .none,
                colorStyle: .standard,
                field: .username,
                focusedField: $focusedField
            )
        }
        .padding(.horizontal)
    }

    var saveButton: some View {
        PrimaryButton("Save", isLoading: viewModel.isLoading) {
            Task {
                do {
                    if try await viewModel.saveProfile(isEditMode: isEditMode) {
                        if isEditMode {
                            dismiss()
                        }
                    }
                } catch is CancellationError {
                    return
                } catch {
                    viewModel.presentError(error, fallbackMessage: "Unable to save your profile.")
                }
            }
        }
        .disabled(viewModel.isLoading)
        .padding(.horizontal)
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
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.beige))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.pine, lineWidth: 2))
            .font(AppTypography.inputText)
    }
}
