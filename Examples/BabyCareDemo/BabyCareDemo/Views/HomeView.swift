//
//  HomeView.swift
//  BabyCareDemo
//
//  Home screen showing today's schedule and reminders
//

import SwiftUI
import JMEventKit
import EventKit

struct HomeView: View {
    @StateObject private var eventKit = JMEventKit.shared
    @State private var todayReminders: [EKReminder] = []
    @State private var todayEvents: [EKEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Today's Summary
                    summarySection

                    // Upcoming Reminders
                    if !todayReminders.isEmpty {
                        remindersSection
                    }

                    // Today's Events
                    if !todayEvents.isEmpty {
                        eventsSection
                    }

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("쑥쑥찰칵")
            .refreshable {
                await loadTodayData()
            }
            .task {
                await requestPermissionAndLoad()
            }
            .alert("오류", isPresented: .constant(errorMessage != nil)) {
                Button("확인") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("안녕하세요!")
                .font(.title)
                .fontWeight(.bold)

            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "미리 알림",
                count: todayReminders.count,
                icon: "bell.fill",
                color: .blue
            )

            SummaryCard(
                title: "일정",
                count: todayEvents.count,
                icon: "calendar",
                color: .orange
            )
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 미리 알림")
                .font(.headline)

            ForEach(todayReminders.prefix(5), id: \.calendarItemIdentifier) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 일정")
                .font(.headline)

            ForEach(todayEvents.prefix(5), id: \.eventIdentifier) { event in
                EventRow(event: event)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 작업")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "수유 알림",
                    icon: "drop.fill",
                    color: .blue
                ) {
                    await createFeedingReminder()
                }

                QuickActionButton(
                    title: "기저귀 알림",
                    icon: "square.3.layers.3d",
                    color: .green
                ) {
                    await createDiaperReminder()
                }
            }

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "목욕 알림",
                    icon: "drop.triangle.fill",
                    color: .purple
                ) {
                    await createBathReminder()
                }

                QuickActionButton(
                    title: "검진 일정",
                    icon: "cross.case.fill",
                    color: .red
                ) {
                    await createCheckupEvent()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    // MARK: - Methods

    private func requestPermissionAndLoad() async {
        do {
            _ = try await eventKit.requestReminderAuthorization()
            await loadTodayData()
        } catch {
            errorMessage = "권한 요청 실패: \(error.localizedDescription)"
        }
    }

    private func loadTodayData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch today's reminders
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let reminders = try await eventKit.fetchIncompleteReminders(
                from: startOfDay,
                to: endOfDay
            )
            todayReminders = reminders

            // Fetch today's events
            let events = try await eventKit.fetchEvents(
                from: startOfDay,
                to: endOfDay
            )
            todayEvents = events
        } catch {
            errorMessage = "데이터 로드 실패: \(error.localizedDescription)"
        }
    }

    private func createFeedingReminder() async {
        do {
            let alarm = EKAlarm(relativeOffset: -300) // 5분 전 알림
            _ = try await eventKit.createRecurringReminder(
                title: "수유 시간",
                notes: "아기에게 분유/모유를 먹이세요",
                startDate: Date().addingTimeInterval(3 * 60 * 60), // 3시간 후
                frequency: .daily,
                interval: 1,
                priority: 1,
                alarms: [alarm]
            )
            await loadTodayData()
        } catch {
            errorMessage = "미리 알림 생성 실패: \(error.localizedDescription)"
        }
    }

    private func createDiaperReminder() async {
        do {
            _ = try await eventKit.createReminder(
                title: "기저귀 확인",
                notes: "기저귀 갈아주기",
                dueDate: Date().addingTimeInterval(2 * 60 * 60), // 2시간 후
                priority: 5
            )
            await loadTodayData()
        } catch {
            errorMessage = "미리 알림 생성 실패: \(error.localizedDescription)"
        }
    }

    private func createBathReminder() async {
        do {
            _ = try await eventKit.createReminder(
                title: "목욕 시간",
                notes: "아기 목욕시키기",
                dueDate: Date().addingTimeInterval(4 * 60 * 60), // 4시간 후
                priority: 5
            )
            await loadTodayData()
        } catch {
            errorMessage = "미리 알림 생성 실패: \(error.localizedDescription)"
        }
    }

    private func createCheckupEvent() async {
        do {
            let startDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1주일 후
            let endDate = startDate.addingTimeInterval(60 * 60) // 1시간 지속

            _ = try await eventKit.createEvent(
                title: "소아과 검진",
                startDate: startDate,
                endDate: endDate,
                location: "OO 소아과",
                notes: "정기 검진 예약"
            )
            await loadTodayData()
        } catch {
            errorMessage = "일정 생성 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ReminderRow: View {
    let reminder: EKReminder

    var body: some View {
        HStack {
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(reminder.isCompleted ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "제목 없음")
                    .font(.subheadline)

                if let dueDate = reminder.dueDateComponents?.date {
                    Text(formatTime(dueDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let priority = priorityLabel(reminder.priority) {
                Text(priority)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(reminder.priority).opacity(0.2))
                    .foregroundColor(priorityColor(reminder.priority))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func priorityLabel(_ priority: Int) -> String? {
        switch priority {
        case 1...4: return "높음"
        case 5: return "중간"
        case 6...9: return "낮음"
        default: return nil
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1...4: return .red
        case 5: return .orange
        case 6...9: return .blue
        default: return .gray
        }
    }
}

struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "제목 없음")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    if event.isAllDay {
                        Text("종일")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(formatTime(event.startDate)) - \(formatTime(event.endDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let location = event.location {
                        Text("• \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        Button {
            Task {
                isProcessing = true
                await action()
                isProcessing = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.gradient)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
    }
}

#Preview {
    HomeView()
}
