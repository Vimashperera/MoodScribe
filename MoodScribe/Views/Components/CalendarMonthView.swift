import SwiftUI

struct CalendarMonthView: View {
    let month: Date
    let selectedDay: Date?
    var sentimentForDay: (Date) -> SentimentType?
    var onSelect: (Date) -> Void
    var onShiftMonth: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragTranslation: CGFloat = 0

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button {
                    onShiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")

                Button {
                    onShiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(cells) { cell in
                    dayCell(cell)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.calendar)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            onShiftMonth(direction == .increment ? 1 : -1)
        }
        .offset(x: dragTranslation)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    dragTranslation = value.translation.width / 4
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragTranslation = 0
                    }
                    if value.translation.width < -48 {
                        onShiftMonth(1)
                    } else if value.translation.width > 48 {
                        onShiftMonth(-1)
                    }
                }
        )
        .animation(.easeInOut(duration: 0.25), value: month)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var cells: [DayCell] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [DayCell] = (0..<leading).map { DayCell(id: "blank-\($0)", date: nil) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                result.append(DayCell(id: date.formatted(date: .complete, time: .omitted), date: date))
            }
        }
        return result
    }

    @ViewBuilder
    private func dayCell(_ cell: DayCell) -> some View {
        if let date = cell.date {
            let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            let mood = sentimentForDay(date)
            Button {
                onSelect(date)
            } label: {
                VStack(spacing: 4) {
                    Text(date, format: .dateTime.day())
                        .font(.body)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Circle()
                        .fill(mood?.color(in: colorScheme) ?? Color.clear)
                        .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.04))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(mood?.rawValue ?? "No entry")
        } else {
            Color.clear
                .frame(minHeight: 44)
        }
    }
}

private struct DayCell: Identifiable {
    let id: String
    let date: Date?
}
