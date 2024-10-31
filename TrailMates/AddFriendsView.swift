//
//  AddFriendsView 2.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/8/24.
//


import SwiftUI
import Contacts

struct AddFriendsView: View {
    let isOnboarding: Bool
    let onSkip: (() -> Void)?
    let onFinish: (() -> Void)?

    @State private var isInstagramLinked = false
    @State private var isFacebookLinked = false
    @State private var contacts: [CNContact] = []
    @State private var instagramFriends: [SocialMediaUser] = []
    @State private var facebookFriends: [SocialMediaUser] = []
    @State private var showInstagramLinkSheet = false
    @State private var showFacebookLinkSheet = false
    @State private var showContactsPermissionSheet = false

    var body: some View {
        NavigationView {
            VStack {
                // Title
                Text("Add Friends")
                    .font(.largeTitle)
                    .padding()

                Spacer()

                // Instagram Linking Section
                Button(action: {
                    if isInstagramLinked {
                        fetchInstagramFriends()
                    } else {
                        linkInstagram()
                    }
                }) {
                    HStack {
                        Image("instagram_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(isInstagramLinked ? "View Instagram Friends" : "Link Instagram")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal)

                // Facebook Linking Section
                Button(action: {
                    if isFacebookLinked {
                        fetchFacebookFriends()
                    } else {
                        linkFacebook()
                    }
                }) {
                    HStack {
                        Image("facebook_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(isFacebookLinked ? "View Facebook Friends" : "Link Facebook")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal)

                // Contacts Section
                Button(action: {
                    requestContactsAccess()
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Add from Contacts")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal)

                // Lists of Friends (if any)
                if !instagramFriends.isEmpty {
                    List {
                        Section(header: Text("Instagram Friends on TrailMates")) {
                            ForEach(instagramFriends) { user in
                                FriendRow(friend: user)
                            }
                        }
                    }
                }

                if !facebookFriends.isEmpty {
                    List {
                        Section(header: Text("Facebook Friends on TrailMates")) {
                            ForEach(facebookFriends) { user in
                                FriendRow(friend: user)
                            }
                        }
                    }
                }

                if !contacts.isEmpty {
                    List {
                        Section(header: Text("Contacts on TrailMates")) {
                            ForEach(contacts, id: \.identifier) { contact in
                                HStack {
                                    Text("\(contact.givenName) \(contact.familyName)")
                                    Spacer()
                                    Button(action: {
                                        // Add friend action
                                    }) {
                                        Text("Add")
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Bottom Buttons
                HStack {
                    if isOnboarding, let onSkip = onSkip {
                        Button(action: onSkip) {
                            Text("Skip")
                                .foregroundColor(Color("pine"))
                        }
                        .padding()
                    }

                    Spacer()

                    if let onFinish = onFinish {
                        Button(action: onFinish) {
                            Text("Done")
                                .fontWeight(.bold)
                                .foregroundColor(Color("beige"))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("pumpkin"))
                                .cornerRadius(15)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func linkInstagram() {
        // Simulate linking Instagram account
        isInstagramLinked = true
        fetchInstagramFriends()
    }

    private func fetchInstagramFriends() {
        // Simulate fetching friends
        instagramFriends = [
            SocialMediaUser(id: "1", username: "instaFriend1"),
            SocialMediaUser(id: "2", username: "instaFriend2")
        ]
    }

    private func linkFacebook() {
        // Simulate linking Facebook account
        isFacebookLinked = true
        fetchFacebookFriends()
    }

    private func fetchFacebookFriends() {
        // Simulate fetching friends
        facebookFriends = [
            SocialMediaUser(id: "3", username: "fbFriend1"),
            SocialMediaUser(id: "4", username: "fbFriend2")
        ]
    }

    private func requestContactsAccess() {
        // Implement contacts permission and fetching logic
        // For now, simulate contacts
        contacts = [
            CNContact()
        ]
    }
}

struct FriendRow: View {
    let friend: SocialMediaUser

    var body: some View {
        HStack {
            Text(friend.username)
            Spacer()
            Button(action: {
                // Add friend action
            }) {
                Text("Add")
            }
        }
    }
}

struct SocialMediaUser: Identifiable {
    let id: String
    let username: String
}