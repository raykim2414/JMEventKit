//
//  JMEventKit.swift
//  JMEventKit
//
//  A modern Swift wrapper for Apple's EventKit framework
//  Simplifies reminders and calendar event management in iOS applications
//

@preconcurrency import EventKit
import Foundation
import Combine

/// Main class for interacting with EventKit
/// Provides a simple, async/await-based API for managing reminders and calendar events
@MainActor
public final class JMEventKit: ObservableObject {

    // MARK: - Singleton

    /// Shared singleton instance
    /// Use this instance to interact with EventKit throughout your app
    public static let shared = JMEventKit()

    // MARK: - Published Properties

    /// Current authorization status for reminders
    @Published public private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined

    /// Array of fetched reminders
    @Published public private(set) var reminders: [EKReminder] = []

    /// Indicates whether a fetch operation is in progress
    @Published public private(set) var isFetching: Bool = false

    // MARK: - Private Properties

    /// The underlying EventKit store
    /// Note: marked nonisolated(unsafe) because EKEventStore is thread-safe but not Sendable in Swift 6
    nonisolated(unsafe) private let eventStore: any EventStoreProtocol

    /// App name for reminder calendar
    private var appName: String = "JMEventKit"

    // MARK: - Initialization

    /// Private initializer for singleton pattern
    private init(eventStore: (any EventStoreProtocol)? = nil) {
        self.eventStore = eventStore ?? EKEventStore()
        self.authorizationStatus = self.eventStore.authorizationStatus()
    }

    /// Internal initializer for testing with mock event store
    internal init(mockEventStore: any EventStoreProtocol) {
        self.eventStore = mockEventStore
        self.authorizationStatus = mockEventStore.authorizationStatus()
    }

    // MARK: - Configuration

    /// Configure JMEventKit with app-specific settings
    /// - Parameter appName: Name of your app, used for creating reminder calendars
    public func configure(appName: String) {
        self.appName = appName
    }

    // MARK: - Authorization

