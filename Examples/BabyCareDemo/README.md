# BabyCareDemo

JMEventKit을 사용한 실제 동작하는 육아 미리 알림 샘플 앱입니다.

<img src="https://img.shields.io/badge/iOS-18.0+-blue.svg" />
<img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" />
<img src="https://img.shields.io/badge/SwiftUI-3.0+-green.svg" />

## 📱 기능

### 홈 화면
- 오늘의 미리 알림과 일정 요약
- 빠른 작업 버튼으로 즉시 미리 알림 생성
  - 수유 알림 (3시간마다 반복)
  - 기저귀 알림
  - 목욕 알림
  - 검진 일정

### 미리 알림
- 미리 알림 생성, 수정, 삭제 (CRUD)
- 반복 미리 알림 설정 (매일, 매주, 매월, 매년)
- 우선순위 설정 (높음, 중간, 낮음)
- 알람 추가 (정시, 5분전, 15분전, 30분전, 1시간전)
- 검색 기능
- 완료된 항목 표시/숨김
- Swipe to delete

### 일정
- 캘린더 이벤트 생성, 삭제
- 종일 이벤트 지원
- 반복 이벤트 설정
- 월별 보기
- 위치 설정

### 설정
- 권한 상태 확인
- 권한 요청
- 캘린더 정보 표시
- 통계 (미리 알림/일정 개수)
- 앱 정보 및 링크

## 🚀 실행 방법

### 1. Xcode 프로젝트 생성

이 샘플 앱은 모든 소스 파일이 준비되어 있지만, Xcode 프로젝트 파일을 직접 생성해야 합니다.

**방법 A: Xcode에서 직접 생성 (권장)**

1. **Xcode 열기** → File > New > Project
2. **iOS > App** 선택 → Next
3. 다음 설정 입력:
   - Product Name: `BabyCareDemo`
   - Team: 본인 계정 선택
   - Organization Identifier: `com.yourname`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `None`
4. **Save** 위치: `Examples/BabyCareDemo` 폴더 선택
5. 생성 완료!

### 2. JMEventKit 패키지 추가

1. Xcode에서 BabyCareDemo 프로젝트 열기
2. Project Navigator에서 프로젝트 파일 선택
3. **Package Dependencies** 탭 선택
4. `+` 버튼 클릭
5. `Add Local...` 선택
6. 상위 폴더의 JMEventKit 패키지 선택 (../../)
7. `Add Package` 클릭
8. `JMEventKit` 라이브러리를 타겟에 추가

### 3. 기존 파일 교체

생성된 프로젝트의 기본 파일들을 이미 준비된 파일들로 교체합니다:

```bash
# BabyCareDemo 폴더로 이동
cd Examples/BabyCareDemo

# Xcode가 생성한 기본 파일들을 삭제하고 준비된 파일 사용
# (또는 Xcode에서 직접 드래그 앤 드롭)
```

**교체할 파일들:**
- `BabyCareDemoApp.swift`
- `ContentView.swift`
- `Views/` 폴더 전체
- `Assets.xcassets/`
- `Info.plist`

### 4. 실행

1. 시뮬레이터 또는 실제 기기 선택
2. `Cmd + R` 또는 Run 버튼 클릭
3. 권한 요청 시 "Allow" 선택

**방법 B: Package.swift 사용 (개발자용)**

Package.swift에 executable target을 추가할 수도 있지만, iOS 앱은 Xcode 프로젝트가 필요합니다.

## 📁 프로젝트 구조

```
BabyCareDemo/
├── BabyCareDemo/
│   ├── BabyCareDemoApp.swift      # 앱 엔트리 포인트
│   ├── ContentView.swift           # 메인 탭 뷰
│   ├── Views/
│   │   ├── HomeView.swift         # 홈 화면
│   │   ├── RemindersView.swift    # 미리 알림 관리
│   │   ├── EventsView.swift       # 일정 관리
│   │   └── SettingsView.swift     # 설정
│   ├── Assets.xcassets/
│   └── Info.plist
└── README.md
```

## 💡 주요 코드 예제

### 미리 알림 생성 (반복 + 알람)

```swift
let alarm = EKAlarm(relativeOffset: -300) // 5분 전

let reminder = try await JMEventKit.shared.createRecurringReminder(
    title: "수유 시간",
    notes: "아기에게 분유/모유를 먹이세요",
    startDate: Date().addingTimeInterval(3 * 60 * 60),
    frequency: .daily,
    interval: 1,
    priority: 1,
    alarms: [alarm]
)
```

### 캘린더 이벤트 생성

```swift
let event = try await JMEventKit.shared.createEvent(
    title: "소아과 검진",
    startDate: startDate,
    endDate: endDate,
    location: "OO 소아과",
    notes: "정기 검진 예약"
)
```

### 검색

```swift
let results = try await JMEventKit.shared.searchReminders(
    query: "수유",
    includeCompleted: false
)
```

## 🎨 UI 특징

- **네이티브 SwiftUI** 디자인
- **다크 모드** 지원
- **한글 로컬라이제이션**
- **SF Symbols** 아이콘 사용
- **Pull to refresh** 지원
- **Swipe actions** 지원

## 🔐 필요한 권한

앱 실행 시 다음 권한을 요청합니다:

- **미리 알림 접근** (`NSRemindersFullAccessUsageDescription`)
- **캘린더 접근** (`NSCalendarsFullAccessUsageDescription`)

Info.plist에 이미 설정되어 있습니다.

## 🐛 트러블슈팅

### "Module 'JMEventKit' not found"
→ Package Dependencies에서 JMEventKit이 추가되었는지 확인하세요.

### 권한 거부 시
→ 설정 > 개인정보 보호 및 보안 > 미리 알림/캘린더에서 권한 허용

### 시뮬레이터에서 미리 알림이 보이지 않음
→ 시뮬레이터의 미리 알림 앱에서 기본 목록을 만들어주세요.

## 📚 학습 리소스

이 샘플 앱에서 배울 수 있는 것들:

1. **JMEventKit 사용법**
   - 권한 요청
   - CRUD 작업
   - 반복 항목
   - 알람 설정

2. **SwiftUI 패턴**
   - @StateObject 사용
   - NavigationView + TabView
   - Sheet 모달
   - List + SwipeActions

3. **비동기 프로그래밍**
   - async/await
   - Task
   - Error handling

## 🤝 기여하기

이 샘플 앱을 개선하고 싶으시면:

1. Fork this repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 라이선스

MIT License - JMEventKit과 동일한 라이선스를 따릅니다.

## 👨‍💻 만든 사람

**Ray Kim** - [https://github.com/raykim2414](https://github.com/raykim2414)

JMEventKit 라이브러리와 함께 사용하세요!
