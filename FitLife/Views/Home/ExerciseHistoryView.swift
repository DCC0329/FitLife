import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var allRecords: [ExerciseRecord]
    @StateObject private var hk = HealthKitManager()
    @State private var weeklyCalories: [(date: Date, calories: Double)] = []
    @State private var showAddExercise = false

    private let accent = Color(hex: "A89FEC")   // lavender
    private let pageBg = Color(hex: "F5F7FA")

    private var todayRecords: [ExerciseRecord] {
        allRecords.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var todayManualCalories: Double { todayRecords.reduce(0) { $0 + $1.calories } }
    private var todayManualMinutes: Int { todayRecords.reduce(0) { $0 + $1.duration } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                todayCard
                weeklyChartCard
                recordsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(pageBg.ignoresSafeArea())
        .navigationTitle("运动记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddExercise = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(accent)
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            ManualExerciseInputView()
        }
        .task {
            await hk.requestAuthorization()
            async let c = hk.fetchTodayCalories()
            async let m = hk.fetchTodayExerciseMinutes()
            weeklyCalories = await hk.fetchWeeklyCalories()
            _ = await (c, m)
        }
    }

    // MARK: - 今日概览

    private var todayCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundColor(accent)
                Text("今日运动").font(.system(size: 17, weight: .bold))
                Spacer()
            }
            HStack(spacing: 0) {
                statBox(icon: "flame.fill",
                        value: "\(Int(hk.todayCalories + todayManualCalories))",
                        unit: "千卡",
                        color: accent)
                Divider().frame(height: 44)
                statBox(icon: "timer",
                        value: "\(Int(hk.todayExerciseMinutes) + todayManualMinutes)",
                        unit: "分钟",
                        color: Color(hex: "6CB4EE"))
                Divider().frame(height: 44)
                statBox(icon: "figure.run",
                        value: "\(todayRecords.count)",
                        unit: "次手动",
                        color: Color(hex: "4ECB71"))
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func statBox(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(unit).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 近7天图表

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("近7天消耗(千卡)").font(.system(size: 15, weight: .semibold))

            Chart {
                ForEach(weeklyCalories, id: \.date) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("消耗", item.calories)
                    )
                    .foregroundStyle(accent.opacity(0.8).gradient)
                    .cornerRadius(6)
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
                            Text("\(Int(val))").font(.system(size: 9))
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

    // MARK: - 手动记录列表

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("手动记录")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            if allRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 32))
                        .foregroundColor(accent.opacity(0.4))
                    Text("还没有手动运动记录")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(Array(allRecords.enumerated()), id: \.element.id) { idx, record in
                    exerciseRow(record)
                    if idx < allRecords.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func exerciseRow(_ record: ExerciseRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(dayStr(record.date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(timeStr(record.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "figure.run")
                        .font(.system(size: 15))
                        .foregroundColor(accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text("\(record.duration) 分钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
                    Text("\(Int(record.calories)) 千卡")
                        .font(.caption)
                        .foregroundColor(accent)
                }
            }

            Spacer()

            Button {
                modelContext.delete(record)
                try? modelContext.save()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func dayStr(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ExerciseHistoryView()
            .modelContainer(for: ExerciseRecord.self, inMemory: true)
    }
}
