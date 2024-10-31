import SwiftUI

struct EventsView: View {
    @ObservedObject var eventViewModel: EventViewModel
    @State private var activeSegment = "today"
    @State private var showCreateEvent = false
    
    var segmentedOptions = ["today", "upcoming", "past"]
    
    var filteredEvents: [Event] {
        switch activeSegment {
        case "today":
            return eventViewModel.events.filter { event in
                Calendar.current.isDateInToday(event.date)
            }
        case "upcoming":
            return eventViewModel.events.filter { event in
                event.date > Date() && !Calendar.current.isDateInToday(event.date)
            }
        case "past":
            return eventViewModel.events.filter { event in
                event.date < Date()
            }
        default:
            return []
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                ZStack {
                    Color("pine")
                        .ignoresSafeArea()
                    
                    HStack {
                        Text("Events")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("beige"))
                        
                        Spacer()
                        
                        Button(action: {
                            showCreateEvent = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color("beige"))
                                .font(.title2)
                        }
                    }
                    .padding()
                }
                .frame(height: 60)
                
                // Segmented Control
                VStack(spacing: 16) {
                    HStack {
                        ForEach(segmentedOptions, id: \.self) { segment in
                            Button(action: {
                                withAnimation {
                                    activeSegment = segment
                                }
                            }) {
                                Text(segment.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        activeSegment == segment ?
                                        Color("beige") :
                                            Color.clear
                                    )
                                    .foregroundColor(
                                        activeSegment == segment ?
                                        Color("pine") :
                                        Color("beige")
                                    )
                            }
                        }
                    }
                    .padding(4)
                    .background(Color("pine"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Events List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredEvents) { event in
                            EventRowView(event: event)
                        }
                    }
                    .padding()
                }
                .background(Color("beige"))
            }
            .background(Color("beige"))
        }
        .sheet(isPresented: $showCreateEvent) {
            // TODO: Add CreateEventView here
            Text("Create Event")
        }
    }
}

struct EventRowView: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 16) {
            // Event Image
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: event.eventType == .walk ? "figure.walk" :
                            event.eventType == .bike ? "bicycle" : "figure.run")
                        .foregroundColor(Color("pine"))
                        .font(.system(size: 30))
                )
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("pine"))
                
                // Date and Time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(event.formattedDate())
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
                
                // Location
                HStack {
                    Image(systemName: "mappin")
                        .foregroundColor(.gray)
                    Text(event.description ?? "No location")
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
                
                // Participants
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.gray)
                    Text("\(event.attendeeIds.count) participants")
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Preview Provider
struct EventsView_Previews: PreviewProvider {
    static var previews: some View {
        EventsView(eventViewModel: EventViewModel())
    }
}