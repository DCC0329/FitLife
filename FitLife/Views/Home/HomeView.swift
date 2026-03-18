import SwiftUI
import SwiftData

enum CalendarMode {
    case exercise, weight
}

// MARK: - HomeView

struct HomeView: View {
    @StateObject private var healthManager = HealthKitManager()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .forward) private var allExerciseRecords: [ExerciseRecord]
    @Query(sort: \DrinkRecord.date, order: .forward) private var allDrinkRecords: [DrinkRecord]
    @State private var showManualEntry = false
    @State private var showSleepInput = false
    @State private var selectedCalendarDate = Date()
    @State private var workoutData: [Date: [WorkoutInfo]] = [:]
    @State private var calendarMode: CalendarMode = .exercise
    @State private var sleepBedTime: Date?
    @State private var sleepWakeTime: Date?
    @State private var sleepDuration: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Stat Cards
                    statCardsSection

                    // MARK: Mood & Sleep (side by side)
                    HStack(spacing: 12) {
                        // 今日心情（左）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("今日心情")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            MoodPickerCompact()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surfaceColor)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)

                        // 睡眠概况（右）- 点击进入历史
                        NavigationLink {
                            SleepHistoryView()
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("睡眠概况")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                sleepCompactContent
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surfaceColor)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Calendar with toggle
                    calendarSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationTitle("今日概览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showManualEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntrySheet()
            }
            .sheet(isPresented: $showSleepInput) {
                ManualSleepInputView()
                    .onDisappear {
                        Task { await refreshSleepData() }
                    }
            }
        }
        .task {
            await healthManager.requestAuthorization()
            async let _ = healthManager.fetchTodaySteps()
            async let _ = healthManager.fetchTodayCalories()
            async let _ = healthManager.fetchTodayExerciseMinutes()
            async let _ = healthManager.fetchTodayDistance()

            // Fetch sleep data: try HealthKit first, then SwiftData manual records
            if let sleepData = await healthManager.fetchSleepData(for: Date()) {
                sleepBedTime = sleepData.bedTime
                sleepWakeTime = sleepData.wakeTime
                sleepDuration = sleepData.duration
            } else {
                // Check for manually recorded sleep in SwiftData
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
                let predicate = #Predicate<SleepRecord> { $0.date >= yesterday }
                let descriptor = FetchDescriptor<SleepRecord>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
                if let records = try? modelContext.fetch(descriptor), let latest = records.first {
                    sleepBedTime = latest.bedTime
                    sleepWakeTime = latest.wakeTime
                    sleepDuration = latest.durationHours * 3600
                }
            }

            await loadWorkoutData()
        }
    }

    // MARK: - Stat Cards Section

    private var todayManualExercises: [ExerciseRecord] {
        let cal = Calendar.current
        return allExerciseRecords.filter { cal.isDateInToday($0.date) }
    }

    private var totalTodayCalories: Double {
        healthManager.todayCalories + todayManualExercises.reduce(0) { $0 + $1.calories }
    }

    private var totalTodayMinutes: Double {
        healthManager.todayExerciseMinutes + todayManualExercises.reduce(0) { $0 + Double($1.duration) }
    }

    private var todayDrinkTotal: Int {
        let cal = Calendar.current
        return allDrinkRecords.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private var statCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                NavigationLink {
                    StepsHistoryView()
                } label: {
                    StatCard(
                        icon: "figure.walk",
                        title: "步数",
                        value: String(format: "%.0f", healthManager.todaySteps),
                        color: AppTheme.primaryGreen
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ExerciseHistoryView()
                } label: {
                    StatCard(
                        icon: "flame.fill",
                        title: "消耗(千卡)",
                        value: String(format: "%.0f", totalTodayCalories),
                        color: AppTheme.lavender
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DrinkHistoryView()
                } label: {
                    StatCard(
                        icon: "drop.fill",
                        title: "饮水(ml)",
                        value: "\(todayDrinkTotal)",
                        color: Color(hex: "99CDD8")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ExerciseHistoryView()
                } label: {
                    StatCard(
                        icon: "timer",
                        title: "运动(分钟)",
                        value: String(format: "%.0f", totalTodayMinutes),
                        color: AppTheme.softBlue
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Sleep Summary

    private var sleepSummaryContent: some View {
        let hasSleepData = sleepBedTime != nil || sleepWakeTime != nil || sleepDuration > 0
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.softIndigo)
                Text("昨晚睡眠")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if hasSleepData {
                HStack(spacing: 0) {
                    sleepDataItem(
                        label: "入睡时间",
                        value: sleepBedTime.map { timeFormatter.string(from: $0) } ?? "--"
                    )
                    Spacer()
                    sleepDataItem(
                        label: "起床时间",
                        value: sleepWakeTime.map { timeFormatter.string(from: $0) } ?? "--"
                    )
                    Spacer()
                    sleepDataItem(
                        label: "睡眠时长",
                        value: formatDuration(sleepDuration)
                    )
                }
            } else {
                Text("暂无数据")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private func sleepDataItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Compact Sleep Content

    private var sleepCompactContent: some View {
        let hasSleepData = sleepBedTime != nil || sleepWakeTime != nil || sleepDuration > 0
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()

        return Group {
            if hasSleepData {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.softIndigo)
                        Text("昨晚睡眠")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("入睡")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(sleepBedTime.map { timeFormatter.string(from: $0) } ?? "--")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("起床")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(sleepWakeTime.map { timeFormatter.string(from: $0) } ?? "--")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("时长")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatDuration(sleepDuration))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.softIndigo)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.softIndigo.opacity(0.4))
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Calendar Section with Toggle

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle
            HStack {
                Text(calendarMode == .exercise ? "运动日历" : "体重日历")
                    .font(.headline)
                    .foregroundColor(AppTheme.primaryText)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        withAnimation { calendarMode = .exercise }
                    } label: {
                        Text("运动")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(calendarMode == .exercise ? .white : AppTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(calendarMode == .exercise ? AppTheme.primaryGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                    Button {
                        withAnimation { calendarMode = .weight }
                    } label: {
                        Text("体重")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(calendarMode == .weight ? .white : AppTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(calendarMode == .weight ? AppTheme.primaryGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(3)
                .background(AppTheme.background)
                .clipShape(Capsule())
            }

            if calendarMode == .exercise {
                CalendarView(
                    selectedDate: $selectedCalendarDate,
                    workoutData: $workoutData
                )
            } else {
                WeightCalendarView()
            }
        }
        .padding(AppTheme.padding)
        .background(AppTheme.surfaceColor)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
            content()
        }
        .padding(AppTheme.padding)
        .background(AppTheme.surfaceColor)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
    }

    private func loadWorkoutData() async {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date()
        var data: [Date: [WorkoutInfo]] = [:]

        // Fetch from HealthKit
        let workouts = await healthManager.fetchWorkouts(from: startOfMonth, to: endOfMonth)
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            let info = WorkoutInfo(
                name: workout.workoutActivityType.commonName,
                duration: Int(workout.duration / 60),
                calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            )
            data[day, default: []].append(info)
        }

        workoutData = data
    }

    private func refreshSleepData() async {
        if let sleepData = await healthManager.fetchSleepData(for: Date()) {
            sleepBedTime = sleepData.bedTime
            sleepWakeTime = sleepData.wakeTime
            sleepDuration = sleepData.duration
        } else {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            let predicate = #Predicate<SleepRecord> { $0.date >= yesterday }
            let descriptor = FetchDescriptor<SleepRecord>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
            if let records = try? modelContext.fetch(descriptor), let latest = records.first {
                sleepBedTime = latest.bedTime
                sleepWakeTime = latest.wakeTime
                sleepDuration = latest.durationHours * 3600
            }
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryText)

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.leading, 10)
        }
        .frame(width: 120, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.trailing, 14)
        .background(AppTheme.surfaceColor)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
    }
}

// MARK: - Manual Entry Sheet

struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showWeightInput = false
    @State private var showFoodInput = false
    @State private var showExerciseInput = false
    @State private var showPeriodInput = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showWeightInput = true
                } label: {
                    Label("记录体重", systemImage: "scalemass.fill")
                        .foregroundColor(.primary)
                }

                Button {
                    showFoodInput = true
                } label: {
                    Label("记录饮食", systemImage: "fork.knife")
                        .foregroundColor(.primary)
                }

                Button {
                    showExerciseInput = true
                } label: {
                    Label("记录运动", systemImage: "figure.run")
                        .foregroundColor(.primary)
                }

                Button {
                    showPeriodInput = true
                } label: {
                    Label("记录生理期", systemImage: "drop.fill")
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("手动记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showWeightInput) {
                WeightInputView()
            }
            .sheet(isPresented: $showFoodInput) {
                ManualFoodInputView()
            }
            .sheet(isPresented: $showExerciseInput) {
                ManualExerciseInputView()
            }
            .sheet(isPresented: $showPeriodInput) {
                ManualPeriodInputView()
            }
        }
    }
}

// MARK: - Manual Food Input

struct ManualFoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var foodName = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var mealType: MealType = .lunch

    var body: some View {
        NavigationStack {
            Form {
                Section("食物信息") {
                    TextField("食物名称", text: $foodName)
                    Picker("餐次", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }
                Section("营养信息") {
                    HStack {
                        Text("热量 (千卡)")
                        Spacer()
                        TextField("0", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("蛋白质 (g)")
                        Spacer()
                        TextField("0", value: $protein, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("碳水 (g)")
                        Spacer()
                        TextField("0", value: $carbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("脂肪 (g)")
                        Spacer()
                        TextField("0", value: $fat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("记录饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let record = FoodRecord(
                            date: .now,
                            mealType: mealType,
                            foodName: foodName.isEmpty ? "新食物" : foodName,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            fiber: 0,
                            waterMl: 0
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Manual Exercise Input

struct ManualExerciseInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var duration: Int = 30
    @State private var calories: Double = 200

    var body: some View {
        NavigationStack {
            Form {
                Section("运动信息") {
                    TextField("运动名称（如：跑步）", text: $exerciseName)
                    Stepper("时长: \(duration) 分钟", value: $duration, in: 5...300, step: 5)
                    HStack {
                        Text("消耗热量 (千卡)")
                        Spacer()
                        TextField("0", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section {
                    Text("提示：手动记录的运动不会同步到 Apple Health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("记录运动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let record = ExerciseRecord(
                            name: exerciseName.isEmpty ? "运动" : exerciseName,
                            duration: duration,
                            calories: calories
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Manual Sleep Input

struct ManualSleepInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var bedDay: String = "昨天"
    @State private var bedTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var quality: Int = 3

    private var actualBedTime: Date {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: bedTime)
        let minute = cal.component(.minute, from: bedTime)
        let baseDate = bedDay == "昨天"
            ? cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
            : cal.startOfDay(for: Date())
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? bedTime
    }

    private var duration: TimeInterval {
        let diff = wakeTime.timeIntervalSince(actualBedTime)
        return max(diff, 0)
    }

    private var durationText: String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)小时\(minutes)分钟"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("睡眠时间") {
                    Picker("入睡日期", selection: $bedDay) {
                        Text("昨天").tag("昨天")
                        Text("今天").tag("今天")
                    }
                    .pickerStyle(.segmented)

                    DatePicker("入睡时间（\(bedDay)）", selection: $bedTime, displayedComponents: .hourAndMinute)
                    DatePicker("起床时间（今天）", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    HStack {
                        Text("睡眠时长")
                        Spacer()
                        Text(durationText)
                            .foregroundColor(AppTheme.softIndigo)
                            .fontWeight(.semibold)
                    }
                }

                Section("睡眠质量") {
                    HStack {
                        Text("质量评分")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= quality ? "star.fill" : "star")
                                .foregroundColor(star <= quality ? .yellow : .gray.opacity(0.3))
                                .onTapGesture { quality = star }
                        }
                    }
                }
            }
            .navigationTitle("记录睡眠")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let record = SleepRecord(
                            date: .now,
                            bedTime: actualBedTime,
                            wakeTime: wakeTime,
                            quality: quality,
                            isManual: true
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Manual Period Input

struct ManualPeriodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("生理期记录") {
                    DatePicker("日期", selection: $startDate, displayedComponents: .date)
                    TextField("备注（可选）", text: $note)
                }
            }
            .navigationTitle("记录生理期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let record = PeriodRecord(date: startDate, note: note.isEmpty ? nil : note)
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Manual Mood Input

struct ManualMoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: Mood = .neutral

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("选择你现在的心情")
                    .font(.headline)
                    .padding(.top, 20)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(Mood.all, id: \.id) { mood in
                        Button {
                            selectedMood = mood
                        } label: {
                            VStack(spacing: 6) {
                                Image(mood.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .fill(selectedMood == mood ? AppTheme.primaryGreen.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedMood == mood ? AppTheme.primaryGreen : Color.clear, lineWidth: 2)
                                    )
                                Text(mood.label)
                                    .font(.caption2)
                                    .foregroundColor(selectedMood == mood ? AppTheme.primaryGreen : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("记录心情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let startOfDay = Calendar.current.startOfDay(for: Date())
                        let predicate = #Predicate<MoodRecord> { $0.date >= startOfDay }
                        if let existing = try? modelContext.fetch(FetchDescriptor<MoodRecord>(predicate: predicate)) {
                            existing.forEach { modelContext.delete($0) }
                        }
                        modelContext.insert(MoodRecord(date: .now, mood: selectedMood))
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Drink Input View

struct DrinkInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = "水"
    @State private var amount: Int = 250
    @State private var customType = ""

    private let quickAmounts = [100, 200, 250, 300, 500]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Drink type
                VStack(alignment: .leading, spacing: 10) {
                    Text("饮品类型")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(DrinkRecord.defaultTypes, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                Text(type)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedType == type ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedType == type ? Color(hex: "99CDD8") : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        Button {
                            selectedType = "自定义"
                        } label: {
                            Text("自定义")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedType == "自定义" ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedType == "自定义" ? Color(hex: "99CDD8") : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if selectedType == "自定义" {
                        TextField("输入饮品名称", text: $customType)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)

                // Amount
                VStack(spacing: 12) {
                    Text("\(amount) ml")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "99CDD8"))

                    // Quick select
                    HStack(spacing: 8) {
                        ForEach(quickAmounts, id: \.self) { ml in
                            Button {
                                amount = ml
                            } label: {
                                Text("\(ml)")
                                    .font(.caption2.bold())
                                    .foregroundColor(amount == ml ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(amount == ml ? Color(hex: "99CDD8") : Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Slider(value: Binding(
                        get: { Double(amount) },
                        set: { amount = Int($0) }
                    ), in: 50...1000, step: 50)
                    .tint(Color(hex: "99CDD8"))
                    .padding(.horizontal)
                }

                Spacer()

                // Save
                Button {
                    let type = selectedType == "自定义" ? (customType.isEmpty ? "饮品" : customType) : selectedType
                    let record = DrinkRecord(type: type, amount: amount)
                    modelContext.insert(record)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("记录")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "99CDD8"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("记录饮水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [MoodRecord.self], inMemory: true)
}
