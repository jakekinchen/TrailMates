//
//  SharingService.swift
//  TrailMatesATX
//
//  Extracted UIKit interop code for maps and calendar integration.
//

import SwiftUI
import MapKit
import EventKit
import EventKitUI

// MARK: - SharingService

struct SharingService {

    // MARK: - Open in Maps

    /// Presents an action sheet allowing the user to open a location in Apple Maps or Google Maps.
    static func openInMaps(coordinate: CLLocationCoordinate2D, title: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title

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
                    UIApplication.shared.open(url)
                } else {
                    // If Google Maps is not installed, open in browser
                    let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)"
                    if let webUrl = URL(string: webUrlString) {
                        UIApplication.shared.open(webUrl)
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        Self.presentAlert(alert)
    }

    // MARK: - Add to Calendar

    /// Presents an action sheet allowing the user to add an event to Apple Calendar or Google Calendar.
    static func addToCalendar(
        title: String,
        startDate: Date,
        endDate: Date,
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: TimeZone = .autoupdatingCurrent,
        editViewDelegate: EKEventEditViewDelegate
    ) {
        let alert = UIAlertController(title: "Add to Calendar", message: nil, preferredStyle: .actionSheet)

        // Apple Calendar option
        alert.addAction(UIAlertAction(title: "Apple Calendar", style: .default) { _ in
            let eventStore = EKEventStore()

            Task { @MainActor in
                do {
                    let granted: Bool
                    if #available(iOS 17.0, *) {
                        granted = try await eventStore.requestWriteOnlyAccessToEvents()
                    } else {
                        granted = try await eventStore.requestAccess(to: .event)
                    }
                    if granted {
                        Self.createCalendarEvent(
                            store: eventStore,
                            title: title,
                            startDate: startDate,
                            endDate: endDate,
                            locationName: locationName,
                            coordinate: coordinate,
                            timeZone: timeZone,
                            editViewDelegate: editViewDelegate
                        )
                    }
                } catch {
                    print("Calendar access error: \(error)")
                }
            }
        })

        // Google Calendar option
        alert.addAction(UIAlertAction(title: "Google Calendar", style: .default) { _ in
            let startString = googleCalendarDateString(from: startDate, timeZone: timeZone)
            let endString = googleCalendarDateString(from: endDate, timeZone: timeZone)

            var components = URLComponents(string: "https://calendar.google.com/calendar/render")
            components?.queryItems = [
                URLQueryItem(name: "action", value: "TEMPLATE"),
                URLQueryItem(name: "text", value: title),
                URLQueryItem(name: "dates", value: "\(startString)/\(endString)"),
                URLQueryItem(name: "ctz", value: timeZone.identifier),
                URLQueryItem(name: "location", value: locationName)
            ]

            if let url = components?.url {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        Self.presentAlert(alert)
    }

    // MARK: - Private Helpers

    private static func createCalendarEvent(
        store: EKEventStore,
        title: String,
        startDate: Date,
        endDate: Date,
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: TimeZone,
        editViewDelegate: EKEventEditViewDelegate
    ) {
        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = title
        calendarEvent.startDate = startDate
        calendarEvent.endDate = endDate
        calendarEvent.timeZone = timeZone

        // Set the structured location with coordinates
        let structuredLocation = EKStructuredLocation(title: locationName)
        structuredLocation.geoLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        calendarEvent.structuredLocation = structuredLocation

        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            print("Failed to get default calendar")
            return
        }

        calendarEvent.calendar = defaultCalendar

        let eventViewController = EKEventEditViewController()
        eventViewController.event = calendarEvent
        eventViewController.eventStore = store
        eventViewController.editViewDelegate = editViewDelegate

        Self.presentViewController(eventViewController)
    }

    private static let googleCalendarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter
    }()

    private static func googleCalendarDateString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = Self.googleCalendarFormatter
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private static func presentAlert(_ alert: UIAlertController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootController = windowScene.windows.first?.rootViewController {
            var topController = rootController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(alert, animated: true)
        }
    }

    private static func presentViewController(_ viewController: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootController = windowScene.windows.first?.rootViewController {
            var topController = rootController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(viewController, animated: true)
        }
    }
}
