import SwiftUI
import SwiftData

struct DietView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [FoodRecord]
    @State private var expandedSections: Set<MealType> = Set(MealType.allCases)
    @State private var showFoodRecognition = false
    @State private var selectedMealTypeForRecognition: MealType = .breakfast
    @State private var showManualFoodInput = false
    @State private var selectedMealTypeForManual: MealType = .breakfast
    @State private var showFoodHistory = false
    @State private var historyMealType: MealType = .breakfast
    @State private var mealAnalysis: [MealType: String] = [:]
    @State private var analyzingMeal: MealType? = nil

    // MARK: - Fasting Timer State
    @AppStorage("fasting_start") private var fastingStartTimeInterval: Double = 0
    @AppStorage("fasting_mode") private var fastingMode: Int = 16 // fasting hours: 16, 18, 20
    @State private var fastingNow = Date()
    @State private var fastingTimer: Timer?

    private var todayRecords: [FoodRecord] {
        let calendar = Calendar.current
        return allRecords.filter { calendar.isDateInToday($0.date) }
    }

    private var totalCalories: Double {
        todayRecords.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        todayRecords.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Double {
        todayRecords.reduce(0) { $0 + $1.carbs }
    }

    private var totalFat: Double {
        todayRecords.reduce(0) { $0 + $1.fat }
    }

    @AppStorage("user_weight") private var userWeight: Double = 65.0
    @AppStorage("user_height") private var userHeight: Double = 170.0
    @AppStorage("user_age") private var userAge: Int = 25
    @AppStorage("user_gender") private var userGender: String = "男"

    /// Mifflin-St Jeor BMR
    private var bmr: Double {
        let base = 10.0 * userWeight + 6.25 * userHeight - 5.0 * Double(userAge)
        return userGender == "男" ? base + 5 : base - 161
    }

    private var calorieGoal: Double { bmr }
    private var remaining: Double { max(bmr - totalCalories, 0) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: AppTheme.padding) {
                        calorieCard
                        macroBar
                        fastingCard

                        ForEach(MealType.allCases, id: \.self) { mealType in
                            mealSection(for: mealType)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, AppTheme.padding)
                    .padding(.top, AppTheme.smallPadding)
                }

                cameraButton
            }
            .navigationTitle("饮食记录")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
            .sheet(isPresented: $showFoodRecognition) {
                FoodRecognitionView()
            }
            .sheet(isPresented: $showManualFoodInput) {
                MealFoodInputView(mealType: selectedMealTypeForManual)
            }
            .sheet(isPresented: $showFoodHistory) {
                FoodHistoryView(mealType: historyMealType, allRecords: allRecords)
            }
        }
    }

    // MARK: - Calorie Card

    private var calorieCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(AppTheme.lightGreen.opacity(0.4), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(totalCalories / calorieGoal, 1.0))
                    .stroke(
                        AppTheme.primaryGreen,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: totalCalories)

                VStack(spacing: 2) {
                    Text("还可以吃")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                    Text("\(Int(remaining))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText)
                    Text("基础代谢 \(Int(bmr))")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }

            Text("已摄入 \(Int(totalCalories)) 千卡")
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Macro Bar

    private var macroBar: some View {
        HStack(spacing: 0) {
            macroItem(label: "蛋白质", value: totalProtein)
            divider
            macroItem(label: "碳水", value: totalCarbs)
            divider
            macroItem(label: "脂肪", value: totalFat)
        }
        .cardStyle()
    }

    private func macroItem(label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fg", value))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1, height: 30)
    }

    // MARK: - Fasting Timer Card

    private var isFasting: Bool { fastingStartTimeInterval > 0 }

    private var fastingEatingHours: Int { 24 - fastingMode }

    private var fastingTotalSeconds: Double { Double(fastingMode) * 3600 }

    private var eatingTotalSeconds: Double { Double(fastingEatingHours) * 3600 }

    /// Elapsed seconds since fasting started
    private var fastingElapsed: Double {
        guard isFasting else { return 0 }
        return fastingNow.timeIntervalSince1970 - fastingStartTimeInterval
    }

    /// Whether we are still in the fasting phase (vs eating window)
    private var isInFastingPhase: Bool {
        fastingElapsed < fastingTotalSeconds
    }

    private var fastingProgress: Double {
        guard isFasting else { return 0 }
        if isInFastingPhase {
            return min(fastingElapsed / fastingTotalSeconds, 1.0)
        } else {
            return 1.0
        }
    }

    private func startFastingTimer() {
        fastingTimer?.invalidate()
        fastingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            fastingNow = Date()
        }
    }

    private func stopFastingTimer() {
        fastingTimer?.invalidate()
        fastingTimer = nil
    }

    /// 将秒数格式化为 "H:MM" 倒计时样式
    private func formatHHMM(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return "\(h)h \(m)m \(s)s"
    }

    private var fastingCard: some View {
        HStack(spacing: 14) {
            // MARK: 双环进度圈
            ZStack {
                // 底环
                Circle()
                    .stroke(AppTheme.lightGreen.opacity(0.25), lineWidth: 8)
                    .frame(width: 68, height: 68)

                // 外环：禁食进度（绿色）
                Circle()
                    .trim(from: 0, to: fastingProgress)
                    .stroke(AppTheme.primaryGreen,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fastingProgress)

                // 内环：进食窗口进度（黄色，仅进食阶段显示）
                if isFasting && !isInFastingPhase {
                    let eatingElapsed = fastingElapsed - fastingTotalSeconds
                    let ep = min(eatingElapsed / eatingTotalSeconds, 1.0)
                    Circle()
                        .stroke(AppTheme.warmYellow.opacity(0.25), lineWidth: 5)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: ep)
                        .stroke(AppTheme.warmYellow,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: ep)
                }

                // 中心文字
                if isFasting {
                    if isInFastingPhase {
                        let remaining = fastingTotalSeconds - fastingElapsed
                        VStack(spacing: 1) {
                            Text(formatHHMM(remaining))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.primaryText)
                            Text("还差")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    } else {
                        let eatingElapsed = fastingElapsed - fastingTotalSeconds
                        let eatingRemaining = max(eatingTotalSeconds - eatingElapsed, 0)
                        VStack(spacing: 1) {
                            Text(eatingRemaining > 0 ? formatHHMM(eatingRemaining) : "结束")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.warmYellow)
                            Text("可进食")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(AppTheme.warmYellow.opacity(0.8))
                        }
                    }
                } else {
                    Text("\(fastingMode):\(fastingEatingHours)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText)
                }
            }

            // MARK: 信息区
            VStack(alignment: .leading, spacing: 6) {
                // 模式选择
                HStack(spacing: 6) {
                    ForEach([16, 18, 20], id: \.self) { mode in
                        Button {
                            if !isFasting { fastingMode = mode }
                        } label: {
                            Text("\(mode):\(24 - mode)")
                                .font(.system(size: 10, weight: fastingMode == mode ? .bold : .regular))
                                .foregroundColor(fastingMode == mode ? .white : AppTheme.primaryGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(fastingMode == mode ? AppTheme.primaryGreen : AppTheme.lightGreen.opacity(0.3))
                                )
                        }
                        .disabled(isFasting)
                    }
                }

                // 状态文字
                if isFasting {
                    if isInFastingPhase {
                        let elapsedH = Int(fastingElapsed) / 3600
                        let elapsedM = (Int(fastingElapsed) % 3600) / 60
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text("禁食中")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryGreen)
                                Text("· 已坚持 \(elapsedH)h \(elapsedM)m")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                            // 进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.lightGreen.opacity(0.4))
                                        .frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.primaryGreen)
                                        .frame(width: geo.size.width * fastingProgress, height: 5)
                                        .animation(.easeInOut(duration: 0.5), value: fastingProgress)
                                }
                            }
                            .frame(height: 5)
                            Text("\(Int(fastingProgress * 100))% · 目标 \(fastingMode)h")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    } else {
                        let eatingElapsed = fastingElapsed - fastingTotalSeconds
                        let eatingRemaining = eatingTotalSeconds - eatingElapsed
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.primaryGreen)
                                Text("禁食达标！进食窗口开放中")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryGreen)
                            }
                            if eatingRemaining > 0 {
                                let eH = Int(eatingRemaining) / 3600
                                let eM = (Int(eatingRemaining) % 3600) / 60
                                Text("进食窗口还剩 \(eH)h \(eM)m")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.warmYellow)
                            } else {
                                Text("本轮已结束，可开始下一轮")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                    }
                } else {
                    Text("点击 ▶ 开始计时")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }

            Spacer()

            // 开始 / 停止
            Button {
                if isFasting {
                    fastingStartTimeInterval = 0
                    stopFastingTimer()
                } else {
                    fastingStartTimeInterval = Date().timeIntervalSince1970
                    fastingNow = Date()
                    startFastingTimer()
                }
            } label: {
                Image(systemName: isFasting ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isFasting ? AppTheme.coral : AppTheme.primaryGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .cardStyle()
        .onAppear {
            fastingNow = Date()
            if isFasting { startFastingTimer() }
        }
        .onDisappear { stopFastingTimer() }
    }

    // MARK: - Meal Section

    private func mealSection(for mealType: MealType) -> some View {
        let records = todayRecords.filter { $0.mealType == mealType }
        let sectionCalories = records.reduce(0) { $0 + $1.calories }
        let isExpanded = expandedSections.contains(mealType)

        return VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedSections.remove(mealType)
                    } else {
                        expandedSections.insert(mealType)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: mealTypeIcon(mealType))
                        .foregroundColor(mealTypeColor(mealType))
                        .font(.title3)
                        .frame(width: 28)

                    Text(mealType.label)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Text("\(Int(sectionCalories)) 千卡")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.vertical, 12)
            }

            if isExpanded {
                Divider()

                if records.isEmpty {
                    Text("暂无记录")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.vertical, 12)
                } else {
                    ForEach(records) { record in
                        foodRow(record)
                        if record.id != records.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }

                // AI 饮食分析
                if !records.isEmpty {
                    if let analysis = mealAnalysis[mealType] {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.lavender)
                                .padding(.top, 2)
                            Text(analysis)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(8)
                        .background(AppTheme.lavender.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if analyzingMeal == mealType {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("AI 分析中...")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            analyzeMeal(mealType, records: records)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("AI 饮食分析")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(AppTheme.lavender)
                        }
                        .padding(.vertical, 4)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        selectedMealTypeForManual = mealType
                        showManualFoodInput = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("手动添加")
                                .foregroundColor(AppTheme.primaryGreen)
                                .font(.caption.weight(.medium))
                        }
                    }

                    Divider().frame(height: 20)

                    Button {
                        selectedMealTypeForRecognition = mealType
                        showFoodRecognition = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(AppTheme.softBlue)
                            Text("拍照识别")
                                .foregroundColor(AppTheme.softBlue)
                                .font(.caption.weight(.medium))
                        }
                    }

                    Divider().frame(height: 20)

                    Button {
                        historyMealType = mealType
                        showFoodHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppTheme.warmYellow)
                            Text("历史记录")
                                .foregroundColor(AppTheme.warmYellow)
                                .font(.caption.weight(.medium))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, AppTheme.padding)
        .background(AppTheme.surfaceColor)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
    }

    private func foodRow(_ record: FoodRecord) -> some View {
        HStack(spacing: 10) {
            // Photo thumbnail
            if let imageData = record.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Color.clear
                    .frame(width: 0, height: 0)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(record.foodName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.primaryText)
                    Text(timeString(record.date))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Text("蛋白质 \(String(format: "%.1f", record.protein))g | 碳水 \(String(format: "%.1f", record.carbs))g | 脂肪 \(String(format: "%.1f", record.fat))g")
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Text("\(Int(record.calories)) 千卡")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryGreen)

            Button {
                modelContext.delete(record)
                try? modelContext.save()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button {
            showFoodRecognition = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [AppTheme.primaryGreen, Color(hex: "8BE4A8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: AppTheme.primaryGreen.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, AppTheme.largePadding)
        .padding(.bottom, AppTheme.largePadding)
    }

    // MARK: - Helpers

    private func analyzeMeal(_ mealType: MealType, records: [FoodRecord]) {
        analyzingMeal = mealType
        let foodList = records.map { "\($0.foodName) \(Int($0.calories))千卡 蛋白\(String(format:"%.0f",($0.protein)))g 碳水\(String(format:"%.0f",($0.carbs)))g 脂肪\(String(format:"%.0f",($0.fat)))g" }.joined(separator: "、")

        Task {
            do {
                // Use Gemini directly for analysis
                guard let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key"), !apiKey.isEmpty else {
                    mealAnalysis[mealType] = "请在「我的」→「AI 设置」中配置 API Key"
                    analyzingMeal = nil
                    return
                }

                let prompt = "我\(mealType.label)吃了：\(foodList)。请用1-2句话简短分析这顿饭的营养搭配，指出不足并给出改进建议。直接回复分析文字，不要任何前缀。"

                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
                guard let url = URL(string: urlString) else { return }

                let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                // Check for API error
                if let error = json?["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    mealAnalysis[mealType] = "API错误：\(message)"
                } else if let candidates = json?["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    mealAnalysis[mealType] = text.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    let responseStr = String(data: data.prefix(200), encoding: .utf8) ?? "无响应"
                    mealAnalysis[mealType] = "解析失败：\(responseStr)"
                }
            } catch {
                mealAnalysis[mealType] = "错误：\(error.localizedDescription)"
            }
            analyzingMeal = nil
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func mealTypeIcon(_ type: MealType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    private func mealTypeColor(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return AppTheme.warmYellow
        case .lunch: return AppTheme.primaryGreen
        case .dinner: return AppTheme.coral
        case .snack: return AppTheme.lavender
        }
    }


}

// MARK: - Meal Food Input View

import PhotosUI

struct MealFoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType

    @State private var foodName = ""
    @State private var weight: Double = 100
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var isAIEstimating = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var foodImageData: Data?
    @State private var showPhotoOptions = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("食物信息") {
                    // Photo area
                    HStack {
                        Button {
                            showPhotoOptions = true
                        } label: {
                            if let foodImageData, let uiImage = UIImage(data: foodImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18))
                                    Text("添加照片")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.gray)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .confirmationDialog("选择照片来源", isPresented: $showPhotoOptions) {
                            Button("拍照") { showCamera = true }
                            Button("从相册选择") { showPhotoPicker = true }
                            Button("取消", role: .cancel) {}
                        }
                        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
                        .onChange(of: selectedPhotoItem) {
                            Task {
                                if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self) {
                                    if let img = UIImage(data: data), let compressed = img.jpegData(compressionQuality: 0.6) {
                                        foodImageData = compressed
                                    }
                                }
                            }
                        }
                        .fullScreenCover(isPresented: $showCamera) {
                            CameraView(imageData: $foodImageData)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            TextField("食物名称", text: $foodName)
                                .font(.subheadline)
                        }
                    }

                    HStack {
                        Text("重量")
                        Spacer()
                        TextField("100", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }

                Section("营养信息") {
                    nutrientRow("热量 (千卡)", value: $calories)
                    nutrientRow("蛋白质 (g)", value: $protein)
                    nutrientRow("碳水 (g)", value: $carbs)
                    nutrientRow("脂肪 (g)", value: $fat)
                }

                Section {
                    Button {
                        estimateWithAI()
                    } label: {
                        HStack {
                            if isAIEstimating {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("AI 正在估算...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("AI 自动估算营养成分")
                            }
                        }
                        .foregroundColor(AppTheme.lavender)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(foodName.isEmpty || isAIEstimating)
                }
            }
            .navigationTitle("\(mealType.label) - 添加食物")
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
                            foodName: foodName.isEmpty ? "食物" : foodName,
                            weight: weight,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            fiber: 0,
                            waterMl: 0,
                            imageData: foodImageData
                        )
                        modelContext.insert(record)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(foodName.isEmpty)
                }
            }
        }
    }

    private func nutrientRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func estimateWithAI() {
        guard !foodName.isEmpty else { return }
        isAIEstimating = true

        Task {
            do {
                guard let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key"), !apiKey.isEmpty else {
                    isAIEstimating = false
                    return
                }

                let prompt = "\(foodName) \(weight)克的营养成分，只返回纯JSON，不要markdown格式，不要```，格式：{\"calories\":数字,\"protein\":数字,\"carbs\":数字,\"fat\":数字}"

                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
                guard let url = URL(string: urlString) else {
                    isAIEstimating = false
                    return
                }

                let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    // 提取 JSON
                    var jsonStr = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 去掉 markdown 代码块
                    jsonStr = jsonStr.replacingOccurrences(of: "```json", with: "")
                    jsonStr = jsonStr.replacingOccurrences(of: "```", with: "")
                    jsonStr = jsonStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 安全提取 {} 之间的内容
                    if let startIdx = jsonStr.firstIndex(of: "{"),
                       let endIdx = jsonStr.lastIndex(of: "}") {
                        jsonStr = String(jsonStr[startIdx...endIdx])
                    }
                    if let jsonData = jsonStr.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        await MainActor.run {
                            calories = (parsed["calories"] as? Double) ?? (parsed["calories"] as? Int).map(Double.init) ?? 0
                            protein = (parsed["protein"] as? Double) ?? (parsed["protein"] as? Int).map(Double.init) ?? 0
                            carbs = (parsed["carbs"] as? Double) ?? (parsed["carbs"] as? Int).map(Double.init) ?? 0
                            fat = (parsed["fat"] as? Double) ?? (parsed["fat"] as? Int).map(Double.init) ?? 0
                        }
                    }
                }
            } catch {
                // Silently fail
            }
            isAIEstimating = false
        }
    }
}

