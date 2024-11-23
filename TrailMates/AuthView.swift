import SwiftUI

struct AuthView: View {
    @State private var showingLoginFields = false
    @State private var showingSignupFields = false
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isVerificationStage = false
    @FocusState private var focusedField: Field?
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isVerificationSent = false
    @State private var errorMessage: String? = nil
    
    func dismissKeyboard() {
            focusedField = nil
        }

    var body: some View {
        ZStack {
            
            let background = Image("background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            background
            
            VStack(spacing: 0) {
                // Fixed height container for header and circle
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
                
                // Auth Buttons and Fields
                VStack(spacing: 16) {
                    if showingLoginFields || showingSignupFields {
                        VStack(spacing: 16) {
                            if isVerificationStage {
                                // Display phone number (non-editable)
                                FloatingLabelTextField(
                                    placeholder: "Phone Number",
                                    text: .constant(phoneNumber),
                                    keyboardType: .numberPad,
                                    contentType: .telephoneNumber,
                                    isEnabled: false,
                                    field: .phone,
                                    focusedField: $focusedField
                                )
                                
                                // Verification Code Input
                                FloatingLabelTextField(
                                    placeholder: "Verification Code",
                                    text: $verificationCode,
                                    keyboardType: .numberPad,
                                    contentType: .oneTimeCode,
                                    isEnabled: true,
                                    field: .verification,
                                    focusedField: $focusedField
                                )
                                .transition(.moveAndFade)
                            } else {
                                // Regular phone number input
                                FloatingLabelTextField(
                                    placeholder: "Phone Number",
                                    text: $phoneNumber,
                                    keyboardType: .numberPad,
                                    contentType: .telephoneNumber,
                                    isEnabled: true,
                                    field: .phone,
                                    focusedField: $focusedField
                                )
                                .onChange(of: phoneNumber) { oldValue, newValue in
                                    let digitsOnly = newValue.filter { $0.isNumber }
                                    if digitsOnly.count > 11 {
                                        phoneNumber = String(digitsOnly.prefix(11)) // Limit to 10 digits
                                    } else {
                                        phoneNumber = digitsOnly
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.moveAndFade)
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
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
                            // Verify Button
                            Button(action: {
                                authViewModel.verifyCode(verificationCode)
                            }) {
                                Text("Verify")
                                    .buttonStyle(primary: true)
                            }
                            .disabled(verificationCode.isEmpty)
                        } else {
                            // Login Button
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if !phoneNumber.isEmpty {
                                        authViewModel.sendVerificationCode(to: phoneNumber)
                                        isVerificationStage = true
                                        showingLoginFields = true
                                        showingSignupFields = false
                                        isVerificationSent = true
                                    } else {
                                        showingLoginFields = true
                                        showingSignupFields = false
                                    }
                                }
                            }) {
                                Text("Log In")
                                    .buttonStyle(primary: true)
                            }
                            .opacity(!showingSignupFields ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: showingSignupFields)
                            
                            // Sign Up Button
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if !phoneNumber.isEmpty {
                                        authViewModel.sendVerificationCode(to: phoneNumber)
                                        isVerificationStage = true
                                        showingSignupFields = true
                                        showingLoginFields = false
                                        isVerificationSent = true
                                    } else {
                                        showingSignupFields = true
                                        showingLoginFields = false
                                    }
                                }
                            }) {
                                Text("Sign Up")
                                    .buttonStyle(primary: false)
                            }
                            .opacity(!showingLoginFields ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: showingLoginFields)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                Spacer()
                Spacer()
            }
            .onChange(of: phoneNumber) {
                if phoneNumber.count == 10 {
                    dismissKeyboard()
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
                dismissKeyboard()
            })
        .ignoresSafeArea(.keyboard)
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

    init(placeholder: String,
         text: Binding<String>,
         keyboardType: UIKeyboardType,
         contentType: UITextContentType,
         isEnabled: Bool = true,
         field: Field,
         focusedField: FocusState<Field?>.Binding) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.contentType = contentType
        self.isEnabled = isEnabled
        self.field = field
        self._focusedField = focusedField
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Placeholder Label
            Text(placeholder)
                .font(.system(size: !text.isEmpty ? 10 : 16))
                .padding(.horizontal, 8)
                .foregroundColor(Color("alwaysBeige"))
                .offset(x: 8, y: !text.isEmpty ? -16 : 0)
                .animation(.easeInOut(duration: 0.2), value: !text.isEmpty)
                .allowsHitTesting(false)
                .zIndex(1)

            // TextField for Input
            TextField("", text: $text)
                .focused($focusedField, equals: field)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .disabled(!isEnabled)
                .offset(y: 4)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("alwaysPine"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("alwaysBeige"), lineWidth: isEnabled ? 1 : 0.5)
                        )
                )
                .foregroundColor(Color("alwaysBeige"))
                .opacity(isEnabled ? 1 : 0.7)
                .if(field == .phone) { view in
                    view.modifier(PhoneNumberFormatter(text: $text))
                }
                .onChange(of: text) { oldValue, newValue in
                    if newValue.count >= 10 {
                        focusedField = nil  // Dismiss keyboard
                    }
                }
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


