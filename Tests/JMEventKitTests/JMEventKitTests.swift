//
//  JMEventKitTests.swift
//  JMEventKitTests
//
//  Created by JMEventKit
//

import XCTest
import EventKit
@testable import JMEventKit

@MainActor
final class JMEventKitTests: XCTestCase {

    var mockStore: MockEventStore!
    var jmEventKit: JMEventKit!

    override func setUp() async throws {
        mockStore = MockEventStore()
        jmEventKit = JMEventKit(mockEventStore: mockStore)
    }

    override func tearDown() {
        mockStore = nil
        jmEventKit = nil
    }

    // MARK: - Authorization Tests

    func testRequestAuthorizationGranted() async throws {
        // Given
        mockStore.shouldGrantAccess = true

        // When
        let granted = try await jmEventKit.requestReminderAuthorization()

        // Then
        XCTAssertTrue(granted)
        XCTAssertTrue(mockStore.requestAccessCalled)
        XCTAssertEqual(jmEventKit.authorizationStatus, .fullAccess)
    }

    func testRequestAuthorizationDenied() async throws {
        // Given
        mockStore.shouldGrantAccess = false

        // When & Then
        do {
            _ = try await jmEventKit.requestReminderAuthorization()
            XCTFail("Should throw permission denied error")
        } catch let error as JMEventKitError {
            if case .permissionDenied = error {
                XCTAssertEqual(jmEventKit.authorizationStatus, .denied)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testIsAuthorizedWhenGranted() {
        // Given
        mockStore.authStatus = .fullAccess

        // When
        let isAuthorized = jmEventKit.isAuthorized()

        // Then
        XCTAssertTrue(isAuthorized)
    }

    func testIsAuthorizedWhenDenied() {
        // Given
        mockStore.authStatus = .denied

        // When
        let isAuthorized = jmEventKit.isAuthorized()

        // Then
        XCTAssertFalse(isAuthorized)
    }

    // MARK: - Create Reminder Tests

    func testCreateReminderSuccess() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let title = "Test Reminder"
        let notes = "Test notes"
        let dueDate = Date()

        // When
        let reminder = try await jmEventKit.createReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: 5
        )

        // Then
        XCTAssertTrue(mockStore.saveCalled)
        XCTAssertEqual(reminder.title, title)
        XCTAssertEqual(reminder.notes, notes)
        XCTAssertEqual(reminder.priority, 5)
        XCTAssertNotNil(reminder.dueDateComponents)
    }

    func testCreateReminderWithoutPermission() async throws {
        // Given
        mockStore.authStatus = .denied

        // When & Then
        do {
            _ = try await jmEventKit.createReminder(title: "Test")
            XCTFail("Should throw permission denied error")
        } catch let error as JMEventKitError {
            if case .permissionDenied = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testCreateReminderSaveFailed() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        mockStore.shouldThrowOnSave = true

        // When & Then
        do {
            _ = try await jmEventKit.createReminder(title: "Test")
            XCTFail("Should throw save failed error")
        } catch let error as JMEventKitError {
            if case .saveFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Fetch Reminders Tests

    func testFetchRemindersSuccess() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let reminder1 = mockStore.makeReminder()
        reminder1.title = "Reminder 1"
        let reminder2 = mockStore.makeReminder()
        reminder2.title = "Reminder 2"
        mockStore.storedReminders = [reminder1, reminder2]

        // When
        let reminders = try await jmEventKit.fetchReminders()

        // Then
        XCTAssertTrue(mockStore.fetchCalled)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(jmEventKit.reminders.count, 2)
        XCTAssertFalse(jmEventKit.isFetching)
    }

    func testFetchRemindersWithoutPermission() async throws {
        // Given
        mockStore.authStatus = .denied

        // When & Then
        do {
            _ = try await jmEventKit.fetchReminders()
            XCTFail("Should throw permission denied error")
        } catch let error as JMEventKitError {
            if case .permissionDenied = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testFetchRemindersFailed() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        mockStore.shouldThrowOnFetch = true

        // When & Then
        do {
            _ = try await jmEventKit.fetchReminders()
            XCTFail("Should throw fetch failed error")
        } catch let error as JMEventKitError {
            if case .fetchFailed = error {
                // Success
                XCTAssertFalse(jmEventKit.isFetching)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Update Reminder Tests

    func testCompleteReminder() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let reminder = mockStore.makeReminder()
        reminder.isCompleted = false

        // When
        try await jmEventKit.completeReminder(reminder)

        // Then
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertTrue(mockStore.saveCalled)
    }

    func testUncompleteReminder() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let reminder = mockStore.makeReminder()
        reminder.isCompleted = true

        // When
        try await jmEventKit.uncompleteReminder(reminder)

        // Then
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertTrue(mockStore.saveCalled)
    }

    func testUpdateReminder() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let reminder = mockStore.makeReminder()
        reminder.title = "Original Title"

        // When
        reminder.title = "Updated Title"
        try await jmEventKit.updateReminder(reminder)

        // Then
        XCTAssertTrue(mockStore.saveCalled)
        XCTAssertEqual(reminder.title, "Updated Title")
    }

    // MARK: - Delete Reminder Tests

    func testDeleteReminder() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        let reminder = mockStore.makeReminder()
        mockStore.storedReminders = [reminder]

        // When
        try await jmEventKit.deleteReminder(reminder)

        // Then
        XCTAssertTrue(mockStore.deleteCalled)
        XCTAssertEqual(mockStore.storedReminders.count, 0)
    }

    func testDeleteReminderWithoutPermission() async throws {
        // Given
        mockStore.authStatus = .denied
        let reminder = mockStore.makeReminder()

        // When & Then
        do {
            try await jmEventKit.deleteReminder(reminder)
            XCTFail("Should throw permission denied error")
        } catch let error as JMEventKitError {
            if case .permissionDenied = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testDeleteReminderFailed() async throws {
        // Given
        mockStore.authStatus = .fullAccess
        mockStore.shouldThrowOnDelete = true
        let reminder = mockStore.makeReminder()

        // When & Then
        do {
            try await jmEventKit.deleteReminder(reminder)
            XCTFail("Should throw deletion failed error")
        } catch let error as JMEventKitError {
            if case .reminderDeletionFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Configuration Tests

    func testConfigureAppName() {
        // When
        jmEventKit.configure(appName: "MyApp")

        // Then - No direct way to test this, but we can verify it doesn't crash
        XCTAssertNotNil(jmEventKit)
    }

    // MARK: - Utility Tests

    func testDefaultCalendar() {
        // When
        let calendar = jmEventKit.defaultCalendar()

        // Then
        XCTAssertNotNil(calendar)
        XCTAssertEqual(calendar?.title, "Mock Calendar")
    }
}
