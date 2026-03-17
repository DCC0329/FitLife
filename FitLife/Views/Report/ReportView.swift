import SwiftUI
import SwiftData
import Charts
import HealthKit

enum ReportPeriod: String, CaseIterable {
    case weekly = "周报"
    case monthly = "月报"
}

enum WeightChartMode: String, CaseIterable {
    case weight = "体重"
    case bmi = "BMI"
}

enum WeightPeriod: String, CaseIterable {
    case sevenDays = "7天"
    case thirtyDays = "30天"
    case ninetyDays = "90天"
    case all = "全部"
}

enum WeightGrouping: String, CaseIterable {
    case daily = "按天"
    case weekly = "按周"
}

struct ReportView: View {
    @Query(sort: \WeightRecord.date, order: .forward) private var allWeightRecords: [WeightRecord]
    @Query(sort: \FoodRecord.date, order: .forward) private var allFoodRecords: [FoodRecord]
    @Query(sort: \SleepRecord.date, order: .forward) private var allSleepRecords: [SleepRecord]
    @Query(sort: \ExerciseRecord.date, order: .forward) private var allExerciseRecords: [ExerciseRecord]
    @State private var selectedPeriod: ReportPeriod = .weekly
    @State private var workouts: [HKWorkout] = []
    @StateObject private var healthManager = HealthKitManager()
    @AppStorage("goal_weight") private var goalWeight: Double = 65.0
    @AppStorage("user_height") private var userHeight: Double = 170.0
    @State private var chartMode: WeightChartMode = .weight
    @State private var weightPeriod: WeightPeriod = .thirtyDays
    @State private var weightGrouping: WeightGrouping = .daily

    // MARK: - Colors

    private let accent = Color(hex: "4ECB71")        // 主绿
    private let accentLight = Color(hex: "E8F8EE")    // 淡绿
    private let chartLine = Color(hex: "E8879A")       // 淡粉折线
    private let chartFill = Color(hex: "E8879A")       // 淡粉填充
    private let chartPink = Color(hex: "E8879A")       // 淡粉主色
    private let chartPinkLight = Color(hex: "FDF0F2")  // 淡粉背景
    private let cardBg = Color.white
    private let pageBg = Color(hex: "F5F7FA")

