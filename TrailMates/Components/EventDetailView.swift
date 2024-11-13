//
//  EventDetailView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/22/24.
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    @ObservedObject var eventViewModel: EventViewModel
    @EnvironmentObject var userManager: UserManager
    @State private var camera: MapCameraPosition

    @Environment(\.dismiss) var dismiss

    private var currentUser: User? {
        userManager.currentUser
    }

    private var isUserAttending: Bool {
        guard let currentUser = currentUser else { return false }
        return event.attendeeIds.contains(currentUser.id)
    }

    private var isHostedByUser: Bool {
        guard let currentUser = currentUser else { return false }
        return event.hostId == currentUser.id
    }

    init(event: Event, eventViewModel: EventViewModel) {
        self.event = event
        self.eventViewModel = eventViewModel
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: event.location,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
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
                    DetailRow(icon: "mappin", text: event.description ?? "No description")
                    DetailRow(icon: "person.2", text: "\(event.attendeeIds.count) participants")
                    if event.isPrivate {
                        DetailRow(icon: "lock", text: "Private Event")
                    }
                }

                // Map Preview
                Map(position: $camera) {
                    Annotation("Event Location", coordinate: event.location) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(Color("pine"))
                            .font(.title)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)

                // Action Buttons
                if let currentUser = currentUser {
                    if !isHostedByUser {
                        Button {
                            if isUserAttending {
                                // User leaves the event
                                userManager.leaveEvent(eventId: event.id)
                                eventViewModel.removeAttendee(userId: currentUser.id, fromEvent: event.id)
                            } else {
                                // User joins the event
                                userManager.attendEvent(eventId: event.id)
                                eventViewModel.addAttendee(userId: currentUser.id, toEvent: event.id)
                            }
                        } label: {
                            Text(isUserAttending ? "Leave Event" : "Join Event")
                                .font(.headline)
                                .foregroundColor(Color("beige"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isUserAttending ? Color.red : Color("pumpkin"))
                                .cornerRadius(12)
                        }
                    } else {
                        Button {
                            if eventViewModel.cancelEvent(eventId: event.id, hostId: currentUser.id) {
                                dismiss()
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
}

struct DetailRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("pine"))
            Text(text)
                .foregroundColor(.gray)
        }
    }
}
