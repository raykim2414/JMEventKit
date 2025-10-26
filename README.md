# JMEventKit

A modern Swift wrapper for Apple's EventKit framework, designed to simplify reminders and calendar event management in iOS applications.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20macOS%2014%2B%20|%20watchOS%2010%2B-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Features

- ✅ **Simple API**: Intuitive, modern async/await interface
- ✅ **SwiftUI Ready**: Built-in `ObservableObject` support with `@Published` properties
- ✅ **Type-Safe**: Leverages Swift's type system for safer code
- ✅ **iOS 17+ Compatible**: Handles new permission model automatically
- ✅ **Well-Tested**: Comprehensive unit test coverage with mock support
- ✅ **Protocol-Based**: Designed for testability with dependency injection
- ✅ **Zero Dependencies**: Uses only Apple frameworks

## 📋 Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+
- Swift 5.9+
- Xcode 15.0+

## 📦 Installation

### Swift Package Manager

Add JMEventKit to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/raycsh/JMEventKit.git", from: "0.1.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/raycsh/JMEventKit.git`
3. Select version and add to your target

## 🚀 Quick Start

### 1. Add Required Permissions

Add these keys to your `Info.plist`:

```xml
<key>NSRemindersFullAccessUsageDescription</key>
<string>We need access to your reminders to help you track important tasks.</string>
```

### 2. Request Permission

```swift
import JMEventKit

// Configure with your app name
JMEventKit.shared.configure(appName: "My App")

// Request permission
do {
    let granted = try await JMEventKit.shared.requestReminderAuthorization()
    if granted {
        print("Permission granted!")
    }
} catch {
    print("Error requesting permission: \(error)")
}
```

### 3. Create a Reminder

```swift
do {
    let reminder = try await JMEventKit.shared.createReminder(
        title: "Buy groceries",
        notes: "Milk, eggs, bread",
        dueDate: Date().addingTimeInterval(3600), // 1 hour from now
        priority: 5
    )
    print("Created reminder: \(reminder.title ?? "")")
} catch {
    print("Error creating reminder: \(error)")
}
```

### 4. Fetch Reminders

```swift
do {
    let reminders = try await JMEventKit.shared.fetchReminders()
    for reminder in reminders {
        print("- \(reminder.title ?? "Untitled")")
    }
} catch {
    print("Error fetching reminders: \(error)")
}
```

### 5. Complete a Reminder

```swift
do {
    try await JMEventKit.shared.completeReminder(reminder)
    print("Reminder completed!")
} catch {
    print("Error completing reminder: \(error)")
}
```

### 6. Delete a Reminder

```swift
do {
    try await JMEventKit.shared.deleteReminder(reminder)
    print("Reminder deleted!")
} catch {
    print("Error deleting reminder: \(error)")
}
```

## 💻 SwiftUI Integration

JMEventKit works seamlessly with SwiftUI using `@StateObject`:

```swift
import SwiftUI
import JMEventKit

struct RemindersView: View {
    @StateObject private var eventKit = JMEventKit.shared

    var body: some View {
        List {
            ForEach(eventKit.reminders, id: \.calendarItemIdentifier) { reminder in
                HStack {
                    Text(reminder.title ?? "Untitled")
                    Spacer()
                    if reminder.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .task {
            await requestPermissionAndFetch()
        }
        .refreshable {
            try? await eventKit.fetchReminders()
        }
        .overlay {
            if eventKit.isFetching {
                ProgressView()
            }
        }
    }

    private func requestPermissionAndFetch() async {
        do {
            _ = try await eventKit.requestReminderAuthorization()
            try await eventKit.fetchReminders()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## 📚 Advanced Usage

### Fetch Completed Reminders

```swift
let lastWeek = Date().addingTimeInterval(-7 * 24 * 60 * 60)
let completed = try await JMEventKit.shared.fetchCompletedReminders(
    from: lastWeek,
    to: Date()
)
```

### Update a Reminder

```swift
reminder.title = "Updated title"
reminder.notes = "Updated notes"
try await JMEventKit.shared.updateReminder(reminder)
```

### Check Authorization Status

```swift
if JMEventKit.shared.isAuthorized() {
    // Proceed with reminder operations
} else {
    // Request authorization
}
```

### Get Default Calendar

```swift
if let calendar = JMEventKit.shared.defaultCalendar() {
    print("Default calendar: \(calendar.title)")
}
```

## 🧪 Testing

JMEventKit is designed with testability in mind. Use the `EventStoreProtocol` to inject mock implementations:

```swift
import XCTest
@testable import JMEventKit

class MyTests: XCTestCase {
    func testReminderCreation() async throws {
        let mockStore = MockEventStore()
        let eventKit = JMEventKit(mockEventStore: mockStore)

        let reminder = try await eventKit.createReminder(title: "Test")

        XCTAssertEqual(reminder.title, "Test")
        XCTAssertTrue(mockStore.saveCalled)
    }
}
```

## 🛡 Error Handling

JMEventKit provides detailed error types via `JMEventKitError`:

```swift
do {
    try await JMEventKit.shared.createReminder(title: "Test")
} catch JMEventKitError.permissionDenied {
    print("Permission denied. Please enable in Settings.")
} catch JMEventKitError.permissionRestricted {
    print("Access restricted by device settings.")
} catch JMEventKitError.calendarNotFound {
    print("Default calendar not found.")
} catch {
    print("Unexpected error: \(error)")
}
```

Available error types:
- `permissionDenied` - User denied access
- `permissionRestricted` - Access restricted by parental controls
- `reminderNotFound` - Reminder doesn't exist
- `reminderCreationFailed` - Failed to create reminder
- `reminderDeletionFailed` - Failed to delete reminder
- `reminderUpdateFailed` - Failed to update reminder
- `saveFailed(Error)` - Failed to save to event store
- `fetchFailed(Error)` - Failed to fetch reminders
- `invalidConfiguration(String)` - Invalid configuration
- `calendarNotFound` - Default calendar not found
- `unknown(Error)` - Unknown error occurred

## 🗺 Roadmap

### Phase 1: Core Reminders (v0.1.0) - ✅ Complete
- ✅ Basic reminder CRUD operations
- ✅ iOS 17+ permission handling
- ✅ SwiftUI ObservableObject integration
- ✅ Error handling
- ✅ Unit tests
- ✅ Documentation

### Phase 2: Advanced Reminders (v0.2.0)
- [ ] Recurring reminders
- [ ] Reminder alarms
- [ ] Priority and color support
- [ ] Advanced filtering
- [ ] Search functionality

### Phase 3: Calendar Events (v0.3.0)
- [ ] Event creation and management
- [ ] All-day events
- [ ] Recurring events
- [ ] Event attendees

### Phase 4: Advanced Features (v0.4.0+)
- [ ] Location-based reminders
- [ ] Natural language date parsing
- [ ] Batch operations
- [ ] iCloud sync handling

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

JMEventKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 👨‍💻 Author

**Ray Kim** - [https://github.com/raykim2414](https://github.com/raykim2414)

## 🙏 Acknowledgments

- Inspired by [Shift](https://github.com/vinhnx/Shift)
- Built with ❤️ for the iOS development community

---

**Note**: This library wraps Apple's EventKit framework. Some EventKit objects (like `EKReminder`) are not fully Sendable-compliant in Swift 6. This is expected and will be resolved as Apple updates their frameworks.
