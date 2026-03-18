import SwiftUI
import Charts

struct StepsHistoryView: View {
    @StateObject private var hk = HealthKitManager()
    @AppStorage("steps_daily_goal") private var dailyGoal: Int = 10000
    @State private var weeklyData: [(date: Date, steps: Double)] = []
    @State private var goalInput: String = ""
    @State private var isEditingGoal = false

    private let accent = AppTheme.primaryGreen
    private let pageBg = Color(hex: "F5F7FA")

    private var progress: Double { min(hk.todaySteps / Double(dailyGoal), 1.0) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                todayCard
                weeklyChartCard
                statsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(pageBg.ignoresSafeArea())
        .navigationTitle("步数记录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await hk.requestAuthorization()
            async let s = hk.fetchTodaySteps()
            weeklyData = await hk.fetchWeeklySteps()
            _ = await s
        }
    }

    // MARK: - 今日进度卡片

    private var todayCard: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk").foregroundColor(accent)
                    Text("今日步数").font(.system(size: 17, weight: .bold))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("目标").font(.system(size: 11)).foregroundColor(.secondary)
                    Button { if dailyGoal > 1000 { dailyGoal -= 1000 } } label: {
                        Image(systemName: "minus.circle").font(.system(size: 16)).foregroundColor(accent)
                    }
                    if isEditingGoal {
                        TextField("", text: $goalInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 12, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: 68)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit { commitGoalInput() }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("完成") { commitGoalInput() }
                                }
                            }
                    } else {
                        Text("\(dailyGoal)步")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(minWidth: 56)
                            .onTapGesture {
                                goalInput = "\(dailyGoal)"
                                isEditingGoal = true
                            }
                    }
                    Button { if dailyGoal < 50000 { dailyGoal += 1000 } } label: {
                        Image(systemName: "plus.circle").font(.system(size: 16)).foregroundColor(accent)
                    }
                }
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accent.opacity(0.15))
                            .frame(height: 18)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [accent, accent.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress, height: 18)
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 18)

                HStack {
                    Text("\(Int(hk.todaySteps)) 步")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accent)
                    Spacer()
                    if progress >= 1 {
                        Label("已达标", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accent)
                    } else {
                        Text("还需 \(max(0, dailyGoal - Int(hk.todaySteps))) 步")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 近7天图表

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("近7天趋势").font(.system(size: 15, weight: .semibold))

            Chart {
                ForEach(weeklyData, id: \.date) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("步数", item.steps)
                    )
                    .foregroundStyle(
                        item.steps >= Double(dailyGoal)
                            ? accent.gradient
                            : accent.opacity(0.4).gradient
                    )
                    .cornerRadius(6)
                }
                RuleMark(y: .value("目标", Double(dailyGoal)))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(dailyGoal)步")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisValueLabel {
                        if let val = v.as(Double.self) {
                            Text(val >= 10000 ? "\(Int(val/1000))k" : "\(Int(val))")
                                .font(.system(size: 9))
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 统计摘要

    private var statsCard: some View {
        let avg = weeklyData.isEmpty ? 0 : weeklyData.map(\.steps).reduce(0, +) / Double(weeklyData.count)
        let maxSteps = weeklyData.map(\.steps).max() ?? 0
        let reachedDays = weeklyData.filter { $0.steps >= Double(dailyGoal) }.count

        return HStack(spacing: 0) {
            statItem(title: "日均步数", value: "\(Int(avg))")
            Divider().frame(height: 40)
            statItem(title: "最高步数", value: "\(Int(maxSteps))")
            Divider().frame(height: 40)
            statItem(title: "达标天数", value: "\(reachedDays)/7")
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(accent)
            Text(title).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func commitGoalInput() {
        if let val = Int(goalInput), val >= 1000, val <= 99999 {
            dailyGoal = val
        }
        isEditingGoal = false
    }
}

#Preview {
    NavigationStack {
        StepsHistoryView()
    }
}