// MARK: - Food History View

struct FoodHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let allRecords: [FoodRecord]

    @State private var searchText = ""
    @State private var adjustingRecord: FoodRecord? = nil

    private var uniqueFoods: [FoodRecord] {
        var seen = Set<String>()
        var result: [FoodRecord] = []
        let sorted = allRecords.sorted { $0.date > $1.date }
        for record in sorted {
            if !seen.contains(record.foodName) {
                seen.insert(record.foodName)
                result.append(record)
            }
        }
        if searchText.isEmpty { return result }
        return result.filter { $0.foodName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if uniqueFoods.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.secondaryText.opacity(0.4))
                        Text("暂无历史记录")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(uniqueFoods, id: \.id) { record in
                            Button {
                                adjustingRecord = record
                            } label: {
                                HStack(spacing: 12) {
                                    if let imageData = record.imageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppTheme.lightGreen)
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "fork.knife")
                                                .foregroundColor(AppTheme.primaryGreen)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.foodName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppTheme.primaryText)
                                        HStack(spacing: 4) {
                                            Text("\(Int(record.weight))g")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(AppTheme.primaryGreen)
                                            Text("·")
                                                .font(.caption2)
                                                .foregroundColor(AppTheme.secondaryText)
                                            Text("蛋白 \(String(format: "%.1f", record.protein))g · 碳水 \(String(format: "%.1f", record.carbs))g · 脂肪 \(String(format: "%.1f", record.fat))g")
                                                .font(.caption2)
                                                .foregroundColor(AppTheme.secondaryText)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text("\(Int(record.calories))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(AppTheme.primaryGreen)
                                        Text("千卡")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.secondaryText)
                                    }

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.primaryGreen)
                                        .font(.title3)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "搜索食物")
                }
            }
            .navigationTitle("历史食物 · \(mealType.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(AppTheme.primaryGreen)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .sheet(item: $adjustingRecord) { record in
                WeightAdjustSheet(source: record, mealType: mealType) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 克重调整 Sheet

struct WeightAdjustSheet: View {
    let source: FoodRecord
    let mealType: MealType
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double

    init(source: FoodRecord, mealType: MealType, onSaved: @escaping () -> Void) {
        self.source = source
        self.mealType = mealType
        self.onSaved = onSaved
        self._weight = State(initialValue: source.weight)
    }

    private var ratio: Double { weight / max(source.weight, 1) }
    private var adjCalories: Double { source.calories * ratio }
    private var adjProtein:  Double { source.protein  * ratio }
    private var adjCarbs:    Double { source.carbs    * ratio }
    private var adjFat:      Double { source.fat      * ratio }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 食物标题
                HStack(spacing: 12) {
                    if let data = source.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.lightGreen)
                                .frame(width: 52, height: 52)
                            Image(systemName: "fork.knife")
                                .foregroundColor(AppTheme.primaryGreen)
                                .font(.title3)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.foodName)
                            .font(.headline)
                        Text("上次记录：\(Int(source.weight))g · \(Int(source.calories)) 千卡")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                ScrollView {
                    VStack(spacing: 24) {
                        // 克重输入
                        VStack(spacing: 12) {
                            Text("本次克重")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                Button { weight = max(1, weight - 10) } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .background(Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                HStack(spacing: 4) {
                                    TextField("100", value: $weight, format: .number.precision(.fractionLength(0)))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primaryGreen)
                                        .frame(width: 100)
                                    Text("g")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                Button { weight += 10 } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .background(Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }

                            Slider(value: $weight, in: 1...1000, step: 5)
                                .tint(AppTheme.primaryGreen)
                        }
                        .padding(.horizontal, 20)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("完成") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }

                        // 换算后营养预览
                        VStack(spacing: 8) {
                            Text("换算后营养")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 0) {
                                nutriCell(label: "热量", value: String(format: "%.0f", adjCalories), unit: "千卡", color: AppTheme.primaryGreen)
                                Divider().frame(height: 40)
                                nutriCell(label: "蛋白质", value: String(format: "%.1f", adjProtein), unit: "g", color: AppTheme.softBlue)
                                Divider().frame(height: 40)
                                nutriCell(label: "碳水", value: String(format: "%.1f", adjCarbs), unit: "g", color: AppTheme.warmYellow)
                                Divider().frame(height: 40)
                                nutriCell(label: "脂肪", value: String(format: "%.1f", adjFat), unit: "g", color: AppTheme.coral)
                            }
                            .padding(.vertical, 10)
                            .background(AppTheme.surfaceColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }

                // 添加按钮
                Button {
                    let record = FoodRecord(
                        date: .now,
                        mealType: mealType,
                        foodName: source.foodName,
                        weight: weight,
                        calories: adjCalories,
                        protein: adjProtein,
                        carbs: adjCarbs,
                        fat: adjFat,
                        fiber: source.fiber * ratio,
                        waterMl: source.waterMl * ratio,
                        imageData: source.imageData
                    )
                    modelContext.insert(record)
                    try? modelContext.save()
                    dismiss()
                    onSaved()
                } label: {
                    Text("添加到\(mealType.label)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("调整克重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func nutriCell(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(unit).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DietView()
        .modelContainer(for: FoodRecord.self, inMemory: true)
}
