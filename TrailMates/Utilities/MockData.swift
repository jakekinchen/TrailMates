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
    
    // Static event IDs
    static let event1Id = UUID()
    static let event2Id = UUID()
    static let event3Id = UUID()
    
    // MARK: - Users
    @MainActor
    static let users: [UUID: User] = {
        var users = [UUID: User]()
        
        // Load profile images
        let currentUserImage = UIImage(named: "jakeProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend1Image = UIImage(named: "collinProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend2Image = UIImage(named: "nancyProfilePic")?.jpegData(compressionQuality: 0.8)
        let friend3Image = UIImage(named: "alexProfilePic")?.jpegData(compressionQuality: 0.8)
        
        // Create users with static IDs for consistent references
        let currentUser = User(
            id: currentUserId,
            firstName: "Jake",
            lastName: "Kinchen",
            bio: "App developer and outdoor enthusiast.",
            profileImageData: currentUserImage,
            location: Locations.shoalBeach,
            isActive: true,
            friends: [friend1Id, friend2Id],
            doNotDisturb: false,
            phoneNumber: "123-456-7890",
            createdEventIds: [event1Id],
            attendingEventIds: [event1Id, event2Id]
        )
        
        let friend1 = User(
            id: friend1Id,
            firstName: "Collin",
            lastName: "Nelson",
            bio: "Love hiking with friends.",
            profileImageData: friend1Image,
            location: Locations.seaholmPicnicRing,
            isActive: true,
            friends: [currentUserId, friend2Id],
            doNotDisturb: false,
            phoneNumber: "234-567-8901",
            createdEventIds: [event2Id],
            attendingEventIds: [event1Id, event2Id]
        )
        
        let friend2 = User(
            id: friend2Id,
            firstName: "Nancy",
            lastName: "Melancon",
            bio: "Nature lover and trail walker.",
            profileImageData: friend2Image,
            location: Locations.austinHighBoatLaunch,
            isActive: false,
            friends: [currentUserId, friend1Id],
            doNotDisturb: false,
            phoneNumber: "345-678-9012",
            createdEventIds: [event3Id],
            attendingEventIds: [event3Id]
        )
        
        let friend3 = User(
            id: friend3Id,
            firstName: "Alex",
            lastName: "Johnson",
            bio: "Trail running enthusiast",
            profileImageData: friend3Image,
            location: Locations.pflugerPedestrianBridge,
            isActive: true,
            friends: [],
            doNotDisturb: true,
            phoneNumber: "456-789-0123",
            createdEventIds: [],
            attendingEventIds: [event2Id]
        )
        
        users[currentUserId] = currentUser
        users[friend1Id] = friend1
        users[friend2Id] = friend2
        users[friend3Id] = friend3
        
        return users
    }()
    
    // MARK: - Events
    @MainActor
    static let events: [UUID: Event] = {
        var events = [UUID: Event]()
        
        let event1 = Event(
            eventType: .walk,
            id: event1Id,
            title: "Morning Trail Walk",
            description: "Casual morning walk around Lady Bird Lake",
            location: Locations.shoalBeach,
            date: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            hostId: currentUserId,
            attendeeIds: [currentUserId, friend1Id],
            isActive: true,
            isPrivate: false,
            walkTags: ["Casual", "Social", "Nature"]
        )
        
        let event2 = Event(
            eventType: .run,
            id: event2Id,
            title: "Afternoon Run",
            description: "Training run - moderate pace",
            location: Locations.seaholmPicnicRing,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            hostId: friend1Id,
            attendeeIds: [friend1Id, currentUserId, friend3Id],
            isActive: true,
            isPrivate: false,
            walkTags: ["Training", "Fast-Paced"]
        )
        
        let event3 = Event(
            eventType: .bike,
            id: event3Id,
            title: "Weekend Ride",
            description: "Scenic bike ride around the trail",
            location: Locations.pflugerPedestrianBridge,
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            hostId: friend2Id,
            attendeeIds: [friend2Id],
            isActive: true,
            isPrivate: true,
            walkTags: ["Scenic", "Social"]
        )
        
        events[event1Id] = event1
        events[event2Id] = event2
        events[event3Id] = event3
        
        return events
    }()
    
    // MARK: - Common Locations
    struct Locations {
        static let shoalBeach = CLLocationCoordinate2D(latitude: 30.26466, longitude: -97.75160)
        static let seaholmPicnicRing = CLLocationCoordinate2D(latitude: 30.26659, longitude: -97.75401)
        static let austinHighBoatLaunch = CLLocationCoordinate2D(latitude: 30.27041, longitude: -97.76594)
        static let texasRowingCenter = CLLocationCoordinate2D(latitude: 30.27208, longitude: -97.76892)
        static let moPacBridgeNorthEntry = CLLocationCoordinate2D(latitude: 30.27484, longitude: -97.77066)
        static let moPacBridgeSouthEntry = CLLocationCoordinate2D(latitude: 30.27284, longitude: -97.77213)
        static let louNeffPoint = CLLocationCoordinate2D(latitude: 30.26721, longitude: -97.76179)
        static let pflugerPedestrianBridge = CLLocationCoordinate2D(latitude: 30.26546, longitude: -97.75587)
        static let stevieRayVaughanStatue = CLLocationCoordinate2D(latitude: 30.26310, longitude: -97.75068)
        static let allianceChildrensGarden = CLLocationCoordinate2D(latitude: 30.26238, longitude: -97.74872)
        static let bufordTowerOverlook = CLLocationCoordinate2D(latitude: 30.26332, longitude: -97.74596)
        static let shoalBeachTreeCanopy = CLLocationCoordinate2D(latitude: 30.26418, longitude: -97.75015)
        static let batObservationDeck = CLLocationCoordinate2D(latitude: 30.26243, longitude: -97.74468)
        static let austinRowingClubPavilion = CLLocationCoordinate2D(latitude: 30.26071, longitude: -97.74192)
        static let blunnCreekObservationDeck = CLLocationCoordinate2D(latitude: 30.25228, longitude: -97.74033)
        static let eastBouldinCreekObservationDeck = CLLocationCoordinate2D(latitude: 30.25455, longitude: -97.74195)
        static let i35ObservationDeckA = CLLocationCoordinate2D(latitude: 30.24897, longitude: -97.73342)
        static let i35ObservationDeckB = CLLocationCoordinate2D(latitude: 30.24833, longitude: -97.73203)
        static let i35ObservationDeckC = CLLocationCoordinate2D(latitude: 30.24768, longitude: -97.73080)
        static let johnZenorPicnicPavilion = CLLocationCoordinate2D(latitude: 30.24644, longitude: -97.72065)
        static let peacePoint = CLLocationCoordinate2D(latitude: 30.24557, longitude: -97.72291)
        static let longhornShores = CLLocationCoordinate2D(latitude: 30.24654, longitude: -97.71523)
        static let underI35North = CLLocationCoordinate2D(latitude: 30.25145, longitude: -97.73590)
        static let raineyStreetTrailhead = CLLocationCoordinate2D(latitude: 30.255573, longitude: -97.739888)
        static let edwardRendonSrParkingLot = CLLocationCoordinate2D(latitude: 30.25039, longitude: -97.73202)
        static let festivalBeachBoatRamp = CLLocationCoordinate2D(latitude: 30.24842, longitude: -97.72787)
        static let internationalShores = CLLocationCoordinate2D(latitude: 30.24543, longitude: -97.72624)
    }
}
