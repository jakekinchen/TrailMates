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
    @State private var actionErrorMessage: String?
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

    private var eventExportTimeZone: TimeZone {
        TimeZone.autoupdatingCurrent
    }

    private var eventEndDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eventExportTimeZone
        return calendar.date(byAdding: .hour, value: 1, to: event.dateTime) ?? event.dateTime
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
                            .foregroundColor(AppColors.pine)

                        Text("Hosted by \(isHostedByUser ? "You" : "Friend")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    Image(systemName: event.eventType == .walk ? "figure.walk" :
                            event.eventType == .bike ? "bicycle" : "figure.run")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.pine)
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
                            .tint(AppColors.pine)
                }
                .frame(height: 200)
                .cornerRadius(12)
                .accessibilityLabel("Map preview")
                .accessibilityHint("Double tap to open in Maps")
                .onTapGesture {
                    openInMaps(coordinate: event.location)
                }

                // Action Buttons
                if let currentUser = currentUser {
                                if !isHostedByUser {
                                    Button {
                                        Task {
                                            await toggleAttendance(for: currentUser)
                                        }
                                    } label: {
                                        Text(isUserAttending ? "Leave Event" : "Join Event")
                                            .font(.headline)
                                            .foregroundColor(AppColors.alwaysBeige)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(isUserAttending ? Color.red : AppColors.pumpkin)
                                            .cornerRadius(12)
                                    }
                                } else {
                                        Button {
                                            Task {
                                                await cancelEvent(for: currentUser)
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
                                                .foregroundColor(AppColors.pine)
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
                .foregroundColor(AppColors.pine)
            }
        }
        .alert("Event Error", isPresented: .init(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionErrorMessage ?? "An unknown error occurred")
        }
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        SharingService.openInMaps(coordinate: coordinate, title: event.title)
    }

    private func addToCalendar() {
        SharingService.addToCalendar(
            title: event.title,
            startDate: event.dateTime,
            endDate: eventEndDate,
            locationName: event.getLocationName(),
            coordinate: event.location,
            timeZone: eventExportTimeZone,
            editViewDelegate: eventEditViewDelegate
        )
    }

    private func toggleAttendance(for currentUser: User) async {
        do {
            if isUserAttending {
                try await eventViewModel.leaveEvent(userId: currentUser.id, eventId: event.id)
                try await userManager.leaveEvent(event.id)
                localAttendeeIds.remove(currentUser.id)
            } else {
                try await eventViewModel.attendEvent(userId: currentUser.id, eventId: event.id)
                try await userManager.attendEvent(event.id)
                localAttendeeIds.insert(currentUser.id)
            }
        } catch is CancellationError {
            return
        } catch {
            actionErrorMessage = AppError.classify(error).errorDescription ?? "Unable to update this event."
        }
    }

    private func cancelEvent(for currentUser: User) async {
        do {
            if try await eventViewModel.cancelEvent(eventId: event.id, hostId: currentUser.id) {
                dismiss()
            }
        } catch is CancellationError {
            return
        } catch {
            actionErrorMessage = AppError.classify(error).errorDescription ?? "Unable to cancel this event."
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
                .foregroundColor(AppColors.pine)
                .frame(width: 24, alignment: .center) // Fixed width for icons
                .padding(.trailing, 12)  // Consistent spacing after icons
            
            Text(text)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
        }
    }
}
