//
//  EventStoreProtocol.swift
//  JMEventKit
//
//  Created by JMEventKit
//

@preconcurrency import EventKit
import Foundation

/// Protocol abstraction for EKEventStore to enable testing
public protocol EventStoreProtocol {
    /// Request full access to reminders (iOS 17+) or legacy access (iOS 16-)
    func requestReminderAccess() async throws -> Bool

    /// Get the authorization status for reminders
    func authorizationStatus() -> EKAuthorizationStatus

    /// Save a reminder to the event store
    func save(_ reminder: EKReminder, commit: Bool) throws

    /// Remove a reminder from the event store
    func remove(_ reminder: EKReminder, commit: Bool) throws

    /// Commit all pending changes
    func commit() throws

    /// Fetch reminders matching a predicate
    func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder]

    /// Get reminder by identifier
    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem?

    /// Get the default calendar for new reminders
    func defaultCalendarForNewReminders() -> EKCalendar?

    /// Create a new reminder object
    func makeReminder() -> EKReminder

    // MARK: - Event Methods

    /// Create a new event object
    func makeEvent() -> EKEvent

    /// Save an event to the event store
    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws

    /// Remove an event from the event store
    func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws

    /// Get event by identifier
    func event(withIdentifier identifier: String) -> EKEvent?

    /// Get events matching a predicate
    func events(matching predicate: NSPredicate) -> [EKEvent]

    /// Create a predicate for events within a date range
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate

    /// Get the default calendar for new events
    func defaultCalendarForNewEvents() -> EKCalendar?
}

/// Extension to make EKEventStore conform to EventStoreProtocol
extension EKEventStore: EventStoreProtocol {
    public func requestReminderAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(iOS 17.0, macOS 14.0, *) {
                self.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                self.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func authorizationStatus() -> EKAuthorizationStatus {
        if #available(iOS 17.0, macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .reminder)
        } else {
            return EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    nonisolated public func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { @Sendable continuation in
            self.fetchReminders(matching: predicate) { @Sendable reminders in
                // Return the reminders array directly
                // Note: EKReminder is not marked Sendable but is thread-safe
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    public func makeReminder() -> EKReminder {
        return EKReminder(eventStore: self)
    }

    public func makeEvent() -> EKEvent {
        return EKEvent(eventStore: self)
    }

    // Note: EKEventStore has a property named defaultCalendarForNewEvents
    // We can't directly return it due to name collision, so we explicitly cast
    nonisolated public func defaultCalendarForNewEvents() -> EKCalendar? {
        return (self as EKEventStore).defaultCalendarForNewEvents
    }
}