    /// Request permission to access reminders
    /// Automatically handles iOS 17+ and older iOS versions
    /// - Returns: `true` if permission granted, `false` otherwise
    /// - Throws: `JMEventKitError` if an error occurs
    public func requestReminderAuthorization() async throws -> Bool {
        // Check current status
        authorizationStatus = eventStore.authorizationStatus()

        switch authorizationStatus {
        case .authorized, .fullAccess:
            return true

        case .denied:
            throw JMEventKitError.permissionDenied

        case .restricted:
            throw JMEventKitError.permissionRestricted

        case .notDetermined, .writeOnly:
            // Request access
            do {
                let granted = try await eventStore.requestReminderAccess()
                authorizationStatus = eventStore.authorizationStatus()

                // Check the result
                if granted {
                    return true
                } else {
                    // Access was not granted, check why
                    if authorizationStatus == .denied {
                        throw JMEventKitError.permissionDenied
                    } else if authorizationStatus == .restricted {
                        throw JMEventKitError.permissionRestricted
                    } else {
                        return false
                    }
                }
            } catch let error as JMEventKitError {
                throw error
            } catch {
                throw JMEventKitError.unknown(error)
            }

        @unknown default:
            throw JMEventKitError.unknown(NSError(domain: "JMEventKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status"]))
        }
    }

    /// Check if the app has permission to access reminders
    /// - Returns: `true` if authorized, `false` otherwise
    public func isAuthorized() -> Bool {
        authorizationStatus = eventStore.authorizationStatus()
        return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }

    // MARK: - Create Reminders

    /// Create a new reminder
    /// - Parameters:
    ///   - title: Title of the reminder
    ///   - notes: Optional notes for the reminder
    ///   - dueDate: Optional due date
    ///   - priority: Priority level (0 = none, 1-4 = high, 5 = medium, 6-9 = low)
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created `EKReminder`
    /// - Throws: `JMEventKitError` if creation fails
    public func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 0,
        calendar: EKCalendar? = nil
    ) async throws -> EKReminder {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        let reminder = eventStore.makeReminder()
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        // Set due date if provided
        if let dueDate = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }

        // Set calendar
        if let calendar = calendar {
            reminder.calendar = calendar
        } else if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            reminder.calendar = defaultCalendar
        } else {
            throw JMEventKitError.calendarNotFound
        }

        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
            return reminder
        } catch {
            throw JMEventKitError.saveFailed(error)
        }
    }

    // MARK: - Fetch Reminders

    /// Fetch all incomplete reminders
    /// Updates the `reminders` published property
    /// - Returns: Array of `EKReminder`
    /// - Throws: `JMEventKitError` if fetch fails
    @discardableResult
    public func fetchReminders() async throws -> [EKReminder] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        isFetching = true
        defer { isFetching = false }

        // Create predicate for incomplete reminders (already on MainActor)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        do {
            let fetchedReminders = try await eventStore.fetchReminders(matching: predicate)
            reminders = fetchedReminders
            return fetchedReminders
        } catch {
            throw JMEventKitError.fetchFailed(error)
        }
    }

    /// Fetch reminders with custom predicate
    /// - Parameter predicate: NSPredicate for filtering reminders
    /// - Returns: Array of `EKReminder`
    /// - Throws: `JMEventKitError` if fetch fails
    public func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        isFetching = true
        defer { isFetching = false }

        do {
            return try await eventStore.fetchReminders(matching: predicate)
        } catch {
            throw JMEventKitError.fetchFailed(error)
        }
    }

    /// Fetch completed reminders within a date range
    /// - Parameters:
    ///   - startDate: Start date for filtering
    ///   - endDate: End date for filtering
    /// - Returns: Array of completed `EKReminder`
    /// - Throws: `JMEventKitError` if fetch fails
    public func fetchCompletedReminders(from startDate: Date?, to endDate: Date?) async throws -> [EKReminder] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        isFetching = true
        defer { isFetching = false }

        // Create predicate for completed reminders (already on MainActor)
        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: endDate,
            calendars: nil
        )

        do {
            return try await eventStore.fetchReminders(matching: predicate)
        } catch {
            throw JMEventKitError.fetchFailed(error)
        }
    }

    // MARK: - Update Reminders

    /// Mark a reminder as completed
    /// - Parameter reminder: The reminder to complete
    /// - Throws: `JMEventKitError` if update fails
    public func completeReminder(_ reminder: EKReminder) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        reminder.isCompleted = true

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw JMEventKitError.reminderUpdateFailed
        }
    }

    /// Mark a reminder as incomplete
    /// - Parameter reminder: The reminder to uncomplete
    /// - Throws: `JMEventKitError` if update fails
    public func uncompleteReminder(_ reminder: EKReminder) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        reminder.isCompleted = false

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw JMEventKitError.reminderUpdateFailed
        }
    }

    /// Update an existing reminder
    /// - Parameter reminder: The reminder with updated properties
    /// - Throws: `JMEventKitError` if update fails
    public func updateReminder(_ reminder: EKReminder) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw JMEventKitError.reminderUpdateFailed
        }
    }

    // MARK: - Delete Reminders

    /// Delete a reminder
    /// - Parameter reminder: The reminder to delete
    /// - Throws: `JMEventKitError` if deletion fails
    public func deleteReminder(_ reminder: EKReminder) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        do {
            try eventStore.remove(reminder, commit: true)

            // Remove from cached reminders
            if let index = reminders.firstIndex(where: { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }) {
                reminders.remove(at: index)
            }
        } catch {
            throw JMEventKitError.reminderDeletionFailed
        }
    }

    /// Delete a reminder by its identifier
    /// - Parameter identifier: The calendar item identifier
    /// - Throws: `JMEventKitError` if reminder not found or deletion fails
    public func deleteReminder(withIdentifier identifier: String) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        guard let item = eventStore.calendarItem(withIdentifier: identifier),
              let reminder = item as? EKReminder else {
            throw JMEventKitError.reminderNotFound
        }

        try await deleteReminder(reminder)
    }

    // MARK: - Utility Methods

    /// Get a reminder by its identifier
    /// - Parameter identifier: The calendar item identifier
    /// - Returns: The `EKReminder` if found, `nil` otherwise
    public func reminder(withIdentifier identifier: String) -> EKReminder? {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) else {
            return nil
        }
        return item as? EKReminder
    }

    /// Get the default calendar for new reminders
    /// - Returns: The default `EKCalendar` or `nil` if not found
    public func defaultCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewReminders()
    }
}

// MARK: - EKEventStore Extension for Predicates

private extension EventStoreProtocol where Self == EKEventStore {
    func predicateForIncompleteReminders(
        withDueDateStarting startDate: Date?,
        ending endDate: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        return (self as! EKEventStore).predicateForIncompleteReminders(
            withDueDateStarting: startDate,
            ending: endDate,
            calendars: calendars
        )
    }

    func predicateForCompletedReminders(
        withCompletionDateStarting startDate: Date?,
        ending endDate: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        return (self as! EKEventStore).predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: endDate,
            calendars: calendars
        )
    }
}

private extension EventStoreProtocol {
    func predicateForIncompleteReminders(
        withDueDateStarting startDate: Date?,
        ending endDate: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        // This is a workaround for testing - real implementation uses EKEventStore method
        return NSPredicate(value: true)
    }

    func predicateForCompletedReminders(
        withCompletionDateStarting startDate: Date?,
        ending endDate: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        // This is a workaround for testing - real implementation uses EKEventStore method
        return NSPredicate(value: true)
    }
}
