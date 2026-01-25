//
//  PermissionStatus.swift
//  TrailMates
//
//  Enum representing the various states of app permissions.
//
//  Usage:
//  ```swift
//  @State private var locationStatus: PermissionStatus = .notRequested
//
//  switch locationStatus {
//  case .granted: // Full access granted
//  case .partial: // Limited access (e.g., "When In Use" only)
//  case .denied:  // User denied permission
//  case .notRequested: // Permission not yet requested
//  }
//  ```

import Foundation

/// Represents the authorization state of a system permission
enum PermissionStatus {
    /// Permission has not been requested yet
    case notRequested
    /// Full permission has been granted
    case granted
    /// Permission has been denied by the user
    case denied
    /// Partial or limited permission granted
    case partial
}