struct EventCard: View {
    let event: Event
    let user: User?
    @ObservedObject var eventViewModel: EventViewModel
    
    private var isUserAttending: Bool {
        guard let currentUser = user else { return false }
        return event.attendeeIds.contains(currentUser.id)
    }
    
    private var isHostedByUser: Bool {
        guard let currentUser = user else { return false }
        return event.hostId == currentUser.id
    }
    
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
                    HStack {
                        Text(event.title)
                            .font(.headline)
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
                    
                    Text(event.formattedDate())
                        .font(.subheadline)
                        .foregroundColor(Color("pine").opacity(0.8))
                }
                
                Spacer()
                
                // Join/Leave Button
                if let currentUser = user, !isHostedByUser {
                    Button(action: {
                        var mutableUser = currentUser
                        if isUserAttending {
                            eventViewModel.leaveEvent(user: &mutableUser, event: event)
                        } else {
                            eventViewModel.attendEvent(user: &mutableUser, event: event)
                        }
                    }) {
                        Text(isUserAttending ? "Leave" : "Join")
                            .font(.subheadline)
                            .foregroundColor(isUserAttending ? .red : Color("beige"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isUserAttending ?
                                    Color.red.opacity(0.1) :
                                    Color("pumpkin")
                            )
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