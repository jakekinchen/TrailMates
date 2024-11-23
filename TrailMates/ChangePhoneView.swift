struct ChangePhoneView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var newPhoneNumber = ""
    @State private var verificationCode = ""
    @State private var isVerificationSent = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case phone
        case verification
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Current phone number display
            if let currentPhone = userManager.currentUser?.phoneNumber {
                Text("Current: \(currentPhone)")
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            
            // Phone number or verification code input
            if !isVerificationSent {
                FloatingLabelTextField(
                    placeholder: "New Phone Number",
                    text: $newPhoneNumber,
                    keyboardType: .numberPad,
                    contentType: .telephoneNumber,
                    isEnabled: true,
                    field: .phone,
                    focusedField: $focusedField
                )
                
                Button(action: {
                    verifyNewPhone()
                }) {
                    Text("Send Verification Code")
                        .buttonStyle(primary: true)
                }
                .disabled(newPhoneNumber.isEmpty)
            } else {
                FloatingLabelTextField(
                    placeholder: "Verification Code",
                    text: $verificationCode,
                    keyboardType: .numberPad,
                    contentType: .oneTimeCode,
                    isEnabled: true,
                    field: .verification,
                    focusedField: $focusedField
                )
                
                Button(action: {
                    confirmPhoneChange()
                }) {
                    Text("Verify and Update")
                        .buttonStyle(primary: true)
                }
                .disabled(verificationCode.isEmpty)
            }
            
            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Change Phone")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Phone Number Update", isPresented: $showAlert) {
            Button("OK") {
                if authViewModel.isAuthenticated {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authViewModel.isAuthenticated) { newValue in
            if newValue {
                Task {
                    await updateUserPhoneNumber()
                }
            }
        }
    }
    
    private func verifyNewPhone() {
        guard !newPhoneNumber.isEmpty else { return }
        authViewModel.sendVerificationCode(to: newPhoneNumber)
        withAnimation {
            isVerificationSent = true
        }
    }
    
    private func confirmPhoneChange() {
        guard !verificationCode.isEmpty else { return }
        authViewModel.verifyCode(verificationCode)
    }
    
    private func updateUserPhoneNumber() async {
        await userManager.updatePhoneNumber(newPhoneNumber)
        showAlert = true
        alertMessage = "Phone number successfully updated"
    }
}