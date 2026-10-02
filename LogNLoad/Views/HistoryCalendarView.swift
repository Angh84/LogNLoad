import SwiftUI

/// The month grid above the History list: one dot per Workout on its day, today ringed, future days faint. Paging
/// stops at the current month.
struct HistoryCalendarView: View {
    /// The first day of the month shown.
    @Binding var month: Date
    /// Finished Workouts, newest first.
    let workouts: [Workout]
    /// Tapping a day hands up its first Workout in the list.
    let onSelect: (Workout) -> Void
    let onPage: (Date) -> Void
    private let calendar = Calendar.current

    /// The first moment of the month `date` falls in.
    static func monthStart(of date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    var body: some View {
        let inMonth = workouts.filter { $0.startedAt.map { calendar.isDate($0, equalTo: month, toGranularity: .month) } ?? false }
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DisplayFormat.monthHeading(month, calendar: calendar))
                        .font(.headline)
                    Text(DisplayFormat.monthSummary(month, workouts: workouts, calendar: calendar))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Previous month", systemImage: "chevron.left") { page(by: -1) }
                Button("Next month", systemImage: "chevron.right") { page(by: 1) }
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(DisplayFormat.monthDays(month, calendar: calendar).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, workouts: inMonth.filter { $0.startedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false })
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
            if drag.translation.width < -60 { page(by: 1) }
            if drag.translation.width > 60 { page(by: -1) }
        })
    }

    /// `workouts` are the day's, newest first.
    private func dayCell(_ day: Date, workouts: [Workout]) -> some View {
        Button {
            if let first = workouts.first { onSelect(first) }
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 30, height: 30)
                    .overlay {
                        if calendar.isDateInToday(day) {
                            Circle().strokeBorder(.tint, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(workouts) { _ in
                        Circle().fill(.tint).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .opacity(day > .now ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(workouts.isEmpty)
    }

    /// Narrow weekday names for one week, starting on the Region's first weekday.
    private var weekdaySymbols: [String] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: month)?.start ?? month
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart)?.formatted(.dateTime.weekday(.narrow)) }
    }

    /// Moves to the previous or next month and scrolls the list there. Never past the current month.
    private func page(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month).map(Self.monthStart),
              calendar.compare(next, to: .now, toGranularity: .month) != .orderedDescending else { return }
        month = next
        onPage(next)
    }
}
