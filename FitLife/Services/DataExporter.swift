import Foundation
import SwiftData
import UIKit

final class DataExporter {

    private let modelContext: ModelContext
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CSV Export

    func exportCSV() throws -> URL {
        var csv = ""

        // Weight Records
        let weights: [WeightRecord] = (try? modelContext.fetch(FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 体重记录 ===\n"
        csv += "日期,体重(kg),备注\n"
        for r in weights {
            let note = r.note?.replacingOccurrences(of: ",", with: "，") ?? ""
            csv += "\(dateFormatter.string(from: r.date)),\(String(format: "%.1f", r.weight)),\(note)\n"
        }
        csv += "\n"

        // Food Records
        let foods: [FoodRecord] = (try? modelContext.fetch(FetchDescriptor<FoodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 饮食记录 ===\n"
        csv += "日期,餐次,食物名称,热量(kcal),蛋白质(g),碳水(g),脂肪(g)\n"
        for r in foods {
            let meal = r.mealType.label
            let name = r.foodName.replacingOccurrences(of: ",", with: "，")
            csv += "\(dateFormatter.string(from: r.date)),\(meal),\(name),\(String(format: "%.0f", r.calories)),\(String(format: "%.1f", r.protein)),\(String(format: "%.1f", r.carbs)),\(String(format: "%.1f", r.fat))\n"
        }
        csv += "\n"

        // Exercise Records
        let exercises: [ExerciseRecord] = (try? modelContext.fetch(FetchDescriptor<ExerciseRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 运动记录 ===\n"
        csv += "日期,运动名称,时长(分钟),消耗热量(kcal)\n"
        for r in exercises {
            let name = r.name.replacingOccurrences(of: ",", with: "，")
            csv += "\(dateFormatter.string(from: r.date)),\(name),\(r.duration),\(String(format: "%.0f", r.calories))\n"
        }
        csv += "\n"

        // Sleep Records
        let sleeps: [SleepRecord] = (try? modelContext.fetch(FetchDescriptor<SleepRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 睡眠记录 ===\n"
        csv += "日期,入睡时间,起床时间,睡眠质量(1-5)\n"
        for r in sleeps {
            csv += "\(dateFormatter.string(from: r.date)),\(timeFormatter.string(from: r.bedTime)),\(timeFormatter.string(from: r.wakeTime)),\(r.quality)\n"
        }
        csv += "\n"

        // Mood Records
        let moods: [MoodRecord] = (try? modelContext.fetch(FetchDescriptor<MoodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 心情记录 ===\n"
        csv += "日期,心情\n"
        for r in moods {
            csv += "\(dateFormatter.string(from: r.date)),\(r.mood.label)\n"
        }
        csv += "\n"

        // Drink Records
        let drinks: [DrinkRecord] = (try? modelContext.fetch(FetchDescriptor<DrinkRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 饮水记录 ===\n"
        csv += "日期,饮品类型,量(ml)\n"
        for r in drinks {
            csv += "\(dateFormatter.string(from: r.date)),\(r.type),\(r.amount)\n"
        }
        csv += "\n"

        // Period Records
        let periods: [PeriodRecord] = (try? modelContext.fetch(FetchDescriptor<PeriodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        csv += "=== 生理期记录 ===\n"
        csv += "日期,备注\n"
        for r in periods {
            csv += "\(dateFormatter.string(from: r.date)),\(r.note ?? "")\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FitLife_数据导出_\(dateFormatter.string(from: Date())).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF Export

    func exportPDF() throws -> URL {
        let weights: [WeightRecord] = (try? modelContext.fetch(FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let foods: [FoodRecord] = (try? modelContext.fetch(FetchDescriptor<FoodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let exercises: [ExerciseRecord] = (try? modelContext.fetch(FetchDescriptor<ExerciseRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let sleeps: [SleepRecord] = (try? modelContext.fetch(FetchDescriptor<SleepRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let moods: [MoodRecord] = (try? modelContext.fetch(FetchDescriptor<MoodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let drinks: [DrinkRecord] = (try? modelContext.fetch(FetchDescriptor<DrinkRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let periods: [PeriodRecord] = (try? modelContext.fetch(FetchDescriptor<PeriodRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []

        // Gather all dates for range
        var allDates: [Date] = []
        allDates.append(contentsOf: weights.map(\.date))
        allDates.append(contentsOf: foods.map(\.date))
        allDates.append(contentsOf: exercises.map(\.date))
        allDates.append(contentsOf: sleeps.map(\.date))
        allDates.sort()

        let startDate = allDates.first ?? Date()
        let endDate = allDates.last ?? Date()

        // Compute stats
        let currentWeight = weights.last?.weight ?? 0
        let userHeight = UserDefaults.standard.double(forKey: "user_height")
        let heightM = userHeight > 0 ? userHeight / 100.0 : 1.7
        let bmi = currentWeight > 0 ? currentWeight / (heightM * heightM) : 0

        let exerciseDays = Set(exercises.map { Calendar.current.startOfDay(for: $0.date) }).count

        let totalCalories = foods.reduce(0.0) { $0 + $1.calories }
        let foodDays = Set(foods.map { Calendar.current.startOfDay(for: $0.date) }).count
        let avgDailyCalories = foodDays > 0 ? totalCalories / Double(foodDays) : 0

        let totalSleepHours = sleeps.reduce(0.0) { $0 + $1.durationHours }
        let avgSleepHours = sleeps.isEmpty ? 0 : totalSleepHours / Double(sleeps.count)

        // Build PDF
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 50
            var y: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.31, green: 0.80, blue: 0.44, alpha: 1.0)
            ]
            let title = "FitLife 健康报告"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 44

            // Date range
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let dateRange = "报告周期：\(dateFormatter.string(from: startDate)) ~ \(dateFormatter.string(from: endDate))"
            dateRange.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 28

            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: y))
            dividerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.lightGray.setStroke()
            dividerPath.lineWidth = 0.5
            dividerPath.stroke()
            y += 20

            // Section header helper
            func drawSection(_ text: String) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.darkText
                ]
                text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                y += 32
            }

            // Stat line helper
            func drawStat(_ label: String, _ value: String) {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: UIColor.darkText
                ]
                label.draw(at: CGPoint(x: margin + 16, y: y), withAttributes: labelAttrs)
                value.draw(at: CGPoint(x: margin + 200, y: y), withAttributes: valueAttrs)
                y += 28
            }

            // Summary section
            drawSection("概览统计")
            drawStat("当前体重", currentWeight > 0 ? String(format: "%.1f kg", currentWeight) : "暂无数据")
            drawStat("BMI 指数", bmi > 0 ? String(format: "%.1f", bmi) : "暂无数据")
            drawStat("运动天数", "\(exerciseDays) 天")
            drawStat("日均摄入热量", avgDailyCalories > 0 ? String(format: "%.0f kcal", avgDailyCalories) : "暂无数据")
            drawStat("平均睡眠时长", avgSleepHours > 0 ? String(format: "%.1f 小时", avgSleepHours) : "暂无数据")

            y += 12

            // Record counts
            drawSection("数据记录数")
            drawStat("体重记录", "\(weights.count) 条")
            drawStat("饮食记录", "\(foods.count) 条")
            drawStat("运动记录", "\(exercises.count) 条")
            drawStat("睡眠记录", "\(sleeps.count) 条")
            drawStat("心情记录", "\(moods.count) 条")
            drawStat("饮水记录", "\(drinks.count) 条")
            drawStat("生理期记录", "\(periods.count) 条")

            // Drink stats
            let totalDrink = drinks.reduce(0) { $0 + $1.amount }
            let drinkDays = Set(drinks.map { Calendar.current.startOfDay(for: $0.date) }).count
            let avgDrink = drinkDays > 0 ? totalDrink / drinkDays : 0

            y += 12
            drawSection("其他统计")
            drawStat("日均饮水", avgDrink > 0 ? "\(avgDrink) ml" : "暂无数据")
            drawStat("生理期天数", "\(periods.count) 天")

            y += 20

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            let footer = "由 FitLife 生成于 \(dateFormatter.string(from: Date()))"
            footer.draw(at: CGPoint(x: margin, y: pageRect.height - margin), withAttributes: footerAttrs)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FitLife_健康报告_\(dateFormatter.string(from: Date())).pdf")
        try data.write(to: url)
        return url
    }
}
