# JMEventKit

Apple의 EventKit 프레임워크를 감싸는 현대적인 Swift 래퍼 라이브러리로, iOS 애플리케이션에서 미리 알림과 캘린더 이벤트 관리를 간소화합니다.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20macOS%2014%2B%20|%20watchOS%2010%2B-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 주요 기능

- ✅ **간단한 API**: 직관적이고 현대적인 async/await 인터페이스
- ✅ **SwiftUI 지원**: `@Published` 속성을 가진 `ObservableObject` 내장
- ✅ **타입 안전성**: Swift의 타입 시스템을 활용한 안전한 코드
- ✅ **iOS 17+ 호환**: 새로운 권한 모델을 자동으로 처리
- ✅ **테스트 완료**: Mock 지원으로 포괄적인 단위 테스트 커버리지
- ✅ **프로토콜 기반**: 의존성 주입을 통한 테스트 가능한 설계
- ✅ **무의존성**: Apple 프레임워크만 사용

## 📋 요구 사항

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+
- Swift 5.9+
- Xcode 15.0+

## 📦 설치

### Swift Package Manager

Swift Package Manager를 통해 프로젝트에 JMEventKit을 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/raycsh/JMEventKit.git", from: "0.1.0")
]
```

또는 Xcode에서:
1. File > Add Package Dependencies
2. 입력: `https://github.com/raycsh/JMEventKit.git`
3. 버전을 선택하고 타겟에 추가

## 🚀 빠른 시작

### 1. 필수 권한 추가

`Info.plist`에 다음 키를 추가하세요:

```xml
<key>NSRemindersFullAccessUsageDescription</key>
<string>중요한 작업을 추적하기 위해 미리 알림에 접근이 필요합니다.</string>
```

### 2. 권한 요청

```swift
import JMEventKit

// 앱 이름으로 구성
JMEventKit.shared.configure(appName: "내 앱")

// 권한 요청
do {
    let granted = try await JMEventKit.shared.requestReminderAuthorization()
    if granted {
        print("권한이 허용되었습니다!")
    }
} catch {
    print("권한 요청 오류: \(error)")
}
```

### 3. 미리 알림 생성

```swift
do {
    let reminder = try await JMEventKit.shared.createReminder(
        title: "장 보기",
        notes: "우유, 계란, 빵",
        dueDate: Date().addingTimeInterval(3600), // 1시간 후
        priority: 5
    )
    print("미리 알림 생성됨: \(reminder.title ?? "")")
} catch {
    print("미리 알림 생성 오류: \(error)")
}
```

### 4. 미리 알림 가져오기

```swift
do {
    let reminders = try await JMEventKit.shared.fetchReminders()
    for reminder in reminders {
        print("- \(reminder.title ?? "제목 없음")")
    }
} catch {
    print("미리 알림 가져오기 오류: \(error)")
}
```

### 5. 미리 알림 완료하기

```swift
do {
    try await JMEventKit.shared.completeReminder(reminder)
    print("미리 알림 완료!")
} catch {
    print("미리 알림 완료 오류: \(error)")
}
```

### 6. 미리 알림 삭제하기

```swift
do {
    try await JMEventKit.shared.deleteReminder(reminder)
    print("미리 알림 삭제됨!")
} catch {
    print("미리 알림 삭제 오류: \(error)")
}
```

## 💻 SwiftUI 통합

JMEventKit은 `@StateObject`를 사용하여 SwiftUI와 완벽하게 작동합니다:

```swift
import SwiftUI
import JMEventKit

struct RemindersView: View {
    @StateObject private var eventKit = JMEventKit.shared

    var body: some View {
        List {
            ForEach(eventKit.reminders, id: \.calendarItemIdentifier) { reminder in
                HStack {
                    Text(reminder.title ?? "제목 없음")
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
            print("오류: \(error)")
        }
    }
}
```

## 📚 고급 사용법

### 완료된 미리 알림 가져오기

```swift
let lastWeek = Date().addingTimeInterval(-7 * 24 * 60 * 60)
let completed = try await JMEventKit.shared.fetchCompletedReminders(
    from: lastWeek,
    to: Date()
)
```

