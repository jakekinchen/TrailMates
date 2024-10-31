struct EventListView: View {
    @ObservedObject var eventViewModel: EventViewModel
    @State var user: User

    var body: some View {
        List(eventViewModel.events) { event in
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                Text("Date: \(event.date.formatted())")
                if let location = event.location {
                    Text("Location: \(location.latitude), \(location.longitude)")
                }
                Button(action: {
                    if user.attendingEventIds.contains(event.id) {
                        eventViewModel.leaveEvent(user: &user, event: event)
                    } else {
                        eventViewModel.attendEvent(user: &user, event: event)
                    }
                }) {
                    Text(user.attendingEventIds.contains(event.id) ? "Leave Event" : "Join Event")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Events")
    }
}