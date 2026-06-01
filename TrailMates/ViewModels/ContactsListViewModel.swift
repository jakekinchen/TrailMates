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

    private struct ContactPhoneMatch {
        let contact: CNContact
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
            let cleansedNumbers = PhoneNumberService.shared.cleansePhoneNumbers(rawPhoneNumbers)
            
            print("📱 Processing \(cleansedNumbers.count) cleansed phone numbers")
            if cleansedNumbers.isEmpty {
                print("⚠️ No valid phone numbers found after cleansing")
                return
            }
            
            // 3. Call Cloud Function to find matching users with proper error handling
            let matchedUsers = try await userManager.findUsersByPhoneNumbers(cleansedNumbers)
            print("📞 Found \(matchedUsers.count) matching users")
            
            // 4. Create MatchedContact objects using the privacy-safe hash echoed
            // by the contact-matching Cloud Function.
            let newMatches = Self.matchedContacts(from: loadedContacts, matchedUsers: matchedUsers)
            
            print("✅ Found \(newMatches.count) matches out of \(loadedContacts.count) contacts")
            
            // 5. Update UI
            self.matchedUsers = newMatches
            checkContactsAccess()
            
        } catch let error as AppError {
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
            checkContactsAccess()
            return granted && hasFullContactsAccess
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }

    private func checkContactsAccess() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        hasFullContactsAccess = Self.contactsAccessAllowsReads(status)
    }

    static func matchedContacts(from contacts: [CNContact], matchedUsers: [User]) -> [MatchedContact] {
        let contactsByHash = contactMatchesByHash(from: contacts)
        var seenUserIds = Set<String>()

        return matchedUsers.compactMap { user in
            guard let matchedPhoneHash = user.matchedPhoneHash,
                  let contactMatch = contactsByHash[matchedPhoneHash],
                  !seenUserIds.contains(user.id) else {
                return nil
            }

            seenUserIds.insert(user.id)
            return MatchedContact(
                id: UUID(),
                contact: contactMatch.contact,
                user: user
            )
        }
    }

    private static func contactMatchesByHash(from contacts: [CNContact]) -> [String: ContactPhoneMatch] {
        var matchesByHash: [String: ContactPhoneMatch] = [:]

        for contact in contacts {
            for phoneNumber in contact.phoneNumbers.map({ $0.value.stringValue }) {
                guard let normalizedPhone = PhoneNumberService.shared.cleanseSingleNumber(phoneNumber) else {
                    continue
                }

                let phoneHash = PhoneNumberHasher.shared.hashPhoneNumber(normalizedPhone)
                matchesByHash[phoneHash] = ContactPhoneMatch(contact: contact)
            }
        }

        return matchesByHash
    }

    static func contactsAccessAllowsReads(_ status: CNAuthorizationStatus) -> Bool {
        if status == .authorized {
            return true
        }

        if #available(iOS 18.0, *), status == .limited {
            return true
        }

        return false
    }
}
