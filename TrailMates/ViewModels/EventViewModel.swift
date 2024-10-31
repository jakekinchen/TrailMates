//
//  EventViewModel.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/21/24.
//


import SwiftUI
import Combine
import CoreLocation

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []

    func createEvent(
        for user: User,
        title: String,
        description: String?,
        location: CLLocationCoordinate2D,
        date: Date,
        isPrivate: Bool,
        eventType: Event.EventType = .walk, // Added with default value
        walkTags: [String]? = nil // Added with default value
    ) {
        let newEvent = Event(
            eventType: eventType,
            id: UUID(),
            title: title,
            description: description,
            location: location,
            date: date,
            hostId: user.id,
            attendeeIds: [],
            isActive: true,
            isPrivate: isPrivate,
            walkTags: walkTags
        )
        events.append(newEvent)
    }

    // Rest of the implementation remains the same
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

    // Additional helper methods
    func fetchEventsForUser(_ user: User) -> [Event] {
        return events.filter { event in
            event.hostId == user.id || event.attendeeIds.contains(user.id)
        }
    }
    
    func fetchPublicEvents() -> [Event] {
        return events.filter { !$0.isPrivate }
    }
    
    func fetchEventsByType(_ type: Event.EventType) -> [Event] {
        return events.filter { $0.eventType == type }
    }
}
