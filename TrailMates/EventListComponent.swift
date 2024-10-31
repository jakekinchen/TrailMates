import SwiftUI

struct EventListComponent: View {
    @ObservedObject var eventViewModel: EventViewModel
    @State private var activeSegment = "friends"
    let currentUser: User?
    let friends: [User]
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("View", selection: $activeSegment) {
                Text("Friends").tag("friends")
                Text("Events").tag("events")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color("beige"))
            
            ScrollView {
                VStack(spacing: 4) {
                    if activeSegment == "friends" {
                        // Friends List
                        FriendsListCard(friends: friends)
                    } else {
                        // Events List
                        VStack(spacing: 4) {
                            Text("Upcoming Today")
                                .font(.headline)
                                .foregroundColor(Color("pine"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ForEach(eventViewModel.events.filter { $0.isUpcoming() }) { event in
                                EventCard(event: event, user: currentUser)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color("beige").opacity(0.9))
        }
    }
}

struct EventCard: View {
    let event: Event
    let user: User?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Event Type Icon
                Image(systemName: event.eventType == .walk ? "figure.walk" :
                        event.eventType == .bike ? "bicycle" : "figure.run")
                    .foregroundColor(Color("pine"))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .padding(.trailing, 8)
                
                VStack(alignment: .leading) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(Color("pine"))
                    
                    Text(event.formattedDate())
                        .font(.subheadline)
                        .foregroundColor(Color("pine").opacity(0.8))
                }
                
                Spacer()
                
                // Join/Leave Button
                if let currentUser = user {
                    Button(action: {
                        // Handle join/leave action
                    }) {
                        Text(event.attendeeIds.contains(currentUser.id) ? "Leave" : "Join")
                            .font(.subheadline)
                            .foregroundColor(Color("beige"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("pumpkin"))
                            .cornerRadius(15)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}