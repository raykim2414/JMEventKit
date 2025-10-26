//
//  JMEventKitError.swift
//  JMEventKit
//
//  Created by JMEventKit
//

import Foundation

/// Errors that can occur when using JMEventKit
public enum JMEventKitError: LocalizedError {
    /// Permission was denied by the user
    case permissionDenied

    /// Permission status is restricted (e.g., parental controls)
    case permissionRestricted

    /// Reminder not found with the given identifier
    case reminderNotFound

    /// Failed to create a reminder
    case reminderCreationFailed

    /// Failed to delete a reminder
    case reminderDeletionFailed

    /// Failed to update a reminder
    case reminderUpdateFailed

    /// Failed to save changes to the event store
    case saveFailed(any Error)

    /// Failed to fetch reminders
    case fetchFailed(any Error)

    /// Invalid configuration or parameters
    case invalidConfiguration(String)

    /// Calendar not found
    case calendarNotFound

    /// Unknown error occurred
    case unknown(any Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access reminders was denied. Please grant access in Settings."
        case .permissionRestricted:
            return "Access to reminders is restricted on this device."
        case .reminderNotFound:
            return "The requested reminder could not be found."
        case .reminderCreationFailed:
            return "Failed to create reminder. Please try again."
        case .reminderDeletionFailed:
            return "Failed to delete reminder. Please try again."
        case .reminderUpdateFailed:
            return "Failed to update reminder. Please try again."
        case .saveFailed(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch reminders: \(error.localizedDescription)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .calendarNotFound:
            return "Default reminders calendar could not be found."
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "User did not grant permission to access reminders."
        case .permissionRestricted:
            return "Device restrictions prevent access to reminders."
        case .reminderNotFound:
            return "Reminder identifier does not exist in the event store."
        case .saveFailed(let error), .fetchFailed(let error), .unknown(let error):
            return error.localizedDescription
        case .invalidConfiguration(let message):
            return message
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Reminders and enable access for this app."
        case .permissionRestricted:
            return "Check device restrictions in Settings > Screen Time."
        case .reminderNotFound:
            return "Verify the reminder still exists and try refreshing."
        case .calendarNotFound:
            return "Create a default reminders list in the Reminders app."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}
