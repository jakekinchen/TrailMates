//
//  EventRowView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/4/24.
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    let currentUser: User?
    let onJoinTap: () -> Void
    let onLeaveTap: () -> Void
    let showLeaveJoinButton: Bool
    
    init(
            event: Event,
            currentUser: User?,
            onJoinTap: @escaping () -> Void,
            onLeaveTap: @escaping () -> Void,
            showLeaveJoinButton: Bool = true
        ) {
            self.event = event
            self.currentUser = currentUser
            self.onJoinTap = onJoinTap
            self.onLeaveTap = onLeaveTap
            self.showLeaveJoinButton = showLeaveJoinButton
        }
    
    private var isUserAttending: Bool {
        guard let currentUser = currentUser else { return false }
        return event.attendeeIds.contains(currentUser.id)
    }
    
    private var isHostedByUser: Bool {
        guard let currentUser = currentUser else { return false }
        return event.hostId == currentUser.id
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Event Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("pine").opacity(0.8))
                    .shadow(color: Color("alwaysPine").opacity(0.8), radius: 4)
                    .frame(width: 80, height: 80)
                    
                    
                Image(systemName: event.eventType == .walk ? "figure.walk" :
                        event.eventType == .bike ? "bicycle" : "figure.run")
                    .foregroundColor(Color("beige"))
                    .font(.system(size: 30))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("pine"))
                    
                    if isHostedByUser {
                        Text("Hosted by you")
                            .font(.system(size: 12))
                            .foregroundColor(Color("pumpkin"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color("pumpkin").opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Date and Time
                HStack {
                    Image(systemName: "calendar")
                        .frame(width: 12, alignment: .center)
                        .padding(.trailing, 4)
                    Text(event.formattedDate())
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                
                // Location
                HStack {
                    Image(systemName: "mappin")
                        .frame(width: 12, alignment: .center)
                        .padding(.trailing, 4)
                    Text(event.getLocationName())
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                
                // Participants
                HStack {
                    Image(systemName: "person.2")
                        .frame(width: 12, alignment: .center)
                        .padding(.trailing, 4)
                    Text("\(event.attendeeIds.count) participants")
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                
                // Join/Leave Button
                if currentUser != nil && !isHostedByUser && showLeaveJoinButton {
                    Button(action: isUserAttending ? onLeaveTap : onJoinTap) {
                        Text(isUserAttending ? "Leave" : "Join")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isUserAttending ? .red : Color("alwaysBeige"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                isUserAttending ?
                                    Color.red.opacity(0.1) :
                                    Color("pumpkin")
                            )
                            .cornerRadius(16)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding()
        .background(
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor.black.withAlphaComponent(0.5) // Dark mode color with 80% opacity
                } else {
                    return UIColor.white // Light mode color
                }
            })
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }
}


