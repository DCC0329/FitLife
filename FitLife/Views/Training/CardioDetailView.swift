import SwiftUI
import SwiftData

struct CardioDetailView: View {
    let exercise: CardioExercise
    var themeColor: Color = Color(hex: "7B6CF6")

    @Environment(\.modelContext) private var modelContext
    @AppStorage("user_weight") private var userWeight: Double = 65.0
    @StateObject private var healthKit = HealthKitManager()

    @State private var showFullDescription = false
    @State private var showSavedAlert = false
    @State private var savedMinutes = 0
    @State private var savedCalories = 0

    // Timer UI state
    @State private var isActive = false
    @State private var isPaused = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    // Persisted so the timer survives page exits
    @AppStorage("cardio_start_epoch") private var startEpoch: Double = 0
    @AppStorage("cardio_exercise_id") private var activeExerciseId: String = ""
    @AppStorage("cardio_paused_elapsed") private var pausedElapsed: Int = 0
    @AppStorage("cardio_is_paused") private var storedIsPaused: Bool = false

    private var isThisExerciseActive: Bool { activeExerciseId == exercise.id }

    private var estimatedCalories: Double {
        let hours = Double(elapsedSeconds) / 3600.0
        return met(for: exercise.name) * userWeight * hours
    }

    private func met(for name: String) -> Double {
        switch name {
        case "跳绳", "HIIT间歇训练": return 10.0
        case "跑步（室外）", "跑步机": return 8.5
        case "游泳": return 7.0
        case "跑步机爬坡训练": return 8.0
        case "骑行（户外）": return 7.5
        case "室内单车（动感单车）": return 6.5
        case "椭圆机": return 6.0
        case "划船机", "皮划艇 / 划船": return 6.0
        case "爬楼机": return 8.0
        case "有氧操（跳操）": return 6.5
        case "搏击操 / 拳击有氧": return 7.5
        case "徒步 / 登山": return 6.0
        case "快走": return 4.5
        case "瑜伽": return 3.0
        case "普拉提": return 3.5
        default: return 5.0
        }
    }

    private var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                timerSection
                keyPointsSection
                trainingTipsSection
                precautionsSection
                suggestedPlanSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .alert("已保存", isPresented: $showSavedAlert) {
            Button("好") {}
        } message: {
            Text("训练记录已保存：\(exercise.name) \(savedMinutes) 分钟，消耗约 \(savedCalories) 千卡")
        }
        .task { await healthKit.requestAuthorization() }
        .onAppear { restoreTimerIfNeeded() }
        .onDisappear {
            // Invalidate the tick timer but keep AppStorage so state survives
            timer?.invalidate()
            timer = nil
            if isActive && !isPaused {
                // Still running in background — keep startEpoch as-is
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: exercise.icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(exercise.category)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeColor)
                        .clipShape(Capsule())
                }

                Text(exercise.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(showFullDescription ? nil : 2)

                if exercise.description.count > 40 {
                    Button {
                        withAnimation { showFullDescription.toggle() }
                    } label: {
                        Text(showFullDescription ? "收起" : "展开全文")
                            .font(.system(size: 9))
                            .foregroundColor(themeColor)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                statCell(
                    value: timeString,
                    label: "训练时长",
                    color: isActive ? themeColor : AppTheme.primaryText,
                    isMonospaced: true
                )

                dividerLine

                statCell(
                    value: "\(Int(estimatedCalories))",
                    label: "预估千卡",
                    color: AppTheme.coral
                )

                dividerLine

                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        Text(healthKit.currentHeartRate > 0 ? "\(Int(healthKit.currentHeartRate))" : "--")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                    }
                    Text("心率 BPM")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }

            // Buttons
            if !isActive {
                Button { startTimer() } label: {
                    Label("开始训练", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeColor)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            } else {
                HStack(spacing: 12) {
                    Button { isPaused ? resumeTimer() : pauseTimer() } label: {
                        Label(isPaused ? "继续" : "暂停",
                              systemImage: isPaused ? "play.fill" : "pause.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }

                    Button { stopAndSave() } label: {
                        Label("结束保存", systemImage: "stop.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.coral)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
    }

    private func statCell(value: String, label: String, color: Color, isMonospaced: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(isMonospaced
                      ? .system(size: 28, weight: .bold, design: .monospaced)
                      : .system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1, height: 44)
    }

    // MARK: - Timer Logic

    private func restoreTimerIfNeeded() {
        guard isThisExerciseActive, startEpoch > 0 else { return }
        isActive = true
        if storedIsPaused {
            isPaused = true
            elapsedSeconds = pausedElapsed
        } else {
            isPaused = false
            elapsedSeconds = Int(Date().timeIntervalSince1970 - startEpoch)
            startTick()
            healthKit.startHeartRateObserver()
        }
    }

    private func startTimer() {
        startEpoch = Date().timeIntervalSince1970
        activeExerciseId = exercise.id
        pausedElapsed = 0
        storedIsPaused = false
        isActive = true
        isPaused = false
        elapsedSeconds = 0
        healthKit.startHeartRateObserver()
        startTick()
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        pausedElapsed = elapsedSeconds
        storedIsPaused = true
        isPaused = true
    }

    private func resumeTimer() {
        // Adjust startEpoch so elapsed = now - startEpoch = pausedElapsed
        startEpoch = Date().timeIntervalSince1970 - Double(pausedElapsed)
        storedIsPaused = false
        isPaused = false
        startTick()
    }

    private func startTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds = Int(Date().timeIntervalSince1970 - startEpoch)
        }
    }

    private func stopAndSave() {
        timer?.invalidate()
        timer = nil
        healthKit.stopHeartRateObserver()

        savedMinutes = max(elapsedSeconds / 60, 1)
        savedCalories = Int(estimatedCalories)

        let record = ExerciseRecord(
            date: .now,
            name: exercise.name,
            duration: savedMinutes,
            calories: estimatedCalories
        )
        modelContext.insert(record)
        try? modelContext.save()

        // Clear persisted state
        startEpoch = 0
        activeExerciseId = ""
        pausedElapsed = 0
        storedIsPaused = false
        isActive = false
        isPaused = false
        elapsedSeconds = 0
        showSavedAlert = true
    }

    // MARK: - Content Sections

    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "target", title: "动作要点", color: themeColor)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.keyPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(themeColor)
                            .clipShape(Circle())

                        Text(point)
                            .font(.callout)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineSpacing(2)
                            .padding(.top, 3)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
        }
    }

    private var trainingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "lightbulb.fill", title: "训练建议", color: AppTheme.softBlue)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.trainingTips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.softBlue)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.callout)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineSpacing(2)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
        }
    }

    private var precautionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: "注意事项", color: AppTheme.coral)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.precautions.enumerated()), id: \.offset) { _, precaution in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.coral)
                            .padding(.top, 2)
                        Text(precaution)
                            .font(.callout)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineSpacing(2)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
        }
    }

    private var suggestedPlanSection: some View {
        let lines = exercise.suggestedPlan
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "list.clipboard.fill", title: "推荐训练计划", color: themeColor)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isTitle = !line.contains("：") && !line.contains(":") && index == 0
                    if isTitle {
                        Text(line)
                            .font(.headline)
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(themeColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            Text(line)
                                .font(.callout)
                                .foregroundStyle(AppTheme.primaryText)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                        if index < lines.count - 1 {
                            Divider().padding(.leading, 34).padding(.trailing, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .padding(.bottom, 16)
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        CardioDetailView(exercise: CardioExercise.all[0], themeColor: Color(hex: "5B9BD5"))
    }
}
