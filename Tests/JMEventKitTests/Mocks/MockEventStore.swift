//
//  MockEventStore.swift
//  JMEventKitTests
//
//  Created by JMEventKit
//

import EventKit
import Foundation
@testable import JMEventKit

/// Mock implementation of EventStoreProtocol for testing
@MainActor
final class MockEventStore: EventStoreProtocol {
    var authStatus: EKAuthorizationStatus = .notDetermined
    var shouldGrantAccess = true
    var storedReminders: [EKReminder] = []
    var shouldThrowOnSave = false
    var shouldThrowOnFetch = false
    var shouldThrowOnDelete = false

    // Track method calls
    var requestAccessCalled = false
    var saveCalled = false
    var deleteCalled = false
    var fetchCalled = false

    func requestReminderAccess() async throws -> Bool {
        requestAccessCalled = true
        if shouldGrantAccess {
            authStatus = .fullAccess
            return true
        } else {
            authStatus = .denied
            return false
        }
    }

    func authorizationStatus() -> EKAuthorizationStatus {
        return authStatus
    }

    func save(_ reminder: EKReminder, commit: Bool) throws {
        saveCalled = true
        if shouldThrowOnSave {
            throw NSError(domain: "MockEventStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        }
        if !storedReminders.contains(where: { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }) {
            storedReminders.append(reminder)
        }
    }

    func remove(_ reminder: EKReminder, commit: Bool) throws {
        deleteCalled = true
        if shouldThrowOnDelete {
            throw NSError(domain: "MockEventStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
        }
        storedReminders.removeAll(where: { $0.calendarItemIdentifier == reminder.calendarItemIdentifier })
    }

    func commit() throws {
        // No-op for mock
    }

    nonisolated func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        await MainActor.run {
            fetchCalled = true
        }

        if await MainActor.run(resultType: Bool.self) { shouldThrowOnFetch } {
            throw NSError(domain: "MockEventStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
        }
        return await MainActor.run { storedReminders }
    }

    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem? {
        return storedReminders.first(where: { $0.calendarItemIdentifier == identifier })
    }

    func defaultCalendarForNewReminders() -> EKCalendar? {
        // Create a mock calendar
        let calendar = EKCalendar(for: .reminder, eventStore: EKEventStore())
        calendar.title = "Mock Calendar"
        return calendar
    }

    func makeReminder() -> EKReminder {
        let reminder = EKReminder(eventStore: EKEventStore())
        // Generate a fake identifier for testing
        let uuid = UUID().uuidString
        // Note: We can't set calendarItemIdentifier directly, so we'll use the object as-is
        return reminder
    }
}
