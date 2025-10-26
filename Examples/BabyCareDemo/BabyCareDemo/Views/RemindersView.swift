//
//  RemindersView.swift
//  BabyCareDemo
//
//  Reminders management with CRUD operations
//

import SwiftUI
import JMEventKit
import EventKit

struct RemindersView: View {
    @StateObject private var eventKit = JMEventKit.shared
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showCompleted = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                if eventKit.isFetching {
                    ProgressView("불러오는 중...")
                } else if filteredReminders.isEmpty {
                    emptyState
                } else {
                    remindersList
                }
            }
            .navigationTitle("미리 알림")
            .searchable(text: $searchText, prompt: "미리 알림 검색")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCompleted.toggle()
                    } label: {
                        Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReminderSheet(onAdd: {
                    await loadReminders()
                })
            }
            .task {
                await loadReminders()
            }
            .refreshable {
                await loadReminders()
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("미리 알림이 없습니다")
                .font(.headline)

            Text("+ 버튼을 눌러 새 미리 알림을 추가하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var remindersList: some View {
        List {
            ForEach(filteredReminders, id: \.calendarItemIdentifier) { reminder in
                ReminderListRow(
                    reminder: reminder,
                    onToggle: {
                        await toggleReminder(reminder)
                    },
                    onDelete: {
                        await deleteReminder(reminder)
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var filteredReminders: [EKReminder] {
        var reminders = showCompleted ? eventKit.reminders : eventKit.reminders.filter { !$0.isCompleted }

        if !searchText.isEmpty {
            reminders = reminders.filter { reminder in
                (reminder.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (reminder.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return reminders.sorted { (r1, r2) -> Bool in
            // Sort by completion status, then by due date, then by priority
            if r1.isCompleted != r2.isCompleted {
                return !r1.isCompleted
            }

            if let date1 = r1.dueDateComponents?.date, let date2 = r2.dueDateComponents?.date {
                return date1 < date2
            }

            return r1.priority < r2.priority
        }
    }

    // MARK: - Methods

    private func loadReminders() async {
        do {
            _ = try await eventKit.fetchReminders()
        } catch {
            errorMessage = "미리 알림 로드 실패: \(error.localizedDescription)"
        }
    }

    private func toggleReminder(_ reminder: EKReminder) async {
        do {
            if reminder.isCompleted {
                try await eventKit.uncompleteReminder(reminder)
            } else {
                try await eventKit.completeReminder(reminder)
            }
            await loadReminders()
        } catch {
            errorMessage = "상태 변경 실패: \(error.localizedDescription)"
        }
    }

    private func deleteReminder(_ reminder: EKReminder) async {
        do {
            try await eventKit.deleteReminder(reminder)
            await loadReminders()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - Reminder List Row

struct ReminderListRow: View {
    let reminder: EKReminder
    let onToggle: () async -> Void
    let onDelete: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task {
                    isProcessing = true
                    await onToggle()
                    isProcessing = false
                }
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(reminder.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title ?? "제목 없음")
                    .font(.body)
                    .strikethrough(reminder.isCompleted)
                    .foregroundColor(reminder.isCompleted ? .secondary : .primary)

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let dueDate = reminder.dueDateComponents?.date {
                        Label(formatDueDate(dueDate), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                    }

                    if let priority = priorityLabel(reminder.priority) {
                        Text(priority)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(reminder.priority).opacity(0.2))
                            .foregroundColor(priorityColor(reminder.priority))
                            .cornerRadius(4)
                    }

                    if let alarms = reminder.alarms, !alarms.isEmpty {
                        Label("\(alarms.count)", systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let rules = reminder.recurrenceRules, !rules.isEmpty {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await onDelete()
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .opacity(isProcessing ? 0.6 : 1.0)
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "오늘 \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "내일 \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            return formatter.string(from: date)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !reminder.isCompleted
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

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eventKit = JMEventKit.shared

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date().addingTimeInterval(3600)
    @State private var hasDueDate = true
    @State private var priority = 0
    @State private var isRecurring = false
    @State private var recurrenceFrequency = EKRecurrenceFrequency.daily
    @State private var hasAlarm = false
    @State private var alarmMinutesBefore = 15
    @State private var errorMessage: String?

    let onAdd: () async -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)

                    TextField("메모", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("마감일") {
                    Toggle("마감일 설정", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("날짜 및 시간", selection: $dueDate)
                    }
                }

                Section("우선순위") {
                    Picker("우선순위", selection: $priority) {
                        Text("없음").tag(0)
                        Text("높음 !!!").tag(1)
                        Text("중간 !!").tag(5)
                        Text("낮음 !").tag(9)
                    }
                }

                Section("반복") {
                    Toggle("반복 설정", isOn: $isRecurring)

                    if isRecurring {
                        Picker("빈도", selection: $recurrenceFrequency) {
                            Text("매일").tag(EKRecurrenceFrequency.daily)
                            Text("매주").tag(EKRecurrenceFrequency.weekly)
                            Text("매월").tag(EKRecurrenceFrequency.monthly)
                            Text("매년").tag(EKRecurrenceFrequency.yearly)
                        }
                    }
                }

                Section("알림") {
                    Toggle("알림 설정", isOn: $hasAlarm)

                    if hasAlarm {
                        Picker("알림 시간", selection: $alarmMinutesBefore) {
                            Text("정시").tag(0)
                            Text("5분 전").tag(5)
                            Text("15분 전").tag(15)
                            Text("30분 전").tag(30)
                            Text("1시간 전").tag(60)
                        }
                    }
                }
            }
            .navigationTitle("새 미리 알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        Task {
                            await createReminder()
                        }
                    }
                    .disabled(title.isEmpty)
                }
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

    private func createReminder() async {
        do {
            var alarms: [EKAlarm]? = nil
            if hasAlarm {
                let offset = TimeInterval(-alarmMinutesBefore * 60)
                alarms = [EKAlarm(relativeOffset: offset)]
            }

            if isRecurring {
                _ = try await eventKit.createRecurringReminder(
                    title: title,
                    notes: notes.isEmpty ? nil : notes,
                    startDate: hasDueDate ? dueDate : Date(),
                    frequency: recurrenceFrequency,
                    interval: 1,
                    priority: priority,
                    alarms: alarms
                )
            } else {
                _ = try await eventKit.createReminder(
                    title: title,
                    notes: notes.isEmpty ? nil : notes,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority,
                    alarms: alarms
                )
            }

            await onAdd()
            dismiss()
        } catch {
            errorMessage = "미리 알림 생성 실패: \(error.localizedDescription)"
        }
    }
}

#Preview {
    RemindersView()
}
