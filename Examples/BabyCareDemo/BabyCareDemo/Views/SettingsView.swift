//
//  SettingsView.swift
//  BabyCareDemo
//
//  Settings and permissions management
//

import SwiftUI
import JMEventKit

struct SettingsView: View {
    @StateObject private var eventKit = JMEventKit.shared
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""

    var body: some View {
        NavigationView {
            List {
                // Permission Section
                Section {
                    permissionRow(
                        title: "미리 알림 권한",
                        status: authorizationStatusText,
                        icon: "checklist",
                        color: authorizationStatusColor
                    )

                    if !eventKit.isAuthorized() {
                        Button {
                            Task {
                                await requestPermission()
                            }
                        } label: {
                            Label("권한 요청", systemImage: "hand.raised.fill")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("권한")
                } footer: {
                    Text("미리 알림과 캘린더를 사용하려면 권한이 필요합니다.")
                }

                // Calendar Info
                Section {
                    if let calendar = eventKit.defaultCalendar() {
                        LabeledContent("미리 알림 캘린더", value: calendar.title)
                    }

                    if let calendar = eventKit.defaultEventCalendar() {
                        LabeledContent("일정 캘린더", value: calendar.title)
                    }
                } header: {
                    Text("캘린더 정보")
                }

                // Statistics
                Section {
                    LabeledContent("미리 알림 개수", value: "\(eventKit.reminders.count)")
                    LabeledContent("일정 개수", value: "\(eventKit.events.count)")
                } header: {
                    Text("통계")
                }

                // App Info
                Section {
                    LabeledContent("앱 이름", value: "쑥쑥찰칵 데모")
                    LabeledContent("버전", value: "1.0.0")
                    LabeledContent("JMEventKit", value: "0.3.0")
                } header: {
                    Text("앱 정보")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이 앱은 JMEventKit 라이브러리를 사용한 샘플 앱입니다.")
                        Text("JMEventKit은 EventKit을 쉽게 사용할 수 있도록 도와주는 Swift 패키지입니다.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // Links
                Section {
                    Link(destination: URL(string: "https://github.com/raykim2414/JMEventKit")!) {
                        Label("GitHub 저장소", systemImage: "link")
                    }

                    Link(destination: URL(string: "https://github.com/raykim2414/JMEventKit/blob/main/README.ko.md")!) {
                        Label("문서 보기", systemImage: "doc.text")
                    }
                } header: {
                    Text("링크")
                }

                // Developer
                Section {
                    LabeledContent("개발자", value: "Ray Kim")
                    Link(destination: URL(string: "https://github.com/raykim2414")!) {
                        Label("GitHub 프로필", systemImage: "person.circle")
                    }
                } header: {
                    Text("개발자")
                }
            }
            .navigationTitle("설정")
            .alert("권한", isPresented: $showingPermissionAlert) {
                Button("확인", role: .cancel) {}
                if !eventKit.isAuthorized() {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } message: {
                Text(permissionMessage)
            }
        }
    }

    // MARK: - View Components

    private func permissionRow(title: String, status: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)

                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
    }

    // MARK: - Computed Properties

    private var authorizationStatusText: String {
        switch eventKit.authorizationStatus {
        case .notDetermined:
            return "권한 요청 필요"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorized, .fullAccess:
            return "허용됨"
        case .writeOnly:
            return "쓰기 전용"
        @unknown default:
            return "알 수 없음"
        }
    }

    private var authorizationStatusColor: Color {
        switch eventKit.authorizationStatus {
        case .authorized, .fullAccess:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined, .writeOnly:
            return .orange
        @unknown default:
            return .gray
        }
    }

    // MARK: - Methods

    private func requestPermission() async {
        do {
            let granted = try await eventKit.requestReminderAuthorization()
            if granted {
                permissionMessage = "권한이 허용되었습니다!"
            } else {
                permissionMessage = "권한이 거부되었습니다. 설정에서 권한을 허용해주세요."
            }
            showingPermissionAlert = true
        } catch {
            permissionMessage = "권한 요청 중 오류가 발생했습니다: \(error.localizedDescription)"
            showingPermissionAlert = true
        }
    }
}

#Preview {
    SettingsView()
}
