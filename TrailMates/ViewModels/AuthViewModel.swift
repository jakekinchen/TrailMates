// ViewModels/AuthViewModel.swift

import SwiftUI
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var verificationID: String?
    @Published var errorMessage: String?

    func sendVerificationCode(to phoneNumber: String) {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
                return
            }
            DispatchQueue.main.async {
                self?.verificationID = verificationID
            }
        }
    }

    func verifyCode(_ code: String) {
        guard let verificationID = verificationID else { return }
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
                return
            }
            DispatchQueue.main.async {
                self?.isAuthenticated = true
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            verificationID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}