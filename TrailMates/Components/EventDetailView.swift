//
//  EventDetailView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/22/24.
//

import SwiftUI
import MapKit
import EventKit
import EventKitUI

struct EventDetailView: View {
    let event: Event
    @ObservedObject var eventViewModel: EventViewModel
    @EnvironmentObject var userManager: UserManager
    @State private var camera: MapCameraPosition
    @State private var localAttendeeIds: Set<String>
    private let eventEditViewDelegate = EventEditViewDelegate()
        
        init(event: Event, eventViewModel: EventViewModel) {
            self.event = event
            self.eventViewModel = eventViewModel
            _camera = State(initialValue: .region(MKCoordinateRegion(
                center: event.location,
                span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0075)
            )))
            _localAttendeeIds = State(initialValue: event.attendeeIds) // Initialize with event's attendees
        }

    @Environment(\.dismiss) var dismiss

    private var currentUser: User? {
        userManager.currentUser
    }

    private var isUserAttending: Bool {
            guard let currentUser = currentUser else { return false }
            return localAttendeeIds.contains(currentUser.id) // Use local state instead of event.attendeeIds
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
                    DetailRow(icon: "mappin", text: event.getLocationName())
                    DetailRow(icon: "person.2", text: "\(localAttendeeIds.count) participants")
                    if event.isPublic {
                        DetailRow(icon: "lock", text: "Public Event")
                    }
                }

                // Map Preview
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: event.location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))), interactionModes: []) {
                    Marker(event.getLocationName(), coordinate: event.location)
                            .tint(Color("pine"))
                }
                .frame(height: 200)
                .cornerRadius(12)
                .onTapGesture {
                    openInMaps(coordinate: event.location)
                }

                // Action Buttons
                if let currentUser = currentUser {
                                if !isHostedByUser {
                                    Button {
                                        Task {
                                            if isUserAttending {
                                                try await eventViewModel.leaveEvent(userId: currentUser.id, eventId: event.id)
                                                try await userManager.leaveEvent(event.id)
                                                localAttendeeIds.remove(currentUser.id) // Update local state
                                            } else {
                                                try await eventViewModel.attendEvent(userId: currentUser.id, eventId: event.id)
                                                try await userManager.attendEvent(event.id)
                                                localAttendeeIds.insert(currentUser.id) // Update local state
                                            }
                                        }
                                    } label: {
                                        Text(isUserAttending ? "Leave Event" : "Join Event")
                                            .font(.headline)
                                            .foregroundColor(Color("alwaysBeige"))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(isUserAttending ? Color.red : Color("pumpkin"))
                                            .cornerRadius(12)
                                    }
                                } else {
                                        Button {
                                            Task {
                                                if try await eventViewModel.cancelEvent(eventId: event.id, hostId: currentUser.id) {
                                                    dismiss()
                                                }
                                            }
                                        } label: {
                                            Text("Cancel Event")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.red)
                                                .cornerRadius(12)
                                        }
                                    }
                                    if isUserAttending || isHostedByUser {
                                        Button {
                                            addToCalendar()
                                        } label: {
                                            Text("Add to Calendar")
                                                .font(.headline)
                                                .foregroundColor(Color("pine"))
                                                .frame(maxWidth: .infinity)
                                                .padding(.top, 8)
                                        }
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
    
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.title

        let alert = UIAlertController(title: "Open in Maps", message: nil, preferredStyle: .actionSheet)

        // Apple Maps option
        alert.addAction(UIAlertAction(title: "Apple Maps", style: .default) { _ in
            mapItem.openInMaps()
        })

        // Google Maps option
        alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { _ in
            let urlString = "comgooglemaps://?saddr=&daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving"
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url)
                    }
                } else {
                    // If Google Maps is not installed, open in browser
                    let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)"
                    if let webUrl = URL(string: webUrlString) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(webUrl)
                        }
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Find the topmost view controller to present the alert
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootController = windowScene.windows.first?.rootViewController {
                // Traverse to the topmost presented view controller
                var topController = rootController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(alert, animated: true)
            }
        }
    }
    
    private func addToCalendar() {
        let alert = UIAlertController(title: "Add to Calendar", message: nil, preferredStyle: .actionSheet)
            
            // Apple Calendar option
            alert.addAction(UIAlertAction(title: "Apple Calendar", style: .default) { _ in
                let eventStore = EKEventStore()
                
                // Handle calendar access based on iOS version
                if #available(iOS 17.0, *) {
                    // Use new iOS 17 API
                    eventStore.requestWriteOnlyAccessToEvents { granted, error in
                        if granted {
                            DispatchQueue.main.async {
                                self.createCalendarEvent(store: eventStore)
                            }
                        }
                    }
                } else {
                    // Use older API for iOS 16 and below
                    eventStore.requestAccess(to: .event) { granted, error in
                        if granted {
                            DispatchQueue.main.async {
                                self.createCalendarEvent(store: eventStore)
                            }
                        }
                    }
                }
            })
        
        // Google Calendar option
        alert.addAction(UIAlertAction(title: "Google Calendar", style: .default) { _ in
            let title = event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let location = event.getLocationName().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            let dateFormatter = ISO8601DateFormatter()
            let startDate = dateFormatter.string(from: event.dateTime)
            let endDate = dateFormatter.string(from: Calendar.current.date(byAdding: .hour, value: 1, to: event.dateTime) ?? event.dateTime)
            
            let urlString = "https://calendar.google.com/calendar/render?action=TEMPLATE&text=\(title)&dates=\(startDate)/\(endDate)&location=\(location)"
            
            if let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootController = windowScene.windows.first?.rootViewController {
                var topController = rootController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(alert, animated: true)
            }
        }
    }
    
    private func createCalendarEvent(store: EKEventStore) {
        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.title
        calendarEvent.startDate = event.dateTime
        calendarEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.dateTime) ?? event.dateTime

        // Set the structured location with coordinates
        let structuredLocation = EKStructuredLocation(title: event.getLocationName())
        structuredLocation.geoLocation = CLLocation(latitude: event.location.latitude, longitude: event.location.longitude)
        calendarEvent.structuredLocation = structuredLocation

        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            print("Failed to get default calendar")
            return
        }

        calendarEvent.calendar = defaultCalendar

        let eventViewController = EKEventEditViewController()
        eventViewController.event = calendarEvent
        eventViewController.eventStore = store
        eventViewController.editViewDelegate = eventEditViewDelegate

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootController = windowScene.windows.first?.rootViewController {
            var topController = rootController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(eventViewController, animated: true)
        }
    }
    
}

class EventEditViewDelegate: NSObject, EKEventEditViewDelegate {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true)
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: icon)
                .foregroundColor(Color("pine"))
                .frame(width: 24, alignment: .center) // Fixed width for icons
                .padding(.trailing, 12)  // Consistent spacing after icons
            
            Text(text)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
        }
    }
}
