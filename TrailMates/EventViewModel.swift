import SwiftUI
import Combine

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []

    func createEvent(for user: User, title: String, description: String?, location: CLLocationCoordinate2D, date: Date, isPrivate: Bool) {
        let newEvent = Event(
            id: UUID(),
            title: title,
            description: description,
            location: location,
            date: date,
            hostId: user.id,
            attendeeIds: [],
            isActive: true,
            isPrivate: isPrivate
        )
        events.append(newEvent)
    }

    func attendEvent(user: inout User, event: Event) {
        guard !user.attendingEventIds.contains(event.id) else { return }
        user.attendingEventIds.append(event.id)
        
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].attendeeIds.append(user.id)
        }
    }

    func cancelEvent(user: inout User, event: Event) {
        guard let index = events.firstIndex(where: { $0.id == event.id && $0.hostId == user.id }) else { return }
        events.remove(at: index)
    }

    func leaveEvent(user: inout User, event: Event) {
        guard let userIndex = user.attendingEventIds.firstIndex(of: event.id) else { return }
        user.attendingEventIds.remove(at: userIndex)

        if let eventIndex = events.firstIndex(where: { $0.id == event.id }) {
            if let attendeeIndex = events[eventIndex].attendeeIds.firstIndex(of: user.id) {
                events[eventIndex].attendeeIds.remove(at: attendeeIndex)
            }
        }
    }
}