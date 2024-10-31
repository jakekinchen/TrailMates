import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    let currentUser: User?
    @Environment(\.dismiss) var dismiss
    @ObservedObject var eventViewModel: EventViewModel
    
    private var isUserAttending: Bool {
        guard let currentUser = currentUser else { return false }
        return event.attendeeIds.contains(currentUser.id)
    }
    
    private var isHostedByUser: Bool {
        guard let currentUser = currentUser else { return false }
        return event.hostId == currentUser.id
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Event Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color("pine"))
                        
                        Text("Hosted by \(isHostedByUser ? "You" : "Friend")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    Image(systemName: event.eventType == .walk ? "figure.walk" :
                            event.eventType == .bike ? "bicycle" : "figure.run")
                        .font(.system(size: 40))
                        .foregroundColor(Color("pine"))
                }
                
                // Event Details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(icon: "calendar", text: event.formattedDate())
                    DetailRow(icon: "mappin", text: event.description ?? "No location")
                    DetailRow(icon: "person.2", text: "\(event.attendeeIds.count) participants")
                    if event.isPrivate {
                        DetailRow(icon: "lock", text: "Private Event")
                    }
                }
                
                // Map Preview
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: event.location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [event]) { event in
                    MapMarker(coordinate: event.location, tint: Color("pine"))
                }
                .frame(height: 200)
                .cornerRadius(12)
                
                // Action Buttons
                if !isHostedByUser {
                    Button(action: {
                        if var user = currentUser {
                            if isUserAttending {
                                eventViewModel.leaveEvent(user: &user, event: event)
                            } else {
                                eventViewModel.attendEvent(user: &user, event: event)
                            }
                        }
                    }) {
                        Text(isUserAttending ? "Leave Event" : "Join Event")
                            .font(.headline)
                            .foregroundColor(Color("beige"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isUserAttending ? Color.red : Color("pumpkin"))
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        if var user = currentUser {
                            eventViewModel.cancelEvent(user: &user, event: event)
                            dismiss()
                        }
                    }) {
                        Text("Cancel Event")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color("pine"))
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("pine"))
            Text(text)
                .foregroundColor(.gray)
        }
    }
}