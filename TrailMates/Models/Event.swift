//
//  Event.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/21/24.
//

import Foundation
import CoreLocation

// Event Model - Sendable compliant as a struct with Sendable properties
struct Event: Codable, Identifiable, Sendable {
    // Core properties
    let id: String
    var title: String
    var description: String?
    var location: CLLocationCoordinate2D
    var dateTime: Date
    var hostId: String
    
    // Event configuration
    var eventType: EventType
    var isPublic: Bool
    var tags: [String]
    
    // Attendance tracking
    var attendeeIds: Set<String>
    
    // Status
    var status: EventStatus
    
    enum EventType: String, Codable {
        case walk, bike, run
    }
    
    enum EventStatus: String, Codable {
        case upcoming   // Future event
        case active    // Currently happening
        case completed // Past event
        case canceled  // Canceled event
    }
}

// Event Utility Functions
extension Event {
    func isUpcoming() -> Bool {
        return dateTime > Date()
    }

    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }
    
    
}