### 미리 알림 업데이트

```swift
reminder.title = "업데이트된 제목"
reminder.notes = "업데이트된 메모"
try await JMEventKit.shared.updateReminder(reminder)
```

### 권한 상태 확인

```swift
if JMEventKit.shared.isAuthorized() {
    // 미리 알림 작업 진행
} else {
    // 권한 요청
}
```

### 기본 캘린더 가져오기

```swift
if let calendar = JMEventKit.shared.defaultCalendar() {
    print("기본 캘린더: \(calendar.title)")
}
```

### 반복 미리 알림 생성

```swift
let reminder = try await JMEventKit.shared.createRecurringReminder(
    title: "비타민 복용",
    startDate: Date(),
    frequency: .daily,
    interval: 1,
    endDate: Date().addingTimeInterval(30 * 24 * 60 * 60) // 30일
)
```

### 알람이 있는 미리 알림 생성

```swift
let alarm1 = EKAlarm(relativeOffset: -3600) // 1시간 전
let alarm2 = EKAlarm(relativeOffset: -300)  // 5분 전

let reminder = try await JMEventKit.shared.createReminder(
    title: "중요한 회의",
    dueDate: Date().addingTimeInterval(7200),
    alarms: [alarm1, alarm2]
)
```

### 고급 필터링

```swift
// 이번 주 마감인 높은 우선순위 미리 알림 가져오기
let weekFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60)
let highPriorityReminders = try await JMEventKit.shared.fetchIncompleteReminders(
    priority: 1,
    from: Date(),
    to: weekFromNow
)
```

### 미리 알림 검색

```swift
// 제목과 메모에서 검색
let results = try await JMEventKit.shared.searchReminders(
    query: "장보기",
    includeCompleted: false
)
```

### 캘린더 이벤트 생성

```swift
let startDate = Date().addingTimeInterval(3600)
let endDate = startDate.addingTimeInterval(3600) // 1시간 지속

let event = try await JMEventKit.shared.createEvent(
    title: "팀 회의",
    startDate: startDate,
    endDate: endDate,
    location: "회의실 A",
    notes: "4분기 목표 논의"
)
```

### 종일 이벤트 생성

```swift
let event = try await JMEventKit.shared.createAllDayEvent(
    title: "회사 휴일",
    date: Date().addingTimeInterval(7 * 24 * 60 * 60)
)
```

### 반복 이벤트 생성

```swift
let event = try await JMEventKit.shared.createRecurringEvent(
    title: "주간 팀 스탠드업",
    startDate: Date(),
    endDate: Date().addingTimeInterval(1800), // 30분
    frequency: .weekly,
    interval: 1,
    recurrenceEnd: Date().addingTimeInterval(90 * 24 * 60 * 60) // 90일
)
```

### 이벤트 가져오기

```swift
let startDate = Date()
let endDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 다음 7일

let events = try await JMEventKit.shared.fetchEvents(
    from: startDate,
    to: endDate
)
```

### 이벤트 업데이트

```swift
event.title = "업데이트된 회의 제목"
event.location = "회의실 B"
try await JMEventKit.shared.updateEvent(event)
```

### 이벤트 삭제

```swift
try await JMEventKit.shared.deleteEvent(event)
```

## 🧪 테스트

JMEventKit은 테스트를 염두에 두고 설계되었습니다. `EventStoreProtocol`을 사용하여 Mock 구현을 주입하세요:

```swift
import XCTest
@testable import JMEventKit

class MyTests: XCTestCase {
    func testReminderCreation() async throws {
        let mockStore = MockEventStore()
        let eventKit = JMEventKit(mockEventStore: mockStore)

        let reminder = try await eventKit.createReminder(title: "테스트")

        XCTAssertEqual(reminder.title, "테스트")
        XCTAssertTrue(mockStore.saveCalled)
    }
}
```

## 🛡 오류 처리

JMEventKit은 `JMEventKitError`를 통해 상세한 오류 타입을 제공합니다:

