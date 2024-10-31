//
//  Friend.swift
//  TrailMates
//
//  Created by Jake Kinchen on 10/3/24.
//


import Foundation
import CoreLocation // To use CLLocationCoordinate2D

struct Friend: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let coordinate: CLLocationCoordinate2D
    let profileImageName: String
    let isActive: Bool
    let doNotDisturb: Bool
    let phoneNumber: String
}
