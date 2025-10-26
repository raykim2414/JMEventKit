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

    /// Array of fetched events
    @Published public private(set) var events: [EKEvent] = []

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
    ///   - alarms: Optional array of alarms
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created `EKReminder`
    /// - Throws: `JMEventKitError` if creation fails
    public func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 0,
        alarms: [EKAlarm]? = nil,
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

        // Set alarms if provided
        if let alarms = alarms {
            reminder.alarms = alarms
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

    /// Create a recurring reminder
    /// - Parameters:
    ///   - title: Title of the reminder
    ///   - notes: Optional notes for the reminder
    ///   - startDate: Start date for the reminder
    ///   - frequency: Recurrence frequency (.daily, .weekly, .monthly, .yearly)
    ///   - interval: Interval for recurrence (e.g., every 2 days)
    ///   - endDate: Optional end date for recurrence
    ///   - priority: Priority level (0 = none, 1-4 = high, 5 = medium, 6-9 = low)
    ///   - alarms: Optional array of alarms
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created recurring `EKReminder`
    /// - Throws: `JMEventKitError` if creation fails
    public func createRecurringReminder(
        title: String,
        notes: String? = nil,
        startDate: Date,
        frequency: EKRecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        priority: Int = 0,
        alarms: [EKAlarm]? = nil,
        calendar: EKCalendar? = nil
    ) async throws -> EKReminder {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        let reminder = eventStore.makeReminder()
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        // Set due date from start date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        reminder.dueDateComponents = components

        // Set alarms if provided
        if let alarms = alarms {
            reminder.alarms = alarms
        }

        // Create recurrence rule
        let recurrenceEnd: EKRecurrenceEnd?
        if let endDate = endDate {
            recurrenceEnd = EKRecurrenceEnd(end: endDate)
        } else {
            recurrenceEnd = nil
        }

        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: recurrenceEnd
        )
        reminder.recurrenceRules = [recurrenceRule]

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
        let predicate = (eventStore as! EKEventStore).predicateForIncompleteReminders(
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
        let predicate = (eventStore as! EKEventStore).predicateForCompletedReminders(
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

    /// Fetch incomplete reminders with advanced filtering
    /// - Parameters:
    ///   - priority: Filter by priority (nil = all priorities)
    ///   - startDate: Filter by due date starting from this date
    ///   - endDate: Filter by due date ending at this date
    ///   - calendars: Filter by specific calendars (nil = all calendars)
    /// - Returns: Array of filtered `EKReminder`
    /// - Throws: `JMEventKitError` if fetch fails
    public func fetchIncompleteReminders(
        priority: Int? = nil,
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        calendars: [EKCalendar]? = nil
    ) async throws -> [EKReminder] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        isFetching = true
        defer { isFetching = false }

        // Create predicate for incomplete reminders
        let predicate = (eventStore as! EKEventStore).predicateForIncompleteReminders(
            withDueDateStarting: startDate,
            ending: endDate,
            calendars: calendars
        )

        do {
            let fetchedReminders = try await eventStore.fetchReminders(matching: predicate)

            // Apply priority filter if specified
            if let priority = priority {
                return fetchedReminders.filter { $0.priority == priority }
            }

            return fetchedReminders
        } catch {
            throw JMEventKitError.fetchFailed(error)
        }
    }

    /// Search reminders by title or notes
    /// - Parameters:
    ///   - query: Search query string
    ///   - includeCompleted: Include completed reminders in search (default: false)
    /// - Returns: Array of matching `EKReminder`
    /// - Throws: `JMEventKitError` if search fails
    public func searchReminders(query: String, includeCompleted: Bool = false) async throws -> [EKReminder] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        isFetching = true
        defer { isFetching = false }

        // Fetch incomplete reminders
        let incompletePredicate = (eventStore as! EKEventStore).predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        do {
            var allReminders = try await eventStore.fetchReminders(matching: incompletePredicate)

            // Include completed reminders if requested
            if includeCompleted {
                let completedPredicate = (eventStore as! EKEventStore).predicateForCompletedReminders(
                    withCompletionDateStarting: nil,
                    ending: nil,
                    calendars: nil
                )
                let completedReminders = try await eventStore.fetchReminders(matching: completedPredicate)
                allReminders.append(contentsOf: completedReminders)
            }

            // Filter by query
            let lowercasedQuery = query.lowercased()
            return allReminders.filter { reminder in
                let titleMatch = reminder.title?.lowercased().contains(lowercasedQuery) ?? false
                let notesMatch = reminder.notes?.lowercased().contains(lowercasedQuery) ?? false
                return titleMatch || notesMatch
            }
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

    // MARK: - Calendar Events Authorization

    /// Request permission to access calendar events
    /// Automatically handles iOS 17+ and older iOS versions
    /// - Returns: `true` if permission granted, `false` otherwise
    /// - Throws: `JMEventKitError` if an error occurs
    public func requestEventAuthorization() async throws -> Bool {
        // Use same authorizationStatus as reminders for now
        // In production, you might want separate status tracking
        return try await requestReminderAuthorization()
    }

    // MARK: - Create Events

    /// Create a new calendar event
    /// - Parameters:
    ///   - title: Title of the event
    ///   - startDate: Start date and time
    ///   - endDate: End date and time
    ///   - location: Optional location
    ///   - notes: Optional notes
    ///   - alarms: Optional array of alarms
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created `EKEvent`
    /// - Throws: `JMEventKitError` if creation fails
    public func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        alarms: [EKAlarm]? = nil,
        calendar: EKCalendar? = nil
    ) async throws -> EKEvent {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        let event = eventStore.makeEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.isAllDay = false

        // Set alarms if provided
        if let alarms = alarms {
            event.alarms = alarms
        }

        // Set calendar
        if let calendar = calendar {
            event.calendar = calendar
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents() {
            event.calendar = defaultCalendar
        } else {
            throw JMEventKitError.calendarNotFound
        }

        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event
        } catch {
            throw JMEventKitError.saveFailed(error)
        }
    }

    /// Create a new all-day event
    /// - Parameters:
    ///   - title: Title of the event
    ///   - date: Date for the all-day event
    ///   - location: Optional location
    ///   - notes: Optional notes
    ///   - alarms: Optional array of alarms
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created all-day `EKEvent`
    /// - Throws: `JMEventKitError` if creation fails
    public func createAllDayEvent(
        title: String,
        date: Date,
        location: String? = nil,
        notes: String? = nil,
        alarms: [EKAlarm]? = nil,
        calendar: EKCalendar? = nil
    ) async throws -> EKEvent {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        let event = eventStore.makeEvent()
        event.title = title
        event.isAllDay = true
        event.location = location
        event.notes = notes

        // Set start and end dates to the same day
        let dateCalendar = Calendar.current
        let startOfDay = dateCalendar.startOfDay(for: date)
        event.startDate = startOfDay
        event.endDate = dateCalendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        // Set alarms if provided
        if let alarms = alarms {
            event.alarms = alarms
        }

        // Set calendar
        if let targetCalendar = calendar {
            event.calendar = targetCalendar
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents() {
            event.calendar = defaultCalendar
        } else {
            throw JMEventKitError.calendarNotFound
        }

        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event
        } catch {
            throw JMEventKitError.saveFailed(error)
        }
    }

    /// Create a recurring calendar event
    /// - Parameters:
    ///   - title: Title of the event
    ///   - startDate: Start date and time
    ///   - endDate: End date and time
    ///   - frequency: Recurrence frequency (.daily, .weekly, .monthly, .yearly)
    ///   - interval: Interval for recurrence (e.g., every 2 weeks)
    ///   - recurrenceEnd: Optional end date for recurrence
    ///   - location: Optional location
    ///   - notes: Optional notes
    ///   - alarms: Optional array of alarms
    ///   - calendar: Optional specific calendar to use
    /// - Returns: The created recurring `EKEvent`
    /// - Throws: `JMEventKitError` if creation fails
    public func createRecurringEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        frequency: EKRecurrenceFrequency,
        interval: Int = 1,
        recurrenceEnd: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        alarms: [EKAlarm]? = nil,
        calendar: EKCalendar? = nil
    ) async throws -> EKEvent {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        let event = eventStore.makeEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.isAllDay = false

        // Set alarms if provided
        if let alarms = alarms {
            event.alarms = alarms
        }

        // Create recurrence rule
        let recurrenceEndRule: EKRecurrenceEnd?
        if let recurrenceEnd = recurrenceEnd {
            recurrenceEndRule = EKRecurrenceEnd(end: recurrenceEnd)
        } else {
            recurrenceEndRule = nil
        }

        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: recurrenceEndRule
        )
        event.recurrenceRules = [recurrenceRule]

        // Set calendar
        if let targetCalendar = calendar {
            event.calendar = targetCalendar
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents() {
            event.calendar = defaultCalendar
        } else {
            throw JMEventKitError.calendarNotFound
        }

        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event
        } catch {
            throw JMEventKitError.saveFailed(error)
        }
    }

    // MARK: - Fetch Events

    /// Fetch events within a date range
    /// Updates the `events` published property
    /// - Parameters:
    ///   - startDate: Start date for the range
    ///   - endDate: End date for the range
    ///   - calendars: Optional array of calendars to search (nil = all calendars)
    /// - Returns: Array of `EKEvent`
    /// - Throws: `JMEventKitError` if fetch fails
    @discardableResult
    public func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) async throws -> [EKEvent] {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        isFetching = true
        defer { isFetching = false }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        let fetchedEvents = eventStore.events(matching: predicate)
        events = fetchedEvents
        return fetchedEvents
    }

    // MARK: - Update Events

    /// Update an existing event
    /// - Parameters:
    ///   - event: The event with updated properties
    ///   - span: Whether to update this event only or future events (.thisEvent or .futureEvents)
    /// - Throws: `JMEventKitError` if update fails
    public func updateEvent(_ event: EKEvent, span: EKSpan = .thisEvent) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        do {
            try eventStore.save(event, span: span, commit: true)
        } catch {
            throw JMEventKitError.eventUpdateFailed
        }
    }

    // MARK: - Delete Events

    /// Delete an event
    /// - Parameters:
    ///   - event: The event to delete
    ///   - span: Whether to delete this event only or future events (.thisEvent or .futureEvents)
    /// - Throws: `JMEventKitError` if deletion fails
    public func deleteEvent(_ event: EKEvent, span: EKSpan = .thisEvent) async throws {
        guard isAuthorized() else {
            throw JMEventKitError.permissionDenied
        }

        do {
            try eventStore.remove(event, span: span, commit: true)

            // Remove from cached events
            if let index = events.firstIndex(where: { $0.eventIdentifier == event.eventIdentifier }) {
                events.remove(at: index)
            }
        } catch {
            throw JMEventKitError.eventDeletionFailed
        }
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

    /// Get an event by its identifier
    /// - Parameter identifier: The event identifier
    /// - Returns: The `EKEvent` if found, `nil` otherwise
    public func event(withIdentifier identifier: String) -> EKEvent? {
        return eventStore.event(withIdentifier: identifier)
    }

    /// Get the default calendar for new events
    /// - Returns: The default `EKCalendar` or `nil` if not found
    public func defaultEventCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents()
    }
}
