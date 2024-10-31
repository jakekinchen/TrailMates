//
//  Event.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/21/24.
//

import Foundation
import CoreLocation

// Event Model
struct Event: Codable, Identifiable {
    enum EventType: String, Codable {
           case walk, bike, run
       }
    var eventType: EventType
    let id: UUID
    var title: String
    var description: String?
    var location: CLLocationCoordinate2D
    var date: Date
    var hostId: UUID
    var attendeeIds: [UUID]
    var isActive: Bool
    var isPrivate: Bool
    var walkTags: [String]?
}

// Event Utility Functions
extension Event {
    func isUpcoming() -> Bool {
        return date > Date()
    }

    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
