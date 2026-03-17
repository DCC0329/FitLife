import SwiftUI
import SwiftData

struct ProfileView: View {
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_age") private var userAge: Int = 25
    @AppStorage("user_gender") private var userGender: String = "男"
    @AppStorage("user_height") private var userHeight: Double = 170.0
    @AppStorage("user_weight") private var userWeight: Double = 65.0
    @AppStorage("goal_weight") private var goalWeight: Double = 60.0
    @StateObject private var aiManager = AIServiceManager.shared
    @State private var currentAPIKey: String = ""
    @Environment(\.modelContext) private var modelContext
    @State private var showingWeightInput = false
    @State private var showingImagePicker = false
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var exportError: String?
    @State private var showingExportError = false
    @State private var showingCertAlert = false
    @AppStorage("user_avatar_data") private var avatarData: Data?
    @AppStorage("start_weight") private var startWeight: Double = 0

    // MARK: - Natural Fresh Palette (清新自然)

    private let sage       = Color(hex: "87B5A2")   // 鼠尾草绿（主色）
    private let sageLight  = Color(hex: "EDF4F1")   // 淡鼠尾草
    private let clay       = Color(hex: "C4856A")   // 暖陶土（强调色）
    private let clayLight  = Color(hex: "FAF0EB")   // 淡陶土
    private let stone      = Color(hex: "8FA08E")   // 石青灰绿（第三色）
    private let stoneLight = Color(hex: "EEF2ED")   // 淡石青
    private let cardWhite  = Color.white
    private let pageBg     = Color(hex: "F2EFE9")   // 温暖亚麻底色

    private var bmi: Double {
        let heightInMeters = userHeight / 100.0
        guard heightInMeters > 0 else { return 0 }
        return userWeight / (heightInMeters * heightInMeters)
    }

    private var weightGoalProgress: Double {
        let start = startWeight > 0 ? startWeight : userWeight
        guard start > goalWeight else { return start == goalWeight ? 1.0 : 0 }
        let totalToLose = start - goalWeight
        let lost = start - userWeight
        return min(max(lost / totalToLose, 0), 1.0)
    }

