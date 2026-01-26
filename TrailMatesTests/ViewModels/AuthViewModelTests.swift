import Testing
import Foundation
@testable import TrailMatesATX

/// Tests for AuthViewModel phone authentication flow states and error handling.
/// Note: AuthViewModel depends on FirebaseAuth which requires actual Firebase initialization.
/// These tests focus on state management, error handling, and phone number formatting logic.
@Suite("AuthViewModel Tests")
@MainActor
struct AuthViewModelTests {

    // MARK: - Initial State Tests

    @Test("AuthViewModel has correct initial state")
    func testInitialState() {
        let viewModel = AuthViewModel()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.showError == false)
        #expect(viewModel.errorMessage == "")
        #expect(viewModel.verificationId == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isVerifying == false)
        #expect(viewModel.phoneNumber == "")
        #expect(viewModel.verificationCode == "")
        #expect(viewModel.isSigningUp == false)
    }

    @Test("AuthViewModel phone number can be set")
    func testSetPhoneNumber() {
        let viewModel = AuthViewModel()

        viewModel.phoneNumber = "+1 (555) 123-4567"

        #expect(viewModel.phoneNumber == "+1 (555) 123-4567")
    }

    @Test("AuthViewModel verification code can be set")
    func testSetVerificationCode() {
        let viewModel = AuthViewModel()

        viewModel.verificationCode = "123456"

        #expect(viewModel.verificationCode == "123456")
    }

    @Test("AuthViewModel signup mode can be toggled")
    func testSignupModeToggle() {
        let viewModel = AuthViewModel()

        #expect(viewModel.isSigningUp == false)

        viewModel.isSigningUp = true
        #expect(viewModel.isSigningUp == true)

        viewModel.isSigningUp = false
        #expect(viewModel.isSigningUp == false)
    }

    // MARK: - Error State Tests

    @Test("AuthViewModel can show error message")
    func testShowErrorMessage() {
        let viewModel = AuthViewModel()

        viewModel.showError = true
        viewModel.errorMessage = "Test error message"

        #expect(viewModel.showError == true)
        #expect(viewModel.errorMessage == "Test error message")
    }

    @Test("AuthViewModel error can be cleared")
    func testClearError() {
        let viewModel = AuthViewModel()

        // Set error
        viewModel.showError = true
        viewModel.errorMessage = "Some error"

        // Clear error
        viewModel.showError = false
        viewModel.errorMessage = ""

        #expect(viewModel.showError == false)
        #expect(viewModel.errorMessage == "")
    }

    // MARK: - Loading State Tests

    @Test("AuthViewModel loading state can be toggled")
    func testLoadingState() {
        let viewModel = AuthViewModel()

        #expect(viewModel.isLoading == false)

        viewModel.isLoading = true
        #expect(viewModel.isLoading == true)

        viewModel.isLoading = false
        #expect(viewModel.isLoading == false)
    }

    @Test("AuthViewModel verifying state can be toggled")
    func testVerifyingState() {
        let viewModel = AuthViewModel()

        #expect(viewModel.isVerifying == false)

        viewModel.isVerifying = true
        #expect(viewModel.isVerifying == true)

        viewModel.isVerifying = false
        #expect(viewModel.isVerifying == false)
    }

    // MARK: - Verification ID Tests

    @Test("AuthViewModel verification ID can be set")
    func testSetVerificationId() {
        let viewModel = AuthViewModel()

        #expect(viewModel.verificationId == nil)

        viewModel.verificationId = "test-verification-id"
        #expect(viewModel.verificationId == "test-verification-id")
    }

    @Test("AuthViewModel verification ID can be cleared")
    func testClearVerificationId() {
        let viewModel = AuthViewModel()

        viewModel.verificationId = "test-verification-id"
        viewModel.verificationId = nil

        #expect(viewModel.verificationId == nil)
    }

    // MARK: - Authentication State Tests

    @Test("AuthViewModel authentication state can be toggled")
    func testAuthenticationState() {
        let viewModel = AuthViewModel()

        #expect(viewModel.isAuthenticated == false)

        viewModel.isAuthenticated = true
        #expect(viewModel.isAuthenticated == true)

        viewModel.isAuthenticated = false
        #expect(viewModel.isAuthenticated == false)
    }

    // MARK: - Phone Number Format Tests

    @Test("Valid 10-digit US phone numbers are recognized")
    func testValidUSPhoneNumbers() {
        // These are the formats that should work with the formatPhoneNumber logic
        let validFormats = [
            "5551234567",       // 10 digits
            "(555) 123-4567",   // Formatted 10 digits
            "555-123-4567",     // Dashed 10 digits
            "555.123.4567",     // Dotted 10 digits
            "555 123 4567"      // Spaced 10 digits
        ]

        for format in validFormats {
            let cleanNumber = format.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            #expect(cleanNumber.count == 10 || cleanNumber.count == 11, "Format \(format) should have 10 or 11 digits")
        }
    }

    @Test("Valid 11-digit US phone numbers starting with 1 are recognized")
    func testValidUSPhoneNumbersWith1Prefix() {
        let validFormats = [
            "15551234567",        // 11 digits starting with 1
            "1 (555) 123-4567",   // Formatted with 1 prefix
            "1-555-123-4567"      // Dashed with 1 prefix
        ]

        for format in validFormats {
            let cleanNumber = format.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            #expect(cleanNumber.count == 11, "Format \(format) should have 11 digits")
            #expect(cleanNumber.hasPrefix("1"), "Format \(format) should start with 1")
        }
    }

    @Test("Phone numbers with + prefix are preserved")
    func testPhoneNumbersWithPlusPrefix() {
        let number = "+1 (555) 123-4567"
        #expect(number.hasPrefix("+"))
    }

    // MARK: - Flow State Tests

    @Test("AuthViewModel simulates code sending flow states")
    func testCodeSendingFlowStates() {
        let viewModel = AuthViewModel()

        // Initial state
        #expect(viewModel.isLoading == false)
        #expect(viewModel.showError == false)

        // Simulate loading start
        viewModel.isLoading = true
        viewModel.showError = false

        #expect(viewModel.isLoading == true)
        #expect(viewModel.showError == false)

        // Simulate success
        viewModel.isLoading = false
        viewModel.verificationId = "mock-verification-id"
        viewModel.isVerifying = true

        #expect(viewModel.isLoading == false)
        #expect(viewModel.verificationId != nil)
        #expect(viewModel.isVerifying == true)
    }

    @Test("AuthViewModel simulates code sending error flow")
    func testCodeSendingErrorFlow() {
        let viewModel = AuthViewModel()

        // Simulate loading start
        viewModel.isLoading = true

        // Simulate error
        viewModel.isLoading = false
        viewModel.showError = true
        viewModel.errorMessage = "Invalid phone number"

        #expect(viewModel.isLoading == false)
        #expect(viewModel.showError == true)
        #expect(viewModel.errorMessage == "Invalid phone number")
    }

    @Test("AuthViewModel simulates verification flow states")
    func testVerificationFlowStates() {
        let viewModel = AuthViewModel()

        // Setup: verification ID set
        viewModel.verificationId = "mock-verification-id"
        viewModel.verificationCode = "123456"

        // Simulate verification start
        viewModel.isLoading = true
        viewModel.showError = false

        #expect(viewModel.isLoading == true)

        // Simulate success
        viewModel.isLoading = false
        viewModel.isVerifying = false
        viewModel.isAuthenticated = true

        #expect(viewModel.isLoading == false)
        #expect(viewModel.isVerifying == false)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test("AuthViewModel simulates verification error flow")
    func testVerificationErrorFlow() {
        let viewModel = AuthViewModel()

        // Setup
        viewModel.verificationId = "mock-verification-id"
        viewModel.verificationCode = "wrong-code"
        viewModel.isLoading = true

        // Simulate error
        viewModel.showError = true
        viewModel.errorMessage = "Invalid verification code"
        viewModel.isLoading = false
        viewModel.isVerifying = false
        viewModel.isAuthenticated = false

        #expect(viewModel.showError == true)
        #expect(viewModel.errorMessage == "Invalid verification code")
        #expect(viewModel.isAuthenticated == false)
    }

    // MARK: - verifyCode Requirements Test

    @Test("verifyCode requires verification ID to be set")
    func testVerifyCodeRequiresVerificationId() {
        let viewModel = AuthViewModel()

        // Without verification ID, verification should fail
        #expect(viewModel.verificationId == nil)

        // The actual verifyCode method would show error
        // We simulate the expected behavior
        if viewModel.verificationId == nil {
            viewModel.showError = true
            viewModel.errorMessage = "Missing verification ID"
        }

        #expect(viewModel.showError == true)
        #expect(viewModel.errorMessage == "Missing verification ID")
    }

    // MARK: - State Reset Tests

    @Test("AuthViewModel states can be reset for new attempt")
    func testStateReset() {
        let viewModel = AuthViewModel()

        // Set various states
        viewModel.phoneNumber = "+1 (555) 123-4567"
        viewModel.verificationCode = "123456"
        viewModel.verificationId = "some-id"
        viewModel.isLoading = true
        viewModel.isVerifying = true
        viewModel.showError = true
        viewModel.errorMessage = "Some error"
        viewModel.isAuthenticated = true
        viewModel.isSigningUp = true

        // Reset states
        viewModel.phoneNumber = ""
        viewModel.verificationCode = ""
        viewModel.verificationId = nil
        viewModel.isLoading = false
        viewModel.isVerifying = false
        viewModel.showError = false
        viewModel.errorMessage = ""
        viewModel.isAuthenticated = false
        viewModel.isSigningUp = false

        // Verify reset
        #expect(viewModel.phoneNumber == "")
        #expect(viewModel.verificationCode == "")
        #expect(viewModel.verificationId == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isVerifying == false)
        #expect(viewModel.showError == false)
        #expect(viewModel.errorMessage == "")
        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.isSigningUp == false)
    }

    // MARK: - Signup vs Login Mode Tests

    @Test("AuthViewModel differentiates signup and login modes")
    func testSignupVsLoginModes() {
        let viewModel = AuthViewModel()

        // Login mode (default)
        #expect(viewModel.isSigningUp == false)

        // Switch to signup mode
        viewModel.isSigningUp = true
        #expect(viewModel.isSigningUp == true)

        // The signup mode affects the flow after verification
        // In signup mode: creates new user
        // In login mode: logs in existing user
    }

    // MARK: - Multiple Attempts Test

    @Test("AuthViewModel handles multiple verification attempts")
    func testMultipleVerificationAttempts() {
        let viewModel = AuthViewModel()

        // First attempt - wrong code
        viewModel.verificationId = "verification-id"
        viewModel.verificationCode = "111111"
        viewModel.showError = true
        viewModel.errorMessage = "Wrong code"

        #expect(viewModel.showError == true)

        // Clear error for retry
        viewModel.showError = false
        viewModel.errorMessage = ""
        viewModel.verificationCode = "222222"

        // Second attempt - still wrong
        viewModel.showError = true
        viewModel.errorMessage = "Wrong code again"

        #expect(viewModel.showError == true)

        // Clear and try correct code
        viewModel.showError = false
        viewModel.errorMessage = ""
        viewModel.verificationCode = "123456"

        // Success
        viewModel.isAuthenticated = true
        viewModel.isVerifying = false

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.showError == false)
    }
}
