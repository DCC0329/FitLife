import SwiftUI
import SwiftData
import Charts

struct DrinkHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrinkRecord.date, order: .reverse) private var allRecords: [DrinkRecord]
    @AppStorage("drink_daily_goal") private var dailyGoal: Int = 2000
    @State private var showAddDrink = false
    @State private var goalInput: String = ""
    @State private var isEditingGoal = false

    private let accent = Color(hex: "99CDD8")
    private let pageBg = Color(hex: "F5F7FA")

    private var todayRecords: [DrinkRecord] {
        allRecords.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayTotal: Int { todayRecords.reduce(0) { $0 + $1.amount } }
    private var progress: Double { min(Double(todayTotal) / Double(dailyGoal), 1.0) }

    private var last7Days: [(date: Date, total: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date()))!
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let total = allRecords.filter { $0.date >= day && $0.date < next }.reduce(0) { $0 + $1.amount }
            return (date: day, total: total)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                todayCard
                weeklyChartCard
                todayLogCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(pageBg.ignoresSafeArea())
        .navigationTitle("饮水记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddDrink = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(accent)
                }
            }
        }
        .sheet(isPresented: $showAddDrink) {
            DrinkInputView()
        }
    }

    // MARK: - 今日进度卡片

    private var todayCard: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill").foregroundColor(accent)
                    Text("今日饮水").font(.system(size: 17, weight: .bold))
                }
                Spacer()
                // 每日目标调节
                HStack(spacing: 4) {
                    Text("目标").font(.system(size: 11)).foregroundColor(.secondary)
                    Button { if dailyGoal > 500 { dailyGoal -= 250 } } label: {
                        Image(systemName: "minus.circle").font(.system(size: 16)).foregroundColor(accent)
                    }
                    if isEditingGoal {
                        TextField("", text: $goalInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 12, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
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
                        Text("\(dailyGoal)ml")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(minWidth: 56)
                            .onTapGesture {
                                goalInput = "\(dailyGoal)"
                                isEditingGoal = true
                            }
                    }
                    Button { if dailyGoal < 5000 { dailyGoal += 250 } } label: {
                        Image(systemName: "plus.circle").font(.system(size: 16)).foregroundColor(accent)
                    }
                }
            }

            // 进度条
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
                    Text("\(todayTotal) ml")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accent)
                    Spacer()
                    if progress >= 1 {
                        Label("已达标", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accent)
                    } else {
                        Text("还需 \(dailyGoal - todayTotal) ml")
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
                ForEach(last7Days, id: \.date) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("饮水(ml)", item.total)
                    )
                    .foregroundStyle(
                        item.total >= dailyGoal
                            ? accent.gradient
                            : accent.opacity(0.4).gradient
                    )
                    .cornerRadius(6)
                }

                RuleMark(y: .value("目标", dailyGoal))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(dailyGoal)ml")
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
                        if let val = v.as(Int.self) {
                            Text(val >= 1000 ? "\(val/1000)L" : "\(val)")
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

    // MARK: - 今日明细

    private var todayLogCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日明细")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            if todayRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "drop").font(.system(size: 32)).foregroundColor(accent.opacity(0.4))
                    Text("今天还没有饮水记录").foregroundColor(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(Array(todayRecords.enumerated()), id: \.element.id) { idx, record in
                    drinkRow(record)
                    if idx < todayRecords.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func drinkRow(_ record: DrinkRecord) -> some View {
        HStack(spacing: 12) {
            Text(fmt(record.date, "HH:mm"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 40)

            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: drinkIcon(record.type))
                        .font(.system(size: 15))
                        .foregroundColor(accent)
                )

            Text(record.type).font(.subheadline)

            Spacer()

            Text("\(record.amount) ml")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)

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

    private func drinkIcon(_ type: String) -> String {
        switch type {
        case "水": return "drop.fill"
        case "咖啡": return "cup.and.saucer.fill"
        case "豆浆", "牛奶": return "mug.fill"
        case "茶": return "leaf.fill"
        case "果汁": return "waterbottle.fill"
        case "苹果醋": return "flask.fill"
        default: return "drop.fill"
        }
    }

    private func commitGoalInput() {
        if let val = Int(goalInput), val >= 100, val <= 9999 {
            dailyGoal = val
        }
        isEditingGoal = false
    }

    private func fmt(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = format
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DrinkHistoryView()
            .modelContainer(for: DrinkRecord.self, inMemory: true)
    }
}
