import SwiftUI
import SwiftData
import Charts

struct SleepHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepRecord.date, order: .reverse) private var allRecords: [SleepRecord]
    @State private var showAddSleep = false

    private let accent = AppTheme.softIndigo
    private let pageBg = Color(hex: "F5F7FA")

    // MARK: - 近7天数据

    private var last7Days: [(date: Date, hours: Double)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date()))!
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let h = allRecords.first { $0.date >= day && $0.date < next }?.durationHours ?? 0
            return (date: day, hours: h)
        }
    }

    private var nonZeroHours: [Double] { last7Days.map(\.hours).filter { $0 > 0 } }
    private var avgHours: Double? { nonZeroHours.isEmpty ? nil : nonZeroHours.reduce(0, +) / Double(nonZeroHours.count) }
    private var maxHours: Double? { nonZeroHours.max() }
    private var minHours: Double? { nonZeroHours.min() }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                chartCard
                statsCard
                recordsList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(pageBg.ignoresSafeArea())
        .navigationTitle("睡眠历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSleep = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(accent)
                }
            }
        }
        .sheet(isPresented: $showAddSleep) {
            ManualSleepInputView()
        }
    }

    // MARK: - 图表卡片

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(accent)
                Text("近7天睡眠")
                    .font(.system(size: 17, weight: .bold))
            }

            if nonZeroHours.isEmpty {
                Text("暂无睡眠记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(last7Days, id: \.date) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("时长(h)", item.hours)
                        )
                        .foregroundStyle(
                            item.hours >= 7
                                ? accent.gradient
                                : accent.opacity(0.4).gradient
                        )
                        .cornerRadius(6)
                    }

                    RuleMark(y: .value("建议8h", 8))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("建议 8h")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { v in
                        AxisValueLabel {
                            if let h = v.as(Double.self) {
                                Text("\(Int(h))h").font(.system(size: 9))
                            }
                        }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 统计卡片

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCell(title: "平均时长", value: avgHours.map { String(format: "%.1fh", $0) } ?? "--")
            miniDiv
            statCell(title: "最长", value: maxHours.map { String(format: "%.1fh", $0) } ?? "--")
            miniDiv
            statCell(title: "最短", value: minHours.map { String(format: "%.1fh", $0) } ?? "--")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDiv: some View {
        Rectangle().fill(Color.gray.opacity(0.15)).frame(width: 1, height: 36)
    }

    // MARK: - 记录列表

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("全部记录")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            if allRecords.isEmpty {
                Text("暂无记录，点击右上角 + 添加")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(allRecords.enumerated()), id: \.element.id) { idx, record in
                    sleepRow(record)
                    if idx < allRecords.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func sleepRow(_ record: SleepRecord) -> some View {
        HStack(spacing: 12) {
            // 日期标签
            VStack(spacing: 1) {
                Text(fmt(record.date, "d"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text(fmt(record.date, "M月"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 36)

            // 时间段
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    timeChip(icon: "moon.fill", time: record.bedTime)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    timeChip(icon: "sun.max.fill", time: record.wakeTime)
                }
                Text(String(format: "共 %.1f 小时", record.durationHours))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 星级
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { s in
                    Image(systemName: s <= record.quality ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(s <= record.quality ? .yellow : .gray.opacity(0.3))
                }
            }

            // 删除
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
        .padding(.vertical, 12)
    }

    private func timeChip(icon: String, time: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(accent)
            Text(fmt(time, "HH:mm")).font(.system(size: 12, weight: .medium))
        }
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
        SleepHistoryView()
            .modelContainer(for: SleepRecord.self, inMemory: true)
    }
}
