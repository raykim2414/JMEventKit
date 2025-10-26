//
//  EventsView.swift
//  BabyCareDemo
//
//  Calendar events management
//

import SwiftUI
import JMEventKit

struct EventsView: View {
    @StateObject private var eventKit = JMEventKit.shared
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month Calendar Header
                monthSelector

                // Events List
                if eventKit.isFetching {
                    ProgressView("불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("일정")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEventSheet(selectedDate: selectedDate, onAdd: {
                    await loadEvents()
                })
            }
            .task {
                await loadEvents()
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

    private var monthSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                    Task {
                        await loadEvents()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthYearString)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                    Task {
                        await loadEvents()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Week days
            weekDaysHeader

            // Calendar grid (simplified - showing selected date)
            selectedDateView
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }

    private var weekDaysHeader: some View {
        HStack(spacing: 0) {
            ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var selectedDateView: some View {
        VStack {
            Text(selectedDateString)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("이 기간에 일정이 없습니다")
                .font(.headline)

            Text("+ 버튼을 눌러 새 일정을 추가하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsList: some View {
        List {
            ForEach(groupedEvents, id: \.key) { group in
                Section(header: Text(formatSectionDate(group.key))) {
                    ForEach(group.value, id: \.eventIdentifier) { event in
                        EventListRow(
                            event: event,
                            onDelete: {
                                await deleteEvent(event)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: selectedDate)
    }

    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: selectedDate)
    }

    private var filteredEvents: [EKEvent] {
        eventKit.events.sorted { $0.startDate < $1.startDate }
    }

    private var groupedEvents: [(key: Date, value: [EKEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event -> Date in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Methods

    private func loadEvents() async {
        do {
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

            _ = try await eventKit.fetchEvents(
                from: startOfMonth,
                to: endOfMonth
            )
        } catch {
            errorMessage = "일정 로드 실패: \(error.localizedDescription)"
        }
    }

    private func deleteEvent(_ event: EKEvent) async {
        do {
            try await eventKit.deleteEvent(event)
            await loadEvents()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

// MARK: - Event List Row

struct EventListRow: View {
    let event: EKEvent
    let onDelete: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title ?? "제목 없음")
                        .font(.headline)

                    if event.isAllDay {
                        Text("종일")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(formatTime(event.startDate)) - \(formatTime(event.endDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let rules = event.recurrenceRules, !rules.isEmpty {
                    Image(systemName: "repeat")
                        .foregroundColor(.secondary)
                }
            }

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let alarms = event.alarms, !alarms.isEmpty {
                Label("\(alarms.count)개 알림", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Add Event Sheet

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eventKit = JMEventKit.shared

    let selectedDate: Date
    let onAdd: () async -> Void

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var isRecurring = false
    @State private var recurrenceFrequency = EKRecurrenceFrequency.weekly
    @State private var hasAlarm = false
    @State private var alarmMinutesBefore = 15
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)
                    TextField("위치", text: $location)
                    TextField("메모", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("시간") {
                    Toggle("종일", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker("날짜", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("시작", selection: $startDate)
                        DatePicker("종료", selection: $endDate)
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
                            Text("1일 전").tag(1440)
                        }
                    }
                }
            }
            .navigationTitle("새 일정")
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
                            await createEvent()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                startDate = selectedDate
                endDate = selectedDate.addingTimeInterval(3600)
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

    private func createEvent() async {
        do {
            var alarms: [EKAlarm]? = nil
            if hasAlarm {
                let offset = TimeInterval(-alarmMinutesBefore * 60)
                alarms = [EKAlarm(relativeOffset: offset)]
            }

            if isAllDay {
                _ = try await eventKit.createAllDayEvent(
                    title: title,
                    date: startDate,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    alarms: alarms
                )
            } else if isRecurring {
                let recurrenceEnd = Calendar.current.date(byAdding: .month, value: 3, to: startDate)
                _ = try await eventKit.createRecurringEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    frequency: recurrenceFrequency,
                    interval: 1,
                    recurrenceEnd: recurrenceEnd,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    alarms: alarms
                )
            } else {
                _ = try await eventKit.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    alarms: alarms
                )
            }

            await onAdd()
            dismiss()
        } catch {
            errorMessage = "일정 생성 실패: \(error.localizedDescription)"
        }
    }
}

#Preview {
    EventsView()
}