```swift
do {
    try await JMEventKit.shared.createReminder(title: "테스트")
} catch JMEventKitError.permissionDenied {
    print("권한이 거부되었습니다. 설정에서 활성화하세요.")
} catch JMEventKitError.permissionRestricted {
    print("기기 설정에 의해 접근이 제한되었습니다.")
} catch JMEventKitError.calendarNotFound {
    print("기본 캘린더를 찾을 수 없습니다.")
} catch {
    print("예상치 못한 오류: \(error)")
}
```

사용 가능한 오류 타입:
- `permissionDenied` - 사용자가 접근을 거부함
- `permissionRestricted` - 자녀 보호 기능에 의해 접근 제한됨
- `reminderNotFound` - 미리 알림이 존재하지 않음
- `reminderCreationFailed` - 미리 알림 생성 실패
- `reminderDeletionFailed` - 미리 알림 삭제 실패
- `reminderUpdateFailed` - 미리 알림 업데이트 실패
- `eventNotFound` - 이벤트가 존재하지 않음
- `eventCreationFailed` - 이벤트 생성 실패
- `eventDeletionFailed` - 이벤트 삭제 실패
- `eventUpdateFailed` - 이벤트 업데이트 실패
- `saveFailed(Error)` - 이벤트 저장소에 저장 실패
- `fetchFailed(Error)` - 미리 알림 가져오기 실패
- `invalidConfiguration(String)` - 잘못된 구성
- `calendarNotFound` - 기본 캘린더를 찾을 수 없음
- `unknown(Error)` - 알 수 없는 오류 발생

## 🗺 로드맵

### Phase 1: 핵심 미리 알림 (v0.1.0) - ✅ 완료
- ✅ 기본 미리 알림 CRUD 작업
- ✅ iOS 17+ 권한 처리
- ✅ SwiftUI ObservableObject 통합
- ✅ 오류 처리
- ✅ 단위 테스트
- ✅ 문서화

### Phase 2: 고급 미리 알림 (v0.2.0) - ✅ 완료
- ✅ 반복 미리 알림
- ✅ 미리 알림 알람
- ✅ 우선순위 지원 (개별 미리 알림 색상은 EventKit API에서 미지원)
- ✅ 고급 필터링
- ✅ 검색 기능

### Phase 3: 캘린더 이벤트 (v0.3.0) - ✅ 완료
- ✅ 이벤트 생성 및 관리
- ✅ 종일 이벤트
- ✅ 반복 이벤트
- ✅ 이벤트 참석자 (읽기 전용, 쓰기는 UI 필요)

### Phase 4: 고급 기능 (v0.4.0+) - 계획 중
- [ ] 위치 기반 미리 알림
- [ ] 일괄 작업
- [ ] iCloud 동기화 변경 알림
- [ ] 고급 반복 규칙 (특정 요일 등)

## 🤝 기여하기

기여를 환영합니다! Pull Request를 자유롭게 제출해 주세요.

1. 저장소 포크
2. 기능 브랜치 생성 (`git checkout -b feature/AmazingFeature`)
3. 변경 사항 커밋 (`git commit -m 'Add some AmazingFeature'`)
4. 브랜치에 푸시 (`git push origin feature/AmazingFeature`)
5. Pull Request 열기

## 📄 라이선스

JMEventKit은 MIT 라이선스로 제공됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 👨‍💻 작성자

**Ray Kim** - [https://github.com/raykim2414](https://github.com/raykim2414)

## 🙏 감사의 말

- [Shift](https://github.com/vinhnx/Shift)에서 영감을 받았습니다
- iOS 개발 커뮤니티를 위해 ❤️로 제작되었습니다

---

**참고**: 이 라이브러리는 Apple의 EventKit 프레임워크를 감쌉니다. 일부 EventKit 객체(예: `EKReminder`)는 Swift 6에서 완전히 Sendable을 준수하지 않습니다. 이는 예상된 것이며 Apple이 프레임워크를 업데이트하면 해결될 것입니다.
