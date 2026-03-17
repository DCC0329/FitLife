import SwiftUI
import SwiftData

struct MoodPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood: Mood? = nil
    @State private var showAllMoods = false

    private let primaryGreen = Color(hex: "43C776")

    var body: some View {
        VStack(spacing: 12) {
            // 主要心情（5个）
            HStack(spacing: 0) {
                ForEach(Array(Mood.primary.enumerated()), id: \.element.id) { index, mood in
                    moodButton(mood)
                    if index < Mood.primary.count - 1 {
                        Spacer()
                    }
                }
            }

            // "更多心情"按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAllMoods.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showAllMoods ? "收起" : "更多心情")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: showAllMoods ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // 展开的全部心情
            if showAllMoods {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                    ForEach(Mood.all, id: \.id) { mood in
                        if !Mood.primary.contains(mood) {
                            moodButton(mood)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task {
            loadTodayMood()
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMood = mood
            }
            saveMood(mood)
        } label: {
            VStack(spacing: 4) {
                Image(mood.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .padding(3)
                    .background(
                        Circle()
                            .fill(selectedMood == mood ? primaryGreen.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(selectedMood == mood ? primaryGreen : Color.clear, lineWidth: 2)
                    )
                    .scaleEffect(selectedMood == mood ? 1.1 : 1.0)

                Text(mood.label)
                    .font(.system(size: 10))
                    .foregroundColor(selectedMood == mood ? primaryGreen : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - SwiftData Operations

    private func saveMood(_ mood: Mood) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = #Predicate<MoodRecord> { record in
            record.date >= startOfDay
        }
        let descriptor = FetchDescriptor<MoodRecord>(predicate: predicate)

        if let existingRecords = try? modelContext.fetch(descriptor) {
            for record in existingRecords {
                modelContext.delete(record)
            }
        }

        let newRecord = MoodRecord(date: .now, mood: mood)
        modelContext.insert(newRecord)
        try? modelContext.save()
    }

    private func loadTodayMood() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = #Predicate<MoodRecord> { record in
            record.date >= startOfDay
        }
        let descriptor = FetchDescriptor<MoodRecord>(predicate: predicate)

        if let records = try? modelContext.fetch(descriptor),
           let latest = records.last {
            selectedMood = latest.mood
        }
    }
}

// MARK: - Compact Mood Picker (for side-by-side layout)

struct MoodPickerCompact: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood: Mood? = nil
    @State private var showAllMoods = false

    private var displayedMoods: [Mood] {
        guard let selected = selectedMood else { return Array(Mood.primary) }
        if Mood.primary.contains(selected) {
            return Mood.primary
        } else {
            var moods = [selected]
            moods.append(contentsOf: Mood.primary.prefix(4))
            return moods
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Primary 5 moods in a compact row
            HStack(spacing: 4) {
                ForEach(displayedMoods, id: \.id) { mood in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMood = mood
                        }
                        saveMood(mood)
                    } label: {
                        Image(mood.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .padding(2)
                            .background(
                                Circle()
                                    .fill(selectedMood == mood ? AppTheme.primaryGreen.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(selectedMood == mood ? AppTheme.primaryGreen : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Show selected mood label
            if let mood = selectedMood {
                Text(mood.label)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.primaryGreen)
            }

            // More button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAllMoods.toggle()
                }
            } label: {
                Text(showAllMoods ? "收起" : "更多")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if showAllMoods {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 6) {
                    ForEach(Mood.all.filter { !Mood.primary.contains($0) }, id: \.id) { mood in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMood = mood
                            }
                            saveMood(mood)
                        } label: {
                            VStack(spacing: 2) {
                                Image(mood.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)
                                Text(mood.label)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .padding(2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedMood == mood ? AppTheme.primaryGreen.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task { loadTodayMood() }
    }

    private func saveMood(_ mood: Mood) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<MoodRecord> { $0.date >= startOfDay }
        if let existing = try? modelContext.fetch(FetchDescriptor<MoodRecord>(predicate: predicate)) {
            existing.forEach { modelContext.delete($0) }
        }
        modelContext.insert(MoodRecord(date: .now, mood: mood))
        try? modelContext.save()
    }

    private func loadTodayMood() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<MoodRecord> { $0.date >= startOfDay }
        if let records = try? modelContext.fetch(FetchDescriptor<MoodRecord>(predicate: predicate)),
           let latest = records.last {
            selectedMood = latest.mood
        }
    }
}

#Preview {
    MoodPickerView()
        .padding()
        .modelContainer(for: MoodRecord.self, inMemory: true)
}
