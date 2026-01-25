//
//  ContactsListViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//


import SwiftUI
import Contacts

@MainActor
class ContactsListViewModel: ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var matchedUsers: [MatchedContact] = []
    @Published var searchText: String = ""
    @Published private(set) var hasFullContactsAccess = false
    @Published private(set) var isLoading = false
    @Published var error: Error?

    struct MatchedContact: Identifiable {
        let id: UUID
        let contact: CNContact
        let user: User
    }

    var filteredMatchedUsers: [MatchedContact] {
        if searchText.isEmpty {
            return matchedUsers
        }
        return matchedUsers.filter { contact in
            let fullName = "\(contact.contact.givenName) \(contact.contact.familyName)".lowercased()
            let username = contact.user.username.lowercased()
            let searchTerm = searchText.lowercased()
            return fullName.contains(searchTerm) || username.contains(searchTerm)
        }
    }

    @MainActor
    func loadAndMatchContacts(userManager: UserManager) async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure we're logged in before proceeding
        guard userManager.isLoggedIn else {
            print("⚠️ Cannot load contacts: User not logged in")
            return
        }
        
        do {
            // 1. Load contacts
            let loadedContacts = try await ContactsService.fetchContacts()
            self.contacts = loadedContacts
            
            // 2. Extract and cleanse phone numbers in one batch operation
            let rawPhoneNumbers = loadedContacts.flatMap { contact in
                contact.phoneNumbers.map { $0.value.stringValue }
            }
            let cleansedNumbers = PhoneNumberUtility.cleansePhoneNumbers(rawPhoneNumbers)
            
            print("📱 Processing \(cleansedNumbers.count) cleansed phone numbers")
            if cleansedNumbers.isEmpty {
                print("⚠️ No valid phone numbers found after cleansing")
                return
            }
            
            // 3. Call Cloud Function to find matching users with proper error handling
            let matchedUsers = try await userManager.findUsersByPhoneNumbers(cleansedNumbers)
            print("📞 Found \(matchedUsers.count) matching users")
            
            // 4. Create MatchedContact objects using a more efficient approach
            var newMatches: [MatchedContact] = []
            
            // Create a lookup dictionary for faster matching
            let usersByPhone = Dictionary(uniqueKeysWithValues: 
                matchedUsers.map { ($0.phoneNumber, $0) }
            )
            
            for contact in loadedContacts {
                // Get cleansed numbers for this contact
                let contactNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                    .compactMap { PhoneNumberUtility.cleanseSingleNumber($0) }
                
                // Find first matching user using the lookup dictionary
                if let matchingNumber = contactNumbers.first(where: { usersByPhone[$0] != nil }),
                   let matchedUser = usersByPhone[matchingNumber] {
                    newMatches.append(MatchedContact(
                        id: UUID(),
                        contact: contact,
                        user: matchedUser
                    ))
                }
            }
            
            print("✅ Found \(newMatches.count) matches out of \(loadedContacts.count) contacts")
            
            // 5. Update UI
            self.matchedUsers = newMatches
            checkContactsAccess()
            
        } catch let error as ValidationError {
            print("❌ Validation error: \(error.localizedDescription)")
            self.error = error
        } catch {
            print("❌ Error loading contacts: \(error)")
            self.error = error
        }
    }

    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            if granted {
                self.hasFullContactsAccess = true
            }
            return granted
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }

    private func checkContactsAccess() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        hasFullContactsAccess = status == .authorized
    }
}