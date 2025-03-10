import SwiftUI

// MARK: - Field Type
enum Field: Hashable {
    case phone
    case verification
}

struct AuthView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject var userManager: UserManager
    @FocusState private var focusedField: Field?
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showingLoginFields = false
    @State private var showingSignupFields = false
    @State private var isVerificationStage = false
    @State private var isVerificationSent = false
    @State private var isCheckingPhoneNumber = false
    
    var body: some View {
        ZStack {
            // Background from first version
            let background = Image("background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            background
            
            VStack(spacing: 0) {
                // Fixed height container for header and circle from first version
                VStack(spacing: 0) {
                    // Header with back button and title
                    ZStack {
                        HStack {
                            if showingLoginFields || showingSignupFields {
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        if isVerificationStage {
                                            isVerificationStage = false
                                        } else {
                                            showingLoginFields = false
                                            showingSignupFields = false
                                            phoneNumber = ""
                                            verificationCode = ""
                                            authViewModel.showError = false
                                            authViewModel.errorMessage = ""
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.left")
                                        .foregroundColor(Color("alwaysPine"))
                                        .imageScale(.large)
                                        .padding(.leading, 20)
                                        .offset(x: 8)
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                            Spacer()
                        }
                        
                        Text("TrailMates")
                            .font(.custom("Magic Retro", size: 48))
                            .foregroundColor(Color("alwaysPine"))
                    }
                    .frame(height: 60)
                    .padding(.top, 110)
                    
                    Circle()
                        .fill(Color("pumpkin"))
                        .frame(width: 60, height: 60)
                        .padding(.top, 20)
                }
                .frame(height: 250)
                
                Spacer()
                Spacer()
                Spacer()
                
                // Auth Fields Container
                VStack(spacing: 16) {
                    if showingLoginFields || showingSignupFields {
                        VStack(spacing: 16) {
                            if isVerificationStage {
                                FloatingLabelTextField(
                                    placeholder: "Verification Code",
                                    text: $verificationCode,
                                    keyboardType: .numberPad,
                                    contentType: .oneTimeCode,
                                    isEnabled: !authViewModel.isLoading,
                                    field: .verification,
                                    focusedField: $focusedField
                                )
                                .onChange(of: verificationCode) { oldValue, newValue in
                                    authViewModel.verificationCode = newValue
                                }
                                .transition(.moveAndFade)
                            } else {
                                FloatingLabelTextField(
                                    placeholder: "Phone Number",
                                    text: $phoneNumber,
                                    keyboardType: .phonePad,
                                    contentType: .telephoneNumber,
                                    isEnabled: !authViewModel.isLoading,
                                    field: .phone,
                                    focusedField: $focusedField
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.moveAndFade)
                    }

                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("alwaysBeige"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("alwaysPine"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("pumpkin"), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Buttons Container
                    VStack(spacing: 12) {
                        if isVerificationStage {
                            Button(action: {
                                Task {
                                    await authViewModel.verifyCode()
                                }
                            }) {
                                Text("Verify")
                                    .buttonStyle(primary: true)
                            }
                            .disabled(verificationCode.isEmpty)
                        } else {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    if !phoneNumber.isEmpty {
                                        isCheckingPhoneNumber = true
                                        print("🔄 Login - Starting phone number check: \(phoneNumber)")
                                        Task {
                                            print("🔍 Login - Checking if user exists")
                                            if await userManager.checkUserExists(phoneNumber: phoneNumber) {
                                                print("✅ Login - User found, proceeding with verification")
                                                // User exists, proceed with login
                                                authViewModel.phoneNumber = phoneNumber
                                                await authViewModel.sendCode()
                                                isVerificationStage = true
                                                showingLoginFields = true
                                                showingSignupFields = false
                                                isVerificationSent = true
                                            } else {
                                                print("❌ Login - No user found with phone number")
                                                // No user found with this phone number
                                                authViewModel.showError = true
                                                authViewModel.errorMessage = "No account found with this phone number. Please sign up instead."
                                            }
                                            isCheckingPhoneNumber = false
                                        }
                                    } else {
                                        print("⚠️ Login - Empty phone number field")
                                        showingLoginFields = true
                                        showingSignupFields = false
                                    }
                                }
                            }) {
                                if isCheckingPhoneNumber {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("alwaysBeige")))
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Log In")
                                        .buttonStyle(primary: true)
                                }
                            }
                            .disabled(isCheckingPhoneNumber)
                            .opacity(!showingSignupFields ? 1 : 0)
                            .animation(.easeOut(duration: 0.1), value: showingSignupFields)
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    if !phoneNumber.isEmpty {
                                        isCheckingPhoneNumber = true
                                        Task {
                                            if await userManager.checkUserExists(phoneNumber: phoneNumber) {
                                                // User already exists
                                                authViewModel.showError = true
                                                authViewModel.errorMessage = "An account already exists with this phone number. Please log in instead."
                                                isCheckingPhoneNumber = false
                                                return
                                            }
                                            // No existing user, proceed with signup
                                            authViewModel.phoneNumber = phoneNumber
                                            authViewModel.isSigningUp = true
                                            await authViewModel.sendCode()
                                            isVerificationStage = true
                                            showingSignupFields = true
                                            showingLoginFields = false
                                            isVerificationSent = true
                                            isCheckingPhoneNumber = false
                                        }
                                    } else {
                                        showingSignupFields = true
                                        showingLoginFields = false
                                    }
                                }
                            }) {
                                if isCheckingPhoneNumber {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("alwaysBeige")))
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Sign Up")
                                        .buttonStyle(primary: false)
                                }
                            }
                            .disabled(isCheckingPhoneNumber)
                            .opacity(!showingLoginFields ? 1 : 0)
                            .animation(.easeOut(duration: 0.1), value: showingLoginFields)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                Spacer()
                Spacer()
            }
            .onChange(of: phoneNumber) { oldValue, newValue in
                if phoneNumber.count == 10 {
                    dismissKeyboard()
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            dismissKeyboard()
        })
        .ignoresSafeArea(.keyboard)
        // .alert("Error", isPresented: $authViewModel.showError) {
        //     Button("OK", role: .cancel) { }
        // } message: {
        //     Text(authViewModel.errorMessage)
        // }
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
}

struct InputFormattingModifier: ViewModifier {
    @Binding var text: String
    let field: Field
    
    func body(content: Content) -> some View {
        if field == .phone {
            content.modifier(PhoneNumberFormatter(text: $text))
        } else {
            content
        }
    }
}

struct FloatingLabelTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let contentType: UITextContentType
    let isEnabled: Bool
    let field: Field
    @FocusState.Binding var focusedField: Field?

    var body: some View {
        ZStack(alignment: .leading) {
            // Placeholder Label that floats above
            Text(placeholder)
                .font(.system(size: !text.isEmpty ? 10 : 16))
                .padding(.horizontal, 8)
                .foregroundColor(Color("alwaysBeige"))
                .offset(x: 8, y: !text.isEmpty ? -16 : 0)
                .animation(.easeInOut(duration: 0.2), value: !text.isEmpty)
                .allowsHitTesting(false)
                .zIndex(1)

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .disabled(!isEnabled)
                .focused($focusedField, equals: field)
                .offset(y: !text.isEmpty ? 2 : 0)
                .onTapGesture {
                    if focusedField == field {
                        UIPasteboard.general.string = text
                        text = ""
                    }
                    focusedField = field
                }
                .onChange(of: text) { oldValue, newValue in
                    let oldDigitCount = oldValue.filter { $0.isNumber }.count
                    let newDigitCount = newValue.filter { $0.isNumber }.count
                    
                    // Handle phone number field
                    if field == .phone && newDigitCount >= 11 && newDigitCount > oldDigitCount {
                        focusedField = nil
                    }
                    
                    // Handle verification code field
                    if field == .verification {
                        // Only allow 6 digits for verification code
                        if newDigitCount > 6 {
                            text = String(newValue.filter { $0.isNumber }.prefix(6))
                        }
                        // Dismiss keyboard when 6 digits are entered
                        if newDigitCount == 6 && newDigitCount > oldDigitCount {
                            focusedField = nil
                        }
                    }
                }
                .modifier(InputFormattingModifier(text: $text, field: field))
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("alwaysPine"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("alwaysBeige"), lineWidth: 1)
                        )
                )
                .foregroundColor(Color("alwaysBeige"))
        }
        .padding(.top, 12)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(Color("alwaysBeige"))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("alwaysPine"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("alwaysBeige"), lineWidth: 1)
                    )
            )
    }
}

extension Text {
    func buttonStyle(primary: Bool) -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(primary ? Color("alwaysBeige") : Color("pumpkin"))
            .frame(maxWidth: .infinity)
            .padding()
            .background(primary ? Color("pumpkin") : Color("alwaysBeige"))
            .cornerRadius(25)
    }
}

extension AnyTransition {
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}


