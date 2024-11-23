//
//  ContactsListViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//


import SwiftUI
import Contacts

class ContactsListViewModel: ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var matchedUsers: [MatchedContact] = []
    @Published var unmatchedContacts: [CNContact] = []
    @Published var searchText: String = ""

    struct MatchedContact: Identifiable {
        let id: UUID
        let contact: CNContact
        let user: User
    }

    @MainActor
    func loadAndMatchContacts(userManager: UserManager) async {
        do {
            let loadedContacts = try await ContactsService.fetchContacts()
            let (matched, unmatched) = await categorizeContacts(loadedContacts, userManager: userManager)
            updateUI(with: loadedContacts, matched: matched, unmatched: unmatched)
        } catch {
            handleError(error)
        }
    }

    private func categorizeContacts(_ contacts: [CNContact], userManager: UserManager) async -> ([MatchedContact], [CNContact]) {
        var matched: [MatchedContact] = []
        var unmatched: [CNContact] = []

        for contact in contacts {
            if let user = await findMatchingUser(for: contact, userManager: userManager) {
                matched.append(MatchedContact(id: UUID(), contact: contact, user: user))
            } else {
                unmatched.append(contact)
            }
        }
        return (matched, unmatched)
    }

    private func findMatchingUser(for contact: CNContact, userManager: UserManager) async -> User? {
        for phoneNumber in contact.phoneNumbers {
            let number = phoneNumber.value.stringValue
            if let user = await userManager.findUserByPhoneNumber(number) {
                return user
            }
        }
        return nil
    }

    @MainActor
    private func updateUI(with contacts: [CNContact], matched: [MatchedContact], unmatched: [CNContact]) {
        self.contacts = contacts
        self.matchedUsers = matched
        self.unmatchedContacts = unmatched
    }

    private func handleError(_ error: Error) {
        // Handle errors gracefully, e.g., by showing an alert to the user
        print("Error fetching contacts: \(error)")
    }

    // Filtered contacts based on search
    var filteredMatchedUsers: [MatchedContact] {
        if searchText.isEmpty { return matchedUsers }
        return matchedUsers.filter { contact in
            let fullName = "\(contact.contact.givenName) \(contact.contact.familyName)".lowercased()
            return fullName.contains(searchText.lowercased())
        }
    }

    var filteredUnmatchedContacts: [CNContact] {
        if searchText.isEmpty { return unmatchedContacts }
        return unmatchedContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
            return fullName.contains(searchText.lowercased())
        }
    }
}