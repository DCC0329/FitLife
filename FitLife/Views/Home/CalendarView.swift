import SwiftUI
import SwiftData

// MARK: - WorkoutInfo

struct WorkoutInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let duration: Int       // minutes
    let calories: Double
}

// MARK: - Morandi Exercise Colors

struct MorandiColors {
    static let palette: [Color] = [
        Color(hex: "99CDD8"),  // 蓝
        Color(hex: "DAEBE3"),  // 薄荷
        Color(hex: "FDE8D3"),  // 桃
        Color(hex: "CFD8C4"),  // 鼠尾草
        Color(hex: "C9B8D8"),  // 薰衣草紫
        Color(hex: "F5D9A8"),  // 暖黄
        Color(hex: "A8C8D8"),  // 雾蓝
        Color(hex: "D8C4B8"),  // 沙棕
        Color(hex: "B8D4C0"),  // 青绿
        Color(hex: "D4B8C8"),  // 玫瑰灰
        Color(hex: "B8C4D8"),  // 灰蓝
        Color(hex: "D8D4A8"),  // 橄榄黄
    ]

    static let period = Color(hex: "F3C3B2")  // 生理期用鲑鱼粉
    static let mood = Color(hex: "DAEBE3")    // 心情用薄荷

    // 同一运动名称始终用同一颜色（用稳定 hash，不受 Swift 随机种子影响）
    static func color(for exerciseName: String) -> Color {
        let stableHash = exerciseName.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return palette[abs(stableHash) % palette.count]
    }
}

// MARK: - CalendarView

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var workoutData: [Date: [WorkoutInfo]]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .forward) private var exerciseRecords: [ExerciseRecord]
    @Query(sort: \PeriodRecord.date, order: .forward) private var periodRecords: [PeriodRecord]
    @Query(sort: \MoodRecord.date, order: .forward) private var moodRecords: [MoodRecord]

    @State private var displayedMonth: Date = Date()
    @State private var showDayDetail = false
    @State private var tappedDate: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
    private let primaryGreen = AppTheme.primaryGreen

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdayHeader
            dayGrid
        }
        .sheet(isPresented: $showDayDetail) {
            DayDetailSheet(
                date: tappedDate,
                workouts: workoutsForDate(tappedDate),
                manualExercises: manualExercisesForDate(tappedDate),
                period: periodForDate(tappedDate),
                mood: moodForDate(tappedDate)
            )
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(primaryGreen)
                    .font(.caption)
            }
            Spacer()
            Text(monthYearString)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(primaryGreen)
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
                    dayCell(for: date)
                        .frame(height: 56)
                        .clipped()
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let workouts = workoutsForDate(date)
        let manualExercises = manualExercisesForDate(date)
        let hasPeriod = periodForDate(date) != nil
        let mood = moodForDate(date)
        let hasActivity = !workouts.isEmpty || !manualExercises.isEmpty || hasPeriod || mood != nil

        return Button {
            tappedDate = date
            selectedDate = date
            if hasActivity {
                showDayDetail = true
            }
        } label: {
            VStack(spacing: 0) {
                // Day number - always at top, fixed position
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color(hex: "DAEBE3"))
                            .frame(width: 22, height: 22)
                    }

                    Text("\(day)")
                        .font(.system(size: 11))
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundColor(isToday ? Color(hex: "657166") : .primary)

                    // Mood sticker
                    if let mood = mood {
                        Image(mood.mood.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .opacity(0.7)
                            .offset(x: 13, y: -5)
                    }
                }
                .frame(height: 22)

                // Content area - fixed height, clipped
                VStack(spacing: 1) {
                    if hasPeriod {
                        Circle()
                            .fill(MorandiColors.period)
                            .frame(width: 4, height: 4)
                    }

                    let exerciseLabels: [(name: String, duration: Int)] =
                        manualExercises.map { ($0.name, $0.duration) } +
                        workouts.map { ($0.name, $0.duration) }
                    ForEach(Array(exerciseLabels.prefix(2).enumerated()), id: \.offset) { _, item in
                        Text("\(item.name) \(item.duration)m")
                            .font(.system(size: 6))
                            .foregroundColor(Color(hex: "657166"))
                            .lineLimit(1)
                            .padding(.horizontal, 2)
                            .background(MorandiColors.color(for: item.name).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    if exerciseLabels.count > 2 {
                        Text("+\(exerciseLabels.count - 2)")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                    }
                    if exerciseLabels.isEmpty && hasPeriod {
                        Text("生理期")
                            .font(.system(size: 6))
                            .foregroundColor(Color(hex: "657166"))
                            .padding(.horizontal, 2)
                            .background(MorandiColors.period.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                .frame(height: 34, alignment: .top)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Helpers

    private func workoutsForDate(_ date: Date) -> [WorkoutInfo] {
        let startOfDay = calendar.startOfDay(for: date)
        return workoutData[startOfDay] ?? []
    }

    private func manualExercisesForDate(_ date: Date) -> [ExerciseRecord] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return exerciseRecords.filter { $0.date >= startOfDay && $0.date < endOfDay }
    }

    private func periodForDate(_ date: Date) -> PeriodRecord? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return periodRecords.first { $0.date >= startOfDay && $0.date < endOfDay }
    }

    private func moodForDate(_ date: Date) -> MoodRecord? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return moodRecords.last { $0.date >= startOfDay && $0.date < endOfDay }
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

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let date: Date
    let workouts: [WorkoutInfo]
    let manualExercises: [ExerciseRecord]
    let period: PeriodRecord?
    let mood: MoodRecord?

    var body: some View {
        NavigationStack {
            List {
                // HealthKit workouts
                if !workouts.isEmpty {
                    Section("Apple Watch 运动") {
                        ForEach(workouts) { workout in
                            HStack {
                                Text(workout.name)
                                    .font(.callout)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MorandiColors.color(for: workout.name).opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Spacer()
                                Text("\(workout.duration)分钟")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f千卡", workout.calories))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.primaryGreen)
                            }
                        }
                    }
                }

                // Manual exercises
                if !manualExercises.isEmpty {
                    Section("手动记录运动") {
                        ForEach(manualExercises) { exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.callout)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MorandiColors.color(for: exercise.name).opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Spacer()
                                Text("\(exercise.duration)分钟")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f千卡", exercise.calories))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.primaryGreen)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(exercise)
                                    try? modelContext.save()
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Period
                if let period = period {
                    Section("生理期") {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(MorandiColors.period)
                            Text("生理期")
                                .font(.callout)
                            if let note = period.note, !note.isEmpty {
                                Spacer()
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if workouts.isEmpty && manualExercises.isEmpty && period == nil {
                    Text("当天没有记录")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 记录"
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarView(
        selectedDate: .constant(Date()),
        workoutData: .constant([:])
    )
    .padding()
    .modelContainer(for: [ExerciseRecord.self, PeriodRecord.self, MoodRecord.self], inMemory: true)
}