    // 证书剩余天数（读取 App bundle 修改时间，每次重装自动重置）
    private var certDaysRemaining: Int {
        guard let bundlePath = Bundle.main.executablePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: bundlePath),
              let installDate = attrs[.modificationDate] as? Date else { return 7 }
        let elapsed = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        return max(7 - elapsed, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    topCard
                    infoCardsRow
                    certBanner
                    aiSettingsCard
                    dataExportCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(pageBg)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingWeightInput) {
                WeightInputView()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("导出失败", isPresented: $showingExportError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(exportError ?? "未知错误")
            }
            .alert("证书即将过期", isPresented: $showingCertAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("App 证书明天就到期了，记得连上电脑用 Xcode ▶ 重新安装，数据不会丢失。")
            }
            .onAppear {
                if certDaysRemaining == 1 {
                    showingCertAlert = true
                }
            }
        }
    }

    // MARK: - Cert Banner

    private var certBanner: some View {
        let days = certDaysRemaining
        let isUrgent = days <= 2
        let color: Color = isUrgent ? clay : stone
        let bgColor: Color = isUrgent ? clayLight : stoneLight
        let icon = isUrgent ? "exclamationmark.triangle.fill" : "clock.fill"

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)

            if days == 0 {
                Text("证书已过期，请用 Xcode 重新安装")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
            } else {
                Text("App 证书还剩 ")
                    .font(.system(size: 13))
                    .foregroundStyle(color) +
                Text("\(days) 天")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color) +
                Text(" 到期，到期后用 Xcode ▶ 重装即可")
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Card

    private var topCard: some View {
        HStack(spacing: 0) {
            // 左侧
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    showingImagePicker = true
                } label: {
                    if let avatarData, let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(sage.opacity(0.3), lineWidth: 2))
                    } else {
                        Circle()
                            .fill(sageLight)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(sage.opacity(0.6))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(userName.isEmpty ? "设置昵称" : userName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    Text("\(userWeight, specifier: "%.1f") kg  \(userGender)  \(userAge)岁")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("\(userWeight, specifier: "%.1f")")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(goalWeight, specifier: "%.1f") kg")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            // 右侧：圆形进度环
            ZStack {
                Circle()
                    .stroke(sageLight, lineWidth: 10)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: weightGoalProgress)
                    .stroke(
                        LinearGradient(
                            colors: [sage, stone],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: weightGoalProgress)

                VStack(spacing: 2) {
                    Text("\(Int(weightGoalProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(sage)
                    Text("减肥进度")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(22)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
        .sheet(isPresented: $showingImagePicker) {
            AvatarPicker(avatarData: $avatarData)
        }
    }

    // MARK: - Info Cards Row

    @State private var showBodyInfoEdit = false
    @State private var showWeightManagement = false

    private var infoCardsRow: some View {
        HStack(spacing: 12) {
            // 体重管理卡
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 10))
                    Text("体重管理")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(sage)

                Spacer().frame(height: 12)

                Text("\(userWeight, specifier: "%.1f")")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.primaryText)
                + Text(" kg")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer().frame(height: 14)

                HStack(spacing: 8) {
                    Button {
                        showingWeightInput = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 9))
                            Text("记录")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(sage)
                        .clipShape(Capsule())
                    }

                    NavigationLink {
                        WeightHistoryView()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 9))
                            Text("历史")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(sage)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(sageLight)
                        .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

            // 右侧双卡
            VStack(spacing: 12) {
                // 身体信息卡
                NavigationLink {
                    BodyInfoEditView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 9))
                                Text("身体信息")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(stone)

                            HStack(spacing: 2) {
                                Text("\(userHeight, specifier: "%.0f")")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primaryText)
                                Text("cm")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .padding(12)
                    .background(stoneLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // 健康指标卡
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 9))
                        Text("健康指标")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(clay)

                    HStack(spacing: 2) {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText)
                        Text("BMI")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(clayLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - AI Settings Card

    private var aiSettingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI 设置")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 14)

            VStack(spacing: 14) {
                Picker("AI 服务", selection: $aiManager.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.system(size: 13))
                            .foregroundColor(stone)
                            .frame(width: 30, height: 30)
                            .background(stoneLight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("\(aiManager.currentProvider.displayName) API Key")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.primaryText)

                        Spacer()

                        if aiManager.isConfigured(provider: aiManager.currentProvider) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(sage)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }

                    SecureField("请输入 API Key", text: $currentAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)
                        .onChange(of: currentAPIKey) { _, newValue in
                            aiManager.setApiKey(newValue, for: aiManager.currentProvider)
                        }
                        .onChange(of: aiManager.selectedProvider) { _, _ in
                            currentAPIKey = aiManager.apiKey(for: aiManager.currentProvider) ?? ""
                        }
                        .onAppear {
                            currentAPIKey = aiManager.apiKey(for: aiManager.currentProvider) ?? ""
                        }
                }
            }
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Data Export Card

    private var dataExportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("数据导出")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 14)

            HStack(spacing: 12) {
                Button {
                    performExport(type: .csv)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 14))
                        Text("导出 CSV")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(stone)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    performExport(type: .pdf)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 14))
                        Text("导出 PDF 报告")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(clay)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(18)
        .background(cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private enum ExportType { case csv, pdf }

    private func performExport(type: ExportType) {
        let exporter = DataExporter(modelContext: modelContext)
        do {
            let url: URL
            switch type {
            case .csv:
                url = try exporter.exportCSV()
            case .pdf:
                url = try exporter.exportPDF()
            }
            exportFileURL = url
            showingShareSheet = true
        } catch {
            exportError = error.localizedDescription
            showingExportError = true
        }
    }
}

// MARK: - Weight History View

struct WeightHistoryView: View {
    @Query(sort: \WeightRecord.date, order: .reverse) private var records: [WeightRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("暂无记录", systemImage: "scalemass", description: Text("请先记录体重数据"))
            } else {
                ForEach(records) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(record.weight, specifier: "%.1f") kg")
                                .font(.headline)
                                .foregroundColor(Color(hex: "4A3F8F"))
                            if let note = record.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(record.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteRecords)
            }
        }
        .navigationTitle("体重历史")
        .toolbar {
            if !records.isEmpty {
                EditButton()
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

// MARK: - Avatar Picker

import PhotosUI

struct AvatarPicker: View {
    @Binding var avatarData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray.opacity(0.3))
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("选择头像")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "4ECB71"))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .navigationTitle("设置头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data),
                           let compressed = uiImage.jpegData(compressionQuality: 0.5) {
                            avatarData = compressed
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ProfileView()
}
