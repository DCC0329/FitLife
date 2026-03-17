import SwiftUI

// MARK: - Body Part Category

struct BodyPartCategory: Identifiable {
    let id = UUID()
    let name: String
    let apiValues: [String]
    let icon: String

    static let all: [BodyPartCategory] = [
        BodyPartCategory(name: "胸部", apiValues: ["chest"], icon: "figure.strengthtraining.traditional"),
        BodyPartCategory(name: "背部", apiValues: ["back"], icon: "figure.rower"),
        BodyPartCategory(name: "肩部", apiValues: ["shoulders"], icon: "figure.arms.open"),
        BodyPartCategory(name: "腿部", apiValues: ["upper legs", "lower legs"], icon: "figure.run"),
        BodyPartCategory(name: "手臂", apiValues: ["upper arms", "lower arms"], icon: "figure.boxing"),
        BodyPartCategory(name: "核心", apiValues: ["waist"], icon: "figure.core.training"),
    ]
}

// MARK: - Training View

struct TrainingView: View {
    private let strengthCategories = BodyPartCategory.all
    private let cardioExercises = CardioExercise.all

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - 力量训练
                    sectionHeader(title: "力量训练", icon: "figure.strengthtraining.traditional", color: Color(hex: "E8DF98"))

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(strengthCategories) { category in
                            NavigationLink {
                                ExerciseListView(
                                    bodyParts: category.apiValues,
                                    chineseName: category.name
                                )
                            } label: {
                                strengthCard(category: category)
                            }
                        }
                    }

                    // MARK: - 有氧训练
                    sectionHeader(title: "有氧训练", icon: "heart.circle.fill", color: Color(hex: "A89FEC"))

                    // 室内有氧
                    subSectionHeader(title: "室内", icon: "house.fill")

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cardioExercises.filter { $0.category == "室内" }) { exercise in
                            NavigationLink {
                                CardioDetailView(exercise: exercise, themeColor: Color(hex: "5B9BD5"))
                            } label: {
                                cardioCard(exercise: exercise, color: Color(hex: "A2D8E8"))
                            }
                        }
                    }

                    // 室外有氧
                    subSectionHeader(title: "室外", icon: "sun.max.fill")

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cardioExercises.filter { $0.category == "室外" }) { exercise in
                            NavigationLink {
                                CardioDetailView(exercise: exercise, themeColor: Color(hex: "D4607E"))
                            } label: {
                                cardioCard(exercise: exercise, color: Color(hex: "E3B7C8"))
                            }
                        }
                    }

                    // 低强度有氧
                    subSectionHeader(title: "低强度", icon: "leaf.fill")

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cardioExercises.filter { $0.category == "低强度" }) { exercise in
                            NavigationLink {
                                CardioDetailView(exercise: exercise, themeColor: Color(hex: "9B72CF"))
                            } label: {
                                cardioCard(exercise: exercise, color: Color(hex: "B8D4A3"))
                            }
                        }
                    }

                    // 游戏健身
                    subSectionHeader(title: "游戏健身", icon: "gamecontroller.fill")

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(GameFitness.all) { game in
                            NavigationLink {
                                CardioDetailView(exercise: game.toCardioExercise(), themeColor: Color(hex: "7B6CF6"))
                            } label: {
                                cardioCard(exercise: game.toCardioExercise(), color: Color(hex: "A89FEC"))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("训练指导")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section Headers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.top, 8)
    }

    private func subSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Strength Card

    private func strengthCard(category: BodyPartCategory) -> some View {
        VStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: "E8DF98"))

            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: "2E2E2E"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(AppTheme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Cardio Card

    private func cardioCard(exercise: CardioExercise, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: exercise.icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            Text(exercise.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: "2E2E2E"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(AppTheme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Game Fitness Card

    private func gameFitnessCard(game: GameFitness) -> some View {
        VStack(spacing: 8) {
            Image(systemName: game.icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [AppTheme.lavender, AppTheme.lavender.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            Text(game.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(AppTheme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Game Fitness Data

struct GameFitness: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let keyPoints: [String]
    let trainingTips: [String]
    let precautions: [String]
    let suggestedPlan: String

    func toCardioExercise() -> CardioExercise {
        CardioExercise(
            id: id,
            name: name,
            icon: icon,
            category: "游戏健身",
            description: description,
            keyPoints: keyPoints,
            trainingTips: trainingTips,
            precautions: precautions,
            suggestedPlan: suggestedPlan
        )
    }

    static let all: [GameFitness] = [
        GameFitness(
            id: "ring_fit",
            name: "健身环大冒险",
            icon: "circle.circle.fill",
            description: "Nintendo Switch上的体感健身游戏，通过Ring-Con和腿部固定带，将运动融入冒险游戏。玩家需要做深蹲、慢跑、瑜伽等多种动作来战斗和探索，非常适合不喜欢传统健身的人。",
            keyPoints: [
                "每次游戏前做5分钟热身，游戏设置中选择适合自己的运动强度",
                "做深蹲动作时注意膝盖不要超过脚尖，背部保持挺直",
                "Ring-Con挤压和拉伸动作要用力到位，半途而废效果差",
                "慢跑时原地抬腿幅度要够，不要偷懒小幅度晃动",
                "注意呼吸节奏，发力时呼气，放松时吸气"
            ],
            trainingTips: [
                "初学者建议设置运动强度在15-20之间，随体能提升逐步增加",
                "每次游玩30-60分钟为宜，游戏内的冷却提示要遵守",
                "可以搭配自定义模式针对特定部位强化训练",
                "坚持每天打卡，游戏的成就系统会帮助你保持动力"
            ],
            precautions: [
                "确保周围有足够空间，移开易碎物品",
                "穿运动鞋，在瑜伽垫上进行，保护关节",
                "出汗后及时擦干Joy-Con手柄，防止打滑",
                "感到头晕或不适立即停止，不要勉强"
            ],
            suggestedPlan: """
            初学者4周计划：
            第1周：每天20分钟，强度15，熟悉基本动作
            第2周：每天30分钟，强度18，开始挑战关卡
            第3周：每天30分钟，强度20，加入自定义训练
            第4周：每天40分钟，强度22，尝试高难度关卡
            每周休息1-2天，搭配拉伸放松
            """
        ),
        GameFitness(
            id: "just_dance",
            name: "舞力全开",
            icon: "figure.dance",
            description: "经典的体感舞蹈游戏，跟随屏幕上的舞者模仿动作，支持多人同玩。通过跳舞的方式进行全身有氧运动，燃脂效果好，而且非常有趣。适合各年龄段，是派对和日常健身的好选择。",
            keyPoints: [
                "跟随屏幕动作时注重大幅度的手臂和身体动作，动作越大消耗越多",
                "保持核心收紧，很多舞步都需要腰腹发力来保持稳定",
                "脚步要踩准节拍，这不仅是得分关键也能保证运动节奏",
                "全程保持微屈膝，避免在跳跃和转身时锁死膝关节"
            ],
            trainingTips: [
                "选择Sweat模式专注燃脂，系统会推荐高强度舞曲组合",
                "从简单难度开始，掌握基本舞步后再挑战更高难度",
                "每次跳30-45分钟，中间可以穿插慢歌休息",
                "和朋友一起跳更有动力，多人模式增加趣味性"
            ],
            precautions: [
                "需要较大的活动空间，至少2米x2米的空地",
                "穿防滑的运动鞋，不建议赤脚或穿袜子跳",
                "注意地板材质，木地板或地毯比瓷砖更安全",
                "大量出汗时注意补水，每15-20分钟喝一口水"
            ],
            suggestedPlan: """
            每周跳舞计划：
            周一：30分钟中等强度，流行舞曲
            周三：40分钟Sweat模式，高强度燃脂
            周五：30分钟自由选曲，享受音乐
            周末：和家人朋友一起多人对战
            目标：每周3-4次，每次至少30分钟
            """
        ),
        GameFitness(
            id: "beat_saber",
            name: "节奏光剑",
            icon: "wand.and.stars",
            description: "VR音乐节奏游戏，玩家用双手挥舞光剑切割飞来的方块，同时躲避障碍物。高强度的上肢和核心运动，沉浸式的VR体验让你忘记运动的疲劳。需要VR头显设备（如Meta Quest）。",
            keyPoints: [
                "挥剑动作从肩膀发力，不仅仅是手腕，增大动作幅度提升运动效果",
                "躲避障碍物时用深蹲和侧步，训练下肢力量和灵活性",
                "保持核心收紧，很多转体切割动作需要腰腹稳定",
                "双臂交替和同时挥舞，注意动作的对称性"
            ],
            trainingTips: [
                "Expert及以上难度才能达到较好的健身效果",
                "安装运动追踪插件可以记录消耗的卡路里",
                "每次游玩30-45分钟，强度相当于中高强度有氧",
                "选择快节奏歌曲，BPM越高运动强度越大"
            ],
            precautions: [
                "VR游戏需要更大的安全空间，设置好Guardian边界",
                "每30分钟休息一次，摘下头显让眼睛休息",
                "注意VR晕动症，感到不适立即停止",
                "大量出汗会影响头显佩戴，准备吸汗面罩"
            ],
            suggestedPlan: """
            VR健身计划：
            热身：5分钟Easy难度歌曲
            正式训练：25分钟Expert难度
            冷却：5分钟Normal难度慢歌
            每周3-4次，搭配其他训练方式
            """
        ),
        GameFitness(
            id: "apple_fitness",
            name: "Apple Fitness+",
            icon: "applelogo",
            description: "Apple官方的健身订阅服务，提供专业教练指导的视频课程，与Apple Watch深度整合，实时显示心率和消耗。涵盖HIIT、瑜伽、力量、舞蹈、骑行、跑步等多种课程类型。",
            keyPoints: [
                "佩戴Apple Watch开始训练，实时追踪心率和运动环数据",
                "跟随教练的提示调整强度，每个课程都有初学者修改版动作",
                "利用Burn Bar功能和其他参与者对比运动强度，保持动力",
                "课程结束后的冷却拉伸环节不要跳过"
            ],
            trainingTips: [
                "新手建议从10-20分钟的课程开始，逐步增加到30-45分钟",
                "利用筛选功能找到适合自己水平和喜欢的教练",
                "搭配不同类型的课程：周一HIIT、周三力量、周五瑜伽",
                "使用SharePlay功能和朋友一起训练增加动力"
            ],
            precautions: [
                "需要Apple Watch和Apple Fitness+订阅",
                "确保Apple Watch电量充足再开始训练",
                "根据心率区间调整强度，不要长时间停留在最高心率区",
                "家中训练注意周围空间和地面防滑"
            ],
            suggestedPlan: """
            每周训练安排：
            周一：20分钟 HIIT + 10分钟核心
            周二：休息或轻度瑜伽
            周三：30分钟 力量训练
            周四：20分钟 舞蹈有氧
            周五：30分钟 骑行或跑步
            周末：瑜伽/冥想恢复，或户外运动
            """
        ),
        GameFitness(
            id: "fitness_boxing_3",
            name: "有氧拳击3",
            icon: "figure.boxing",
            description: "Nintendo Switch上的拳击健身游戏，跟随屏幕提示做出直拳、勾拳、上勾拳等拳击动作，配合步伐移动和闪躲。节奏感强，全身燃脂效果出色，特别针对上肢、核心和心肺功能。支持双人对战模式。",
            keyPoints: [
                "出拳时从腰部发力，转体带动手臂，不要只用手臂力量",
                "保持拳击基本站姿：前脚朝前，后脚45度，双膝微屈，重心略低",
                "收拳要快，出拳后迅速回到防守位置，保持节奏感",
                "闪躲动作用腰腿发力，侧闪和下蹲都能有效训练核心和下肢",
                "保持呼吸节奏，出拳时呼气，收拳时吸气"
            ],
            trainingTips: [
                "初学者先从普通难度开始，熟悉直拳和勾拳的基本动作",
                "每次训练30-45分钟，选择Daily训练模式自动安排课程",
                "逐步解锁高难度组合拳，增加连击数量提升运动强度",
                "搭配腕部负重（0.5-1kg）可以显著增加训练效果"
            ],
            precautions: [
                "确保Joy-Con腕带系紧，防止出汗后手柄飞出",
                "周围留出足够空间，避免打到家具或他人",
                "手腕和肩膀有伤的人注意控制出拳力度",
                "训练前充分热身手腕、肩膀和腰部关节"
            ],
            suggestedPlan: """
            每周拳击训练计划：
            周一：30分钟 基础直拳+勾拳训练
            周三：40分钟 组合拳连击挑战
            周五：30分钟 闪躲+反击专项训练
            周末：双人对战模式，趣味燃脂
            进阶：每周增加5分钟训练时间，逐步提升难度等级
            """
        ),
    ]
}

// MARK: - Exercise List View

struct ExerciseListView: View {
    let bodyParts: [String]
    let chineseName: String

    @State private var exercises: [ExerciseDBExercise] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var freeDBExerciseIDs: Set<String> = []
    @State private var selectedEquipment: String? = nil

    private let limit = 20

    // Equipment English → Chinese
    private let equipmentNames: [String: String] = [
        "dumbbell": "哑铃",
        "barbell": "杠铃",
        "cable": "绳索",
        "machine": "固定器械",
        "leverage machine": "固定器械",
        "body weight": "徒手",
        "assisted": "辅助器械",
        "smith machine": "史密斯架",
        "kettlebell": "壶铃",
        "ez barbell": "曲杆",
        "trap bar": "六角杠",
        "band": "弹力带",
        "resistance band": "弹力带",
        "medicine ball": "药球",
        "stability ball": "瑞士球",
        "olympic barbell": "奥林匹克杠铃",
        "roller": "滚轴",
        "rope": "绳索",
    ]

    // Available equipment tags from loaded exercises (deduplicated)
    private var availableEquipments: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for exercise in exercises {
            for eq in exercise.equipments {
                let key = eq.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    result.append(eq)
                }
            }
        }
        return result.sorted()
    }

    private var filteredExercises: [ExerciseDBExercise] {
        guard let selected = selectedEquipment else { return exercises }
        return exercises.filter { exercise in
            exercise.equipments.contains { $0.lowercased() == selected.lowercased() }
        }
    }

    private func chineseName(for equipment: String) -> String {
        equipmentNames[equipment.lowercased()] ?? equipment
    }

    var body: some View {
        Group {
            if isLoading && exercises.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if exercises.isEmpty {
                ContentUnavailableView(
                    "暂无动作",
                    systemImage: "figure.walk",
                    description: Text("该分类下暂无训练动作")
                )
            } else {
                List {
                    // Equipment filter chips
                    if !availableEquipments.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // "全部" chip
                                    Button {
                                        selectedEquipment = nil
                                    } label: {
                                        Text("全部")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(selectedEquipment == nil ? .white : AppTheme.primaryGreen)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule().fill(selectedEquipment == nil ? AppTheme.primaryGreen : AppTheme.lightGreen)
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(availableEquipments, id: \.self) { eq in
                                        Button {
                                            selectedEquipment = eq
                                        } label: {
                                            Text(chineseName(for: eq))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(selectedEquipment?.lowercased() == eq.lowercased() ? .white : AppTheme.primaryGreen)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule().fill(
                                                        selectedEquipment?.lowercased() == eq.lowercased()
                                                            ? AppTheme.primaryGreen
                                                            : AppTheme.lightGreen
                                                    )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    if filteredExercises.isEmpty {
                        Text("该器材下暂无动作")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredExercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                exerciseRow(exercise: exercise)
                            }
                            .onAppear {
                                if exercise.id == exercises.last?.id && selectedEquipment == nil {
                                    loadMore()
                                }
                            }
                        }
                    }

                    if isLoading && !exercises.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(chineseName)
        .task {
            await loadExercises()
        }
    }

    private func exerciseRow(exercise: ExerciseDBExercise) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: exercise.gifUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name.capitalized)
                            .font(.headline)
                            .lineLimit(2)
                        Text(translateExerciseName(exercise.name))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(freeDBExerciseIDs.contains(exercise.id) ? "Free DB" : "ExerciseDB")
                        .font(.system(size: 9))
                        .foregroundStyle(.gray)
                }

                if !exercise.equipments.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(exercise.equipments, id: \.self) { equipment in
                            Text(equipment)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.primaryGreen)
                                .clipShape(Capsule())
                        }
                    }
                }

                if !exercise.targetMuscles.isEmpty {
                    Text(exercise.targetMuscles.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func translateExerciseName(_ name: String) -> String {
        let dict: [String: String] = [
            // ===== 胸部 =====
            "cable incline fly": "上斜绳索飞鸟",
            "cable incline fly (on stability ball)": "上斜绳索飞鸟(稳定球)",
            "lever chest press": "器械胸推",
            "cable standing up straight crossovers": "绳索站姿交叉夹胸",
            "assisted wide-grip chest dip": "辅助宽握胸部臂屈伸",
            "assisted wide-grip chest dip (kneeling)": "辅助宽握胸部臂屈伸(跪姿)",
            "chest dip on straight bar": "直杠胸部臂屈伸",
            "barbell front raise and pullover": "杠铃前举过顶",
            "barbell bench press": "杠铃卧推",
            "dumbbell bench press": "哑铃卧推",
            "dumbbell fly": "哑铃飞鸟",
            "dumbbell incline fly": "上斜哑铃飞鸟",
            "dumbbell decline fly": "下斜哑铃飞鸟",
            "incline dumbbell bench press": "上斜哑铃卧推",
            "incline barbell bench press": "上斜杠铃卧推",
            "decline barbell bench press": "下斜杠铃卧推",
            "decline dumbbell bench press": "下斜哑铃卧推",
            "push-up": "俯卧撑", "push up": "俯卧撑",
            "wide push-up": "宽距俯卧撑", "wide push up": "宽距俯卧撑",
            "diamond push-up": "钻石俯卧撑", "diamond push up": "钻石俯卧撑",
            "decline push-up": "下斜俯卧撑", "decline push up": "下斜俯卧撑",
            "incline push-up": "上斜俯卧撑", "incline push up": "上斜俯卧撑",
            "clock push-up": "时钟俯卧撑",
            "cable fly": "绳索飞鸟",
            "cable crossover": "绳索夹胸",
            "chest press machine": "器械胸推",
            "machine chest press": "器械胸推",
            "pec deck fly": "蝴蝶机夹胸",
            "dip": "臂屈伸",
            "chest dip": "胸部臂屈伸",
            "smith machine bench press": "史密斯卧推",
            "svend press": "斯文德推举",
            "floor press": "地板卧推",
            "chest push (multiple response)": "药球胸推(多次)",
            "chest push (single response)": "药球胸推(单次)",
            "chest push with run release": "药球胸推跑步释放",
            "chest stretch on stability ball": "稳定球胸部拉伸",
            "isometric chest squeeze": "等长胸部挤压",
            // ===== 背部 =====
            "pull-up": "引体向上", "pull up": "引体向上",
            "chin-up": "反握引体向上", "chin up": "反握引体向上",
            "wide grip pull-up": "宽握引体向上",
            "close grip pull-up": "窄握引体向上",
            "assisted pull-up": "辅助引体向上",
            "lat pulldown": "高位下拉",
            "wide grip lat pulldown": "宽握高位下拉",
            "close grip lat pulldown": "窄握高位下拉",
            "reverse grip lat pulldown": "反握高位下拉",
            "straight arm pulldown": "直臂下拉",
            "barbell row": "杠铃划船",
            "barbell bent over row": "杠铃俯身划船",
            "pendlay row": "彭德雷划船",
            "dumbbell row": "哑铃划船",
            "one arm dumbbell row": "单臂哑铃划船",
            "dumbbell bent over row": "哑铃俯身划船",
            "seated cable row": "坐姿绳索划船",
            "cable row": "绳索划船",
            "single arm cable row": "单臂绳索划船",
            "t-bar row": "T杠划船", "t bar row": "T杠划船",
            "deadlift": "硬拉",
            "barbell deadlift": "杠铃硬拉",
            "conventional deadlift": "传统硬拉",
            "trap bar deadlift": "六角杠硬拉",
            "face pull": "面拉",
            "cable face pull": "绳索面拉",
            "hyperextension": "山羊挺身",
            "back extension": "背部伸展",
            "reverse hyperextension": "反向山羊挺身",
            "lever seated row": "器械坐姿划船",
            "lever high row": "器械高位划船",
            "lever t-bar row": "器械T杠划船",
            "inverted row": "反向划船",
            "meadows row": "梅多斯划船",
            "seal row": "海豹划船",
            "good morning": "早安式体前屈",
            "superman": "超人式",
            // ===== 肩部 =====
            "overhead press": "过头推举",
            "barbell overhead press": "杠铃推举",
            "military press": "军事推举",
            "dumbbell shoulder press": "哑铃肩推",
            "seated dumbbell shoulder press": "坐姿哑铃肩推",
            "dumbbell lateral raise": "哑铃侧平举",
            "lateral raise": "侧平举",
            "front raise": "前平举",
            "dumbbell front raise": "哑铃前平举",
            "barbell front raise": "杠铃前平举",
            "plate front raise": "杠片前平举",
            "rear delt fly": "反向飞鸟",
            "reverse fly": "反向飞鸟",
            "rear delt raise": "后三角肌飞鸟",
            "bent over rear delt raise": "俯身反向飞鸟",
            "cable rear delt fly": "绳索反向飞鸟",
            "arnold press": "阿诺德推举",
            "upright row": "直立划船",
            "barbell upright row": "杠铃直立划船",
            "dumbbell upright row": "哑铃直立划船",
            "cable lateral raise": "绳索侧平举",
            "cable front raise": "绳索前平举",
            "shrug": "耸肩",
            "dumbbell shrug": "哑铃耸肩",
            "barbell shrug": "杠铃耸肩",
            "smith machine overhead press": "史密斯推举",
            "machine shoulder press": "器械肩推",
            "landmine press": "地雷管推举",
            "cuban rotation": "古巴旋转",
            "band pull apart": "弹力带拉伸",
            "external rotation": "外旋",
            "internal rotation": "内旋",
            "lu raise": "吕小军侧平举",
            // ===== 腿部 =====
            "squat": "深蹲",
            "barbell squat": "杠铃深蹲",
            "back squat": "后蹲",
            "front squat": "前蹲",
            "goblet squat": "高脚杯深蹲",
            "overhead squat": "过头深蹲",
            "zercher squat": "泽尔彻深蹲",
            "pistol squat": "单腿深蹲",
            "box squat": "箱式深蹲",
            "jump squat": "跳跃深蹲",
            "smith machine squat": "史密斯深蹲",
            "leg press": "腿举",
            "single leg press": "单腿腿举",
            "leg extension": "腿屈伸",
            "leg curl": "腿弯举",
            "lying leg curl": "俯卧腿弯举",
            "seated leg curl": "坐姿腿弯举",
            "standing leg curl": "站姿腿弯举",
            "nordic hamstring curl": "北欧腿弯举",
            "lunge": "弓步",
            "dumbbell lunge": "哑铃弓步",
            "barbell lunge": "杠铃弓步",
            "walking lunge": "行走弓步",
            "reverse lunge": "后弓步",
            "lateral lunge": "侧弓步",
            "curtsy lunge": "交叉弓步",
            "bulgarian split squat": "保加利亚分腿蹲",
            "split squat": "分腿蹲",
            "romanian deadlift": "罗马尼亚硬拉",
            "single leg romanian deadlift": "单腿罗马尼亚硬拉",
            "stiff leg deadlift": "直腿硬拉",
            "hip thrust": "臀推",
            "barbell hip thrust": "杠铃臀推",
            "single leg hip thrust": "单腿臀推",
            "calf raise": "提踵",
            "standing calf raise": "站姿提踵",
            "seated calf raise": "坐姿提踵",
            "donkey calf raise": "驴式提踵",
            "hack squat": "哈克深蹲",
            "sumo deadlift": "相扑硬拉",
            "sumo squat": "相扑深蹲",
            "step up": "上台阶",
            "dumbbell step up": "哑铃上台阶",
            "glute bridge": "臀桥",
            "single leg glute bridge": "单腿臀桥",
            "hip abduction": "髋外展",
            "hip adduction": "髋内收",
            "cable hip abduction": "绳索髋外展",
            "cable kickback": "绳索后踢",
            "glute kickback": "臀部后踢",
            "wall sit": "靠墙深蹲",
            "sissy squat": "西西深蹲",
            "pendulum squat": "钟摆深蹲",
            // ===== 手臂 =====
            "bicep curl": "二头弯举",
            "barbell curl": "杠铃弯举",
            "ez bar curl": "曲杆弯举",
            "dumbbell curl": "哑铃弯举",
            "dumbbell bicep curl": "哑铃二头弯举",
            "alternate dumbbell curl": "交替哑铃弯举",
            "hammer curl": "锤式弯举",
            "dumbbell hammer curl": "哑铃锤式弯举",
            "cross body hammer curl": "交叉锤式弯举",
            "preacher curl": "牧师凳弯举",
            "dumbbell preacher curl": "哑铃牧师凳弯举",
            "concentration curl": "集中弯举",
            "dumbbell concentration curl": "哑铃集中弯举",
            "cable curl": "绳索弯举",
            "incline dumbbell curl": "上斜哑铃弯举",
            "spider curl": "蜘蛛弯举",
            "reverse curl": "反握弯举",
            "zottman curl": "佐特曼弯举",
            "bayesian curl": "贝叶斯弯举",
            "drag curl": "拖拽弯举",
            "tricep pushdown": "三头下压",
            "tricep extension": "三头臂屈伸",
            "cable tricep pushdown": "绳索三头下压",
            "rope tricep pushdown": "绳索三头下压",
            "overhead tricep extension": "过顶三头臂屈伸",
            "dumbbell overhead tricep extension": "哑铃过顶三头臂屈伸",
            "cable overhead tricep extension": "绳索过顶三头臂屈伸",
            "skull crusher": "碎颅者",
            "lying tricep extension": "仰卧三头臂屈伸",
            "ez bar skull crusher": "曲杆碎颅者",
            "close grip bench press": "窄握卧推",
            "dumbbell kickback": "哑铃后踢",
            "tricep kickback": "三头后踢",
            "tricep dip": "三头臂屈伸",
            "bench dip": "凳上臂屈伸",
            "wrist curl": "腕弯举",
            "reverse wrist curl": "反握腕弯举",
            "wrist roller": "腕力器",
            "farmer walk": "农夫行走",
            "farmer's walk": "农夫行走",
            // ===== 核心 =====
            "crunch": "卷腹",
            "cable crunch": "绳索卷腹",
            "reverse crunch": "反向卷腹",
            "decline crunch": "下斜卷腹",
            "oblique crunch": "侧卷腹",
            "sit-up": "仰卧起坐", "sit up": "仰卧起坐",
            "plank": "平板支撑",
            "side plank": "侧平板支撑",
            "plank to push-up": "平板支撑转俯卧撑",
            "russian twist": "俄罗斯转体",
            "leg raise": "举腿",
            "hanging leg raise": "悬垂举腿",
            "lying leg raise": "仰卧举腿",
            "captain's chair leg raise": "罗马椅举腿",
            "bicycle crunch": "自行车卷腹",
            "mountain climber": "登山者",
            "mountain climbers": "登山者",
            "ab roller": "健腹轮",
            "ab wheel rollout": "健腹轮",
            "wood chop": "伐木",
            "cable wood chop": "绳索伐木",
            "dead bug": "死虫",
            "bird dog": "鸟狗式",
            "v-up": "V字起坐", "v up": "V字起坐",
            "flutter kick": "交替踢腿",
            "scissor kick": "剪刀腿",
            "hollow hold": "空心支撑",
            "pallof press": "帕洛夫推",
            "dragon flag": "龙旗",
            "l-sit": "L形支撑", "l sit": "L形支撑",
            "toe touch": "触脚卷腹",
            "windshield wiper": "雨刷器",
            "ab crunch machine": "卷腹器械",
            // ===== 通用关键词 =====
            "bench press": "卧推",
            "fly": "飞鸟",
            "press": "推举",
            "row": "划船",
            "curl": "弯举",
            "raise": "举/平举",
            "extension": "伸展",
            "pulldown": "下拉",
            "pullover": "过顶",
            "stretch": "拉伸",
            "rotation": "旋转",
            "twist": "转体",
            "kick": "踢",
            "bridge": "桥式",
            "thrust": "臀推",
            "squeeze": "挤压",
        ]

        let lower = name.lowercased()
        // 精确匹配
        if let match = dict[lower] { return match }
        // 模糊匹配：找包含关键词最长的
        var best: (key: String, value: String)? = nil
        for (key, value) in dict {
            if lower.contains(key) {
                if best == nil || key.count > best!.key.count {
                    best = (key, value)
                }
            }
        }
        return best?.value ?? name.capitalized
    }

    private func loadExercises() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        async let exerciseDBTask: [ExerciseDBExercise] = {
            var results: [ExerciseDBExercise] = []
            for bodyPart in bodyParts {
                do {
                    let fetched = try await ExerciseDBService.shared.fetchExercisesByBodyPart(
                        bodyPart, offset: 0, limit: limit
                    )
                    results.append(contentsOf: fetched)
                } catch {
                    // Continue with other body parts
                }
            }
            return results
        }()

        async let freeDBTask: [ExerciseDBExercise] = {
            var results: [ExerciseDBExercise] = []
            for bodyPart in bodyParts {
                let fetched = await FreeExerciseDBService.shared.fetchExercisesByBodyPart(bodyPart)
                results.append(contentsOf: fetched)
            }
            return results
        }()

        let (exerciseDBResults, freeDBResults) = await (exerciseDBTask, freeDBTask)

        if exerciseDBResults.isEmpty && freeDBResults.isEmpty {
            errorMessage = "无法从任何数据源加载训练动作"
        } else {
            freeDBExerciseIDs = Set(freeDBResults.map { $0.id })
            exercises = exerciseDBResults + freeDBResults
            offset = limit
            hasMore = exerciseDBResults.count >= limit
        }

        isLoading = false
    }

    private func loadMore() {
        guard !isLoading, hasMore else { return }

        Task {
            isLoading = true

            do {
                var allResults: [ExerciseDBExercise] = []
                for bodyPart in bodyParts {
                    let results = try await ExerciseDBService.shared.fetchExercisesByBodyPart(
                        bodyPart, offset: offset, limit: limit
                    )
                    allResults.append(contentsOf: results)
                }

                exercises.append(contentsOf: allResults)
                offset += limit
                hasMore = !allResults.isEmpty
            } catch {
                // Silently fail on pagination errors
            }

            isLoading = false
        }
    }
}

#Preview {
    TrainingView()
}
