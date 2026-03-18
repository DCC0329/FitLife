import SwiftUI
import SwiftData

struct WeightCalendarView: View {
    @Query(sort: \WeightRecord.date, order: .forward) private var allWeightRecords: [WeightRecord]
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
    private let downColor = Color(hex: "99CDD8")   // 莫兰迪蓝 - 体重下降
    private let upColor = Color(hex: "F3C3B2")     // 莫兰迪粉 - 体重上升
    private let neutralColor = Color(hex: "CFD8C4") // 莫兰迪灰绿 - 不变

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdayHeader
            dayGrid
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(AppTheme.primaryGreen)
                    .font(.caption)
            }
            Spacer()
            Text(monthYearString)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.primaryGreen)
                    .font(.caption)
            }
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Day Grid

    private var dayGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    weightDayCell(for: date)
                        .frame(height: 56)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    private func weightDayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let weight = weightForDate(date)
        let prevWeight = previousDayWeight(before: date)
        let change: Double? = {
            guard let w = weight, let p = prevWeight else { return nil }
            return w - p
        }()

        return VStack(spacing: 0) {
            // Day number - fixed at top
            Text("\(day)")
                .font(.system(size: 11))
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? Color(hex: "657166") : .primary)
                .frame(width: 22, height: 22)
                .background(isToday ? Color(hex: "DAEBE3") : Color.clear)
                .clipShape(Circle())
                .frame(height: 22)

            // Content area - fixed height, clipped
            VStack(spacing: 1) {
                if let weight = weight {
                    if let change = change {
                        HStack(spacing: 1) {
                            Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                                .font(.system(size: 6, weight: .bold))
                            Text(String(format: "%.2f", abs(change)))
                                .font(.system(size: 7, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "657166"))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(change < 0 ? downColor.opacity(0.5) : change > 0 ? upColor.opacity(0.5) : neutralColor.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text(String(format: "%.2f", weight))
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 34, alignment: .top)
            .clipped()
        }
        .frame(height: 56)
    }

    // MARK: - Data Helpers

    private func weightForDate(_ date: Date) -> Double? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return allWeightRecords.last(where: { $0.date >= startOfDay && $0.date < endOfDay })?.weight
    }

    private func previousDayWeight(before date: Date) -> Double? {
        let prevDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return weightForDate(prevDay)
    }

    // MARK: - Calendar Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = (firstWeekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
}

#Preview {
    WeightCalendarView()
        .padding()
        .modelContainer(for: WeightRecord.self, inMemory: true)
}
