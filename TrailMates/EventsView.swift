//
//  EventsView.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 10/22/24.
//

import SwiftUI

struct EventsView: View {
    @ObservedObject var eventViewModel: EventViewModel
    @EnvironmentObject var userManager: UserManager
    @State private var activeSegment = "circle"
    @State private var showCreateEvent = false
    @State private var showEventDetails = false
    @State private var selectedEvent: Event?
    @State private var showOnlyMyEvents = false
    
    // MARK: - Event Filtering and Grouping
    
    struct EventGroup: Identifiable {
        let id = UUID()
        let title: String
        let events: [Event]
    }
    
    private func getFilteredEvents() -> [Event] {
            guard let currentUser = userManager.currentUser else { return [] }
            return eventViewModel.getFilteredEvents(
                for: currentUser,
                activeSegment: activeSegment,
                showOnlyMyEvents: showOnlyMyEvents
            )
        }
        
        private func emptyStateView() -> some View {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(Color("pine"))
                
                Text(emptyStateMessage)
                    .font(.headline)
                    .foregroundColor(Color("pine"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
        }
        
        private var emptyStateMessage: String {
            switch activeSegment {
            case "circle":
                return "No events from your circle yet.\nConnect with more friends to see their events!"
            case "explore":
                return "No public events available.\nCheck back later for new events!"
            case "myEvents":
                return "You aren't hosting any upcoming events yet.\nTap the + button to get started!"
            default:
                return ""
            }
        }
    
    
    private func makeEventRow(_ event: Event) -> some View {
        EventRowView(
            event: event,
            currentUser: userManager.currentUser,
            onJoinTap: {
                if let userId = userManager.currentUser?.id {
                    Task {
                        try await eventViewModel.attendEvent(userId: userId, eventId: event.id)
                        userManager.attendEvent(eventId: event.id)
                    }
                }
            },
            onLeaveTap: {
                if let userId = userManager.currentUser?.id {
                    Task {
                        try await eventViewModel.leaveEvent(userId: userId, eventId: event.id)
                        userManager.leaveEvent(eventId: event.id)
                    }
                }
            }
        )
        .onTapGesture {
            selectedEvent = event
        }
    }
        
        private func makeGroupHeader(_ title: String) -> some View {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color("pine"))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color("beige"))
        }
        
    private func makeEventsList(_ groups: [EventGroup]) -> some View {
        LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(Color("pine"))
                    
                    Text(activeSegment == "circle" ?
                         "No events from your circle yet.\nConnect with more friends to see their events!" :
                         activeSegment == "explore" ?
                         "No public events available.\nCheck back later for new events!" :
                         "You haven't created any events yet.\nTap the + button to get started!")
                        .font(.headline)
                        .foregroundColor(Color("pine"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.events) { event in
                            makeEventRow(event)
                        }
                    } header: {
                        makeGroupHeader(group.title)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
        
        var body: some View {
            ZStack {
                Color("beige").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Segment Control
                    Picker("View", selection: $activeSegment) {
                        Text("My Circle").tag("circle")
                        Text("Explore").tag("explore")
                        Text("My Events").tag("myEvents")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    
                    ScrollView {
                        let filteredEvents = getFilteredEvents()
                        let groupedEvents = eventViewModel.groupEvents(filteredEvents)
                        makeEventsList(groupedEvents)
                    }
                }
                .withDefaultNavigation(
                    title: navigationTitle,
                    rightButtonIcon: "plus.circle.fill",
                    rightButtonAction: { showCreateEvent = true }
                )
            }
            .sheet(isPresented: $showCreateEvent) {
                if let user = userManager.currentUser {
                    CreateEventView(eventViewModel: eventViewModel, user: user)
                }
            }
            .sheet(item: $selectedEvent) { event in
                NavigationView {
                    EventDetailView(
                        event: event,
                        eventViewModel: eventViewModel
                    )
                }
            }
        }

    
    private var navigationTitle: String {
            switch activeSegment {
            case "circle":
                return "My Circle"
            case "explore":
                return "Explore Events"
            case "myEvents":
                return "My Events"
            default:
                return "TrailMates"
            }
        }
    
    private func sectionHeader(title: String) -> some View {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color("pine"))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Spacer()
            }
        
        }
}
