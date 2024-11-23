import Foundation
import CoreLocation
import UIKit

// MARK: - Mock Data Structure
struct MockData {
    // Static user IDs for consistent references
    static let currentUserId = UUID()
    static let friend1Id = UUID()
    static let friend2Id = UUID()
    static let friend3Id = UUID()
    static let friend4Id = UUID()
    
    // Static event IDs
    static let event1Id = UUID()
    static let event2Id = UUID()
    static let event3Id = UUID()
    static let event4Id = UUID()
    static let event5Id = UUID()
    static let event6Id = UUID()
    
    // MARK: - Users
    static let users: [UUID: User] = {
        var users = [UUID: User]()
        
        // Load profile images
        let currentUserImage = UIImage(named: "jakeProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend1Image = UIImage(named: "collinProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend2Image = UIImage(named: "nancyProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend3Image = UIImage(named: "alexProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend4Image = UIImage(named: "sarahProfilePic")?.jpegData(compressionQuality: 0.8)
        
        // Create users with static IDs for consistent references
        let currentUser = User(
            id: currentUserId,
            firstName: "Jake",
            lastName: "Kinchen",
            username: "jkinchen",
            profileImageData: currentUserImage,
            isActive: true,
            friends: [friend1Id, friend2Id, friend4Id],
            doNotDisturb: false,
            phoneNumber: "123-456-7890",
            createdEventIds: [],
            attendingEventIds: [event1Id, event4Id],
            joinDate: Date(),
            visitedLandmarkIds: [],
            location: Locations.shoalBeach
        )
        
        let friend1 = User(
            id: friend1Id,
            firstName: "Collin",
            lastName: "Nelson",
            username: "CNels",
            profileImageData: friend1Image,
            isActive: true,
            friends: [currentUserId, friend2Id],
            doNotDisturb: false,
            phoneNumber: "234-567-8901",
            createdEventIds: [event2Id],
            attendingEventIds: [event1Id, event2Id, event5Id],
            joinDate: Date(),
            visitedLandmarkIds: [],
            location: Locations.shoalBeach
        )
        
        let friend2 = User(
            id: friend2Id,
            firstName: "Nancy",
            lastName: "Melancon",
            username: "fanciestnancy",
            profileImageData: friend2Image,
            isActive: true,
            friends: [currentUserId, friend1Id, friend4Id],
            doNotDisturb: false,
            phoneNumber: "345-678-9012",
            createdEventIds: [event3Id, event6Id],
            attendingEventIds: [event3Id, event6Id],
            joinDate: Date(),
            visitedLandmarkIds: [],
            location: Locations.austinHighBoatLaunch
        )
        
        let friend3 = User(
            id: friend3Id,
            firstName: "Alex",
            lastName: "Johnson",
            username: "ajohns",
            profileImageData: friend3Image,
            isActive: true,
            friends: [friend4Id],
            doNotDisturb: true,
            phoneNumber: "456-789-0123",
            createdEventIds: [],
            attendingEventIds: [event2Id, event5Id],
            joinDate: Date(),
            visitedLandmarkIds: [],
            location: Locations.pflugerPedestrianBridge
        )
        
        let friend4 = User(
            id: friend4Id,
            firstName: "Sarah",
            lastName: "Lee",
            username: "sarahlee",
            profileImageData: friend4Image,
            isActive: false,
            friends: [currentUserId, friend2Id, friend3Id],
            doNotDisturb: false,
            phoneNumber: "567-890-1234",
            createdEventIds: [event5Id],
            attendingEventIds: [event4Id, event5Id, event6Id],
            joinDate: Date(),
            visitedLandmarkIds: [],
            location: Locations.austinHighBoatLaunch
        )
        
        // Add users to dictionary
        users[currentUserId] = currentUser
        users[friend1Id] = friend1
        users[friend2Id] = friend2
        users[friend3Id] = friend3
        users[friend4Id] = friend4
        
        return users
    }()
    
    // MARK: - Events
    static let events: [UUID: Event] = {
        var events = [UUID: Event]()
        
        let event1 = Event(
            id: event1Id,
            title: "Morning Trail Walk",
            description: "Casual morning walk around Lady Bird Lake",
            location: Locations.shoalBeach,
            dateTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            hostId: currentUserId,
            eventType: .walk,
            isPublic: false,
            tags: ["Casual", "Social", "Nature"],
            attendeeIds: Set([currentUserId, friend1Id]),
            status: .upcoming
        )
        
        let event2 = Event(
            id: event2Id,
            title: "Afternoon Run",
            description: "Training run - moderate pace",
            location: Locations.shoalBeach,
            dateTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            hostId: friend1Id,
            eventType: .run,
            isPublic: false,
            tags: ["Training", "Fast-Paced"],
            attendeeIds: Set([friend1Id, currentUserId, friend3Id]),
            status: .upcoming
        )
        
        let event3 = Event(
            id: event3Id,
            title: "Weekend Ride",
            description: "Scenic bike ride around the trail",
            location: Locations.pflugerPedestrianBridge,
            dateTime: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            hostId: friend2Id,
            eventType: .bike,
            isPublic: true,
            tags: ["Scenic", "Social"],
            attendeeIds: Set([friend2Id]),
            status: .upcoming
        )
        
        let event4 = Event(
            id: event4Id,
            title: "Evening Lake Stroll",
            description: "Relaxing walk by the lake at sunset",
            location: Locations.shoalBeach,
            dateTime: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            hostId: currentUserId,
            eventType: .walk,
            isPublic: false,
            tags: ["Relaxing", "Sunset"],
            attendeeIds: Set([currentUserId, friend4Id]),
            status: .upcoming
        )
        
        let event5 = Event(
            id: event5Id,
            title: "Hill Country Hike",
            description: "Challenging hike in the hills",
            location: Locations.louNeffPoint,
            dateTime: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            hostId: friend4Id,
            eventType: .bike,
            isPublic: false,
            tags: ["Challenging", "Hills"],
            attendeeIds: Set([friend1Id, friend3Id, friend4Id]),
            status: .upcoming
        )
        
        let event6 = Event(
            id: event6Id,
            title: "Lady Bird Lake Kayaking",
            description: "Kayaking trip around Lady Bird Lake",
            location: Locations.austinHighBoatLaunch,
            dateTime: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            hostId: friend2Id,
            eventType: .walk,
            isPublic: false,
            tags: ["Water", "Adventure", "Group"],
            attendeeIds: Set([currentUserId, friend2Id, friend4Id]),
            status: .upcoming
        )
        
        events[event1Id] = event1
        events[event2Id] = event2
        events[event3Id] = event3
        events[event4Id] = event4
        events[event5Id] = event5
        events[event6Id] = event6
        
        return events
    }()
    
}