    private var startDate: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        switch selectedPeriod {
        case .weekly:
            let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            return cal.date(from: components) ?? Date()
        case .monthly:
            let components = cal.dateComponents([.year, .month], from: Date())
            return cal.date(from: components) ?? Date()
        }
    }

    private var endDate: Date {
        let cal = Calendar.current
        switch selectedPeriod {
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: startDate) ?? Date()
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: startDate) ?? Date()
        }
    }

    private var filteredExercises: [ExerciseRecord] {
        allExerciseRecords.filter { $0.date >= weightChartStartDate }
    }

    private var maxWeight: Double? { weightChartRecords.map(\.weight).max() }
    private var minWeight: Double? { weightChartRecords.map(\.weight).min() }
    private var avgWeight: Double? {
        guard !weightChartRecords.isEmpty else { return nil }
        return weightChartRecords.map(\.weight).reduce(0, +) / Double(weightChartRecords.count)
    }

    private var heightInMeters: Double { userHeight / 100.0 }

    private func bmi(for weight: Double) -> Double {
        guard heightInMeters > 0 else { return 0 }
        return weight / (heightInMeters * heightInMeters)
    }

    private var bmiValues: [Double] { weightChartRecords.map { bmi(for: $0.weight) } }
    private var maxBMI: Double? { bmiValues.max() }
    private var minBMI: Double? { bmiValues.min() }
    private var avgBMI: Double? {
        guard !bmiValues.isEmpty else { return nil }
        return bmiValues.reduce(0, +) / Double(bmiValues.count)
    }
    private var latestBMI: Double? {
        guard let last = weightChartRecords.last else { return nil }
        return bmi(for: last.weight)
    }
    private var goalBMI: Double { bmi(for: goalWeight) }

    private func bmiZoneColor(_ value: Double) -> Color {
        switch value {
        case ..<18.5: return Color(hex: "5BA4CF")
        case 18.5..<24: return accent
        case 24..<28: return .orange
        default: return .red
        }
    }

    private func bmiZoneLabel(_ value: Double) -> String {
        switch value {
        case ..<18.5: return "偏瘦"
        case 18.5..<24: return "正常"
        case 24..<28: return "偏胖"
        default: return "肥胖"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    weightChartCard
                    weightSummaryCard
                    exerciseSummaryCard
                    calorieIntakeCard
                    sleepSummaryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(pageBg)
            .navigationTitle("数据报告")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await healthManager.requestAuthorization()
                workouts = await healthManager.fetchWorkouts(from: weightChartStartDate, to: Date())
            }
            .onChange(of: weightPeriod) {
                Task {
                    workouts = await healthManager.fetchWorkouts(from: weightChartStartDate, to: Date())
                }
            }
        }
    }

    // MARK: - Weight Chart Card

    private var weightChartStartDate: Date {
        let now = Date()
        switch weightPeriod {
        case .sevenDays: return Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .thirtyDays: return Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .ninetyDays: return Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        case .all: return Date.distantPast
        }
    }

    private var weightChartRecords: [WeightRecord] {
        return allWeightRecords.filter { $0.date >= weightChartStartDate }
    }

    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("体重趋势")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(chartPink)

            // Period selector
            HStack(spacing: 0) {
                ForEach(WeightPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation { weightPeriod = period }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(weightPeriod == period ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(weightPeriod == period ? chartPink : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(chartPinkLight)
            .clipShape(Capsule())

            // Mode toggle
            HStack(spacing: 8) {
                pillToggle(items: WeightChartMode.allCases.map(\.rawValue),
                          selected: chartMode.rawValue,
                          color: chartPink) { val in
                    chartMode = WeightChartMode.allCases.first { $0.rawValue == val } ?? .weight
                }

                Spacer()
            }

            if weightChartRecords.isEmpty {
                Text("暂无数据，请先记录体重")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if chartMode == .weight {
                weightChart
            } else {
                bmiChart
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func pillToggle(items: [String], selected: String, color: Color, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation { action(item) }
                } label: {
                    Text(item)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(selected == item ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(selected == item ? color : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .background(Color(hex: "F0F1F5"))
        .clipShape(Capsule())
    }

    // MARK: - Weight Chart

    private var weightChart: some View {
        VStack(spacing: 14) {
            Chart {
                ForEach(weightChartRecords) { record in
                    AreaMark(
                        x: .value("日期", record.date),
                        y: .value("体重", record.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartFill.opacity(0.08), chartFill.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", record.date),
                        y: .value("体重", record.weight)
                    )
                    .foregroundStyle(chartLine)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", record.date),
                        y: .value("体重", record.weight)
                    )
                    .foregroundStyle(chartLine)
                    .symbolSize(18)
                }

                RuleMark(y: .value("目标体重", goalWeight))
                    .foregroundStyle(chartPink.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标: \(goalWeight, specifier: "%.1f") kg")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(chartPink)
                    }
            }
            .frame(height: 220)
            .chartYScale(domain: chartYDomain)

            // Stats
            HStack(spacing: 0) {
                weightStatItem(title: "最高", value: maxWeight)
                miniDivider
                weightStatItem(title: "最低", value: minWeight)
                miniDivider
                weightStatItem(title: "平均", value: avgWeight)
            }
        }
    }

    // MARK: - BMI Chart

    private var bmiChart: some View {
        VStack(spacing: 14) {
            Chart {
                ForEach(weightChartRecords) { record in
                    let recordBMI = bmi(for: record.weight)

                    AreaMark(
                        x: .value("日期", record.date),
                        y: .value("BMI", recordBMI)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartFill.opacity(0.08), chartFill.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", record.date),
                        y: .value("BMI", recordBMI)
                    )
                    .foregroundStyle(chartLine)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", record.date),
                        y: .value("BMI", recordBMI)
                    )
                    .foregroundStyle(bmiZoneColor(recordBMI))
                    .symbolSize(18)
                }

                RuleMark(y: .value("目标BMI", goalBMI))
                    .foregroundStyle(chartPink.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标: \(goalBMI, specifier: "%.1f")")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(chartPink)
                    }

                RuleMark(y: .value("偏瘦/正常", 18.5))
                    .foregroundStyle(Color.gray.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

                RuleMark(y: .value("正常/偏胖", 24))
                    .foregroundStyle(Color.gray.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

                RuleMark(y: .value("偏胖/肥胖", 28))
                    .foregroundStyle(Color.orange.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
            .frame(height: 220)
            .chartYScale(domain: bmiChartYDomain)

            if let latest = latestBMI {
                HStack(spacing: 6) {
                    Circle()
                        .fill(bmiZoneColor(latest))
                        .frame(width: 8, height: 8)
                    Text("当前 BMI \(latest, specifier: "%.1f")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.primaryText)
                    Text(bmiZoneLabel(latest))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(bmiZoneColor(latest))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(bmiZoneColor(latest).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 0) {
                bmiStatItem(title: "最高BMI", value: maxBMI)
                miniDivider
                bmiStatItem(title: "最低BMI", value: minBMI)
                miniDivider
                bmiStatItem(title: "平均BMI", value: avgBMI)
            }
        }
    }

    private var bmiChartYDomain: ClosedRange<Double> {
        let values = bmiValues + [goalBMI]
        let lo = (values.min() ?? 15) - 1
        let hi = (values.max() ?? 30) + 1
        return lo...hi
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = weightChartRecords.map(\.weight) + [goalWeight]
        let lo = (weights.min() ?? 50) - 2
        let hi = (weights.max() ?? 80) + 2
        return lo...hi
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private func weightStatItem(title: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let value {
                Text("\(value, specifier: "%.1f") kg")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText)
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bmiStatItem(title: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let value {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(bmiZoneColor(value))
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weight Summary Card

    private var weightSummaryCard: some View {
        let periodDays = max(1, Calendar.current.dateComponents([.day], from: weightChartStartDate, to: min(Date(), Date())).day ?? 1)
        let weightChange: Double? = {
            guard let first = weightChartRecords.first?.weight, let last = weightChartRecords.last?.weight else { return nil }
            return last - first
        }()
        let dailyChange: Double? = weightChange.map { $0 / Double(periodDays) }

        return HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("体重变化")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if let change = weightChange {
                    Text(String(format: "%+.1f kg", change))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(change <= 0 ? chartPink : .orange)
                } else {
                    Text("--").font(.system(size: 15, weight: .bold)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            miniDivider

            VStack(spacing: 4) {
                Text("日均变化")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if let daily = dailyChange {
                    Text(String(format: "%+.2f kg", daily))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(daily <= 0 ? chartPink : .orange)
                } else {
                    Text("--").font(.system(size: 15, weight: .bold)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            miniDivider

            VStack(spacing: 4) {
                Text("记录天数")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(weightChartRecords.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText)
                + Text(" 天")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Exercise Summary Card

    private var exerciseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                Text("运动总结")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
            }

            HStack(spacing: 0) {
                exerciseStatItem(title: "运动天数", value: "\(workoutDays)", unit: "天", color: chartLine)
                miniDivider
                exerciseStatItem(title: "总时长", value: "\(totalMinutes)", unit: "分钟", color: AppTheme.lavender)
                miniDivider
                exerciseStatItem(title: "消耗热量", value: "\(totalCalories)", unit: "千卡", color: accent)
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var workoutDays: Int {
        let hkDays = Set(workouts.map { Calendar.current.startOfDay(for: $0.startDate) })
        let manualDays = Set(filteredExercises.map { Calendar.current.startOfDay(for: $0.date) })
        return hkDays.union(manualDays).count
    }

    private var totalMinutes: Int {
        let hkMinutes = Int(workouts.reduce(0) { $0 + $1.duration } / 60)
        let manualMinutes = filteredExercises.reduce(0) { $0 + $1.duration }
        return hkMinutes + manualMinutes
    }

    private var totalCalories: Int {
        let hkCals = Int(workouts.reduce(0) { $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) })
        let manualCals = Int(filteredExercises.reduce(0) { $0 + $1.calories })
        return hkCals + manualCals
    }

    private func exerciseStatItem(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calorie Intake Card

    private var calorieIntakeCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                Text("日均摄入")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.primaryText)
            }
            Spacer()
            Text("\(averageDailyCalories)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText)
            + Text(" 千卡")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var averageDailyCalories: Int {
        let foodsInPeriod = allFoodRecords.filter { $0.date >= weightChartStartDate }
        guard !foodsInPeriod.isEmpty else { return 0 }
        let totalCals = foodsInPeriod.reduce(0) { $0 + $1.calories }
        let now = Date()
        let days = max(1, Calendar.current.dateComponents([.day], from: weightChartStartDate, to: now).day ?? 1)
        return Int(totalCals / Double(days))
    }

    // MARK: - Sleep Summary Card

    private var sleepSummaryCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.lavender)
                Text("平均睡眠")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.primaryText)
            }
            Spacer()
            Text(String(format: "%.1f", averageSleepHours))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText)
            + Text(" 小时")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var averageSleepHours: Double {
        let sleepInPeriod = allSleepRecords.filter { $0.date >= weightChartStartDate }
        guard !sleepInPeriod.isEmpty else { return 0 }
        let totalHours = sleepInPeriod.reduce(0.0) { $0 + $1.durationHours }
        return totalHours / Double(sleepInPeriod.count)
    }
}
#Preview {
    ReportView()
}
