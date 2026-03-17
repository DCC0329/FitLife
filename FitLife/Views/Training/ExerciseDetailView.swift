import SwiftUI

struct ExerciseDetailView: View {
    let exercise: ExerciseDBExercise

    @State private var translatedInstructions: [String]? = nil
    @State private var isTranslating = false
    private let accentColor = Color(hex: "43C776")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image + Tags combined
                HStack(alignment: .top, spacing: 12) {
                    gifSection
                        .frame(width: 140)

                    tagsSection
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                instructionsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.name.capitalized)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // 加载缓存的翻译
            let cacheKey = "instr_\(exercise.id)"
            if let cached = UserDefaults.standard.stringArray(forKey: cacheKey) {
                translatedInstructions = cached
            }
        }
    }

    // MARK: - GIF Section

    private var gifSection: some View {
        AsyncImage(url: URL(string: exercise.gifUrl), scale: 1.0) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("无法加载动画")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .empty:
                ProgressView()
            @unknown default:
                Color.clear
            }
        }
        .frame(height: 140)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !exercise.targetMuscles.isEmpty {
                tagRow(title: "目标肌群", items: exercise.targetMuscles, color: Color(hex: "3B82F6"))
            }

            if !exercise.secondaryMuscles.isEmpty {
                tagRow(title: "辅助肌群", items: exercise.secondaryMuscles, color: Color(hex: "8B5CF6"))
            }

            if !exercise.equipments.isEmpty {
                tagRow(title: "使用器械", items: exercise.equipments, color: Color(hex: "F59E0B"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagRow(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(Self.translateToChinese(item))
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("动作步骤")
                Spacer()
                if !exercise.instructions.isEmpty {
                    if isTranslating {
                        ProgressView()
                            .controlSize(.small)
                    } else if translatedInstructions == nil {
                        Button {
                            translateInstructions()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "character.book.closed.fill.zh")
                                    .font(.system(size: 11))
                                Text("翻译")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accentColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("已翻译")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            if exercise.instructions.isEmpty {
                Text("暂无动作说明")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                // English original
                                Text(Self.cleanStepPrefix(step))
                                    .font(.callout)
                                    .lineSpacing(2)

                                // Chinese translation below
                                if let translated = translatedInstructions,
                                   index < translated.count {
                                    Text(translated[index])
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Translate Instructions

    private func translateInstructions() {
        guard !exercise.instructions.isEmpty else { return }

        // 检查缓存
        let cacheKey = "instr_\(exercise.id)"
        if let cached = UserDefaults.standard.stringArray(forKey: cacheKey) {
            translatedInstructions = cached
            return
        }

        guard let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key"), !apiKey.isEmpty else { return }

        isTranslating = true
        let steps = exercise.instructions.enumerated().map { "\($0.offset + 1). \(Self.cleanStepPrefix($0.element))" }.joined(separator: "\n")
        let prompt = "将以下健身动作步骤翻译成中文，保持序号格式，每行一条，只返回翻译：\n\(steps)"

        Task {
            do {
                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
                guard let url = URL(string: urlString) else {
                    isTranslating = false
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
                    let lines = text.components(separatedBy: "\n")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .map { line in
                            // 去掉序号前缀
                            var cleaned = line
                            if let range = cleaned.range(of: #"^\d+[\s.:、\-]*"#, options: .regularExpression) {
                                cleaned = String(cleaned[range.upperBound...])
                            }
                            return cleaned
                        }
                    if !lines.isEmpty {
                        translatedInstructions = lines
                        // 永久缓存
                        UserDefaults.standard.set(lines, forKey: cacheKey)
                    }
                }
            } catch {
                // Silently fail
            }
            isTranslating = false
        }
    }

    // MARK: - Helpers

    private static let chineseTranslations: [String: String] = [
        // Body parts
        "chest": "胸部",
        "back": "背部",
        "shoulders": "肩部",
        "upper legs": "大腿",
        "lower legs": "小腿",
        "upper arms": "上臂",
        "lower arms": "前臂",
        "waist": "腰腹",
        "cardio": "有氧",
        "neck": "颈部",
        // Muscles
        "glutes": "臀肌",
        "quads": "股四头肌",
        "hamstrings": "腘绳肌",
        "calves": "小腿肌",
        "biceps": "肱二头肌",
        "triceps": "肱三头肌",
        "delts": "三角肌",
        "lats": "背阔肌",
        "traps": "斜方肌",
        "pectorals": "胸肌",
        "abs": "腹肌",
        "forearms": "前臂肌",
        "serratus anterior": "前锯肌",
        "spine": "脊柱",
        "adductors": "内收肌",
        "abductors": "外展肌",
        "levator scapulae": "肩胛提肌",
        "deltoids": "三角肌",
        "anterior deltoids": "前三角肌",
        "posterior deltoids": "后三角肌",
        "lateral deltoids": "侧三角肌",
        // Equipment
        "barbell": "杠铃",
        "dumbbell": "哑铃",
        "cable": "绳索",
        "body weight": "自重",
        "band": "弹力带",
        "leverage machine": "固定器械",
        "smith machine": "史密斯机",
        "kettlebell": "壶铃",
        "ez barbell": "曲杆杠铃",
        "olympic barbell": "奥林匹克杠铃",
        "medicine ball": "药球",
        "stability ball": "瑞士球",
        "rope": "绳索",
        "roller": "滚轮",
        "weighted": "负重",
        "assisted": "辅助",
        "resistance band": "弹力带",
        "tire": "轮胎",
        "upper body ergometer": "上肢测功计",
        "elliptical machine": "椭圆机",
        "stationary bike": "固定自行车",
        "hammer": "锤式",
        "bosu ball": "波速球",
        "sled machine": "腿举机",
        "skierg machine": "滑雪机",
        "trap bar": "六角杠铃",
        "wheel roller": "健腹轮",
    ]

    /// Remove "Step:1 " or "Step 1: " prefixes from instructions since we already show numbered circles
    private static func cleanStepPrefix(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        // Match patterns like "Step:1 ", "Step:2 ", "Step 1: ", "Step 1. "
        if let range = cleaned.range(of: #"^[Ss]tep[\s:]*\d+[\s:.\-]*"#, options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }
        return cleaned
    }

    private static func translateToChinese(_ text: String) -> String {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
        return chineseTranslations[lowered] ?? text.capitalized
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4, height: 20)

            Text(title)
                .font(.title3)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            exercise: ExerciseDBExercise(
                exerciseId: "0001",
                name: "bench press",
                gifUrl: "https://example.com/bench.gif",
                targetMuscles: ["pectorals"],
                bodyParts: ["chest"],
                equipments: ["barbell"],
                secondaryMuscles: ["triceps", "anterior deltoids"],
                instructions: [
                    "Lie flat on a bench with your feet on the ground.",
                    "Grip the barbell slightly wider than shoulder width.",
                    "Lower the bar to your chest slowly.",
                    "Press the bar back up to the starting position.",
                ]
            )
        )
    }
}
