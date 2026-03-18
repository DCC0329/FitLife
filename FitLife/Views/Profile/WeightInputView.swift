import SwiftUI
import SwiftData
import PhotosUI

struct WeightInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightRecord.date, order: .reverse) private var existingRecords: [WeightRecord]

    @State private var weight: Double = 65.0
    @State private var note: String = ""
    @State private var selectedDate: Date = .now
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showComparisonAlert = false
    @State private var weightDiff: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Large weight display - tappable to edit
                VStack(spacing: 8) {
                    Text("当前体重")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("65.00", value: $weight, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "43C776"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 200)
                        Text("kg")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                // Weight slider
                VStack(spacing: 8) {
                    Slider(value: $weight, in: 30...200, step: 0.1)
                        .tint(Color(hex: "43C776"))
                        .padding(.horizontal)

                    HStack {
                        Text("30 kg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("200 kg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Manual input + stepper
                HStack {
                    Text("手动输入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("体重", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(width: 80)
                    Text("kg")
                        .foregroundColor(.secondary)

                    Divider().frame(height: 28)

                    Button { weight = max(30, weight - 0.1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button { weight = min(200, weight + 0.1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)

                // Date picker
                DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    .padding(.horizontal)

                // Note field
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注（可选）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("例如：早餐前测量", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // Progress photo section
                VStack(alignment: .leading, spacing: 8) {
                    Text("进步照片（可选）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let selectedPhotoData,
                           let uiImage = UIImage(data: selectedPhotoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title3)
                                Text("选择照片")
                                    .font(.subheadline)
                            }
                            .foregroundColor(Color(hex: "43C776"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Save button
                Button {
                    saveRecord()
                } label: {
                    Text("保存")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "43C776"))
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert(comparisonTitle, isPresented: $showComparisonAlert) {
                Button(comparisonButtonLabel) { dismiss() }
            } message: {
                Text(comparisonMessage)
            }
            .onAppear {
                if let saved = UserDefaults.standard.object(forKey: "user_weight") as? Double, saved > 0 {
                    weight = saved
                }
            }
        }
    }

    private var comparisonTitle: String {
        if existingRecords.isEmpty { return "记录成功" }
        if weightDiff < 0 { return "恭喜！体重下降了" }
        if weightDiff > 0 { return "体重上升了" }
        return "体重没有变化"
    }

    private var comparisonMessage: String {
        guard !existingRecords.isEmpty else { return "这是你的第一次体重记录，继续加油" }
        let absVal = String(format: "%.2f", abs(weightDiff))
        if weightDiff < 0 { return "比上次轻了 \(absVal) kg，继续保持" }
        if weightDiff > 0 { return "比上次重了 \(absVal) kg，注意饮食和运动" }
        return "与上次记录相同，\(String(format: "%.2f", weight)) kg"
    }

    private var comparisonButtonLabel: String {
        if weightDiff < 0 { return "太棒了" }
        if weightDiff > 0 { return "知道了" }
        return "好的"
    }

    private func saveRecord() {
        // Compute diff before inserting (existingRecords still has old data)
        if let prev = existingRecords.first {
            weightDiff = weight - prev.weight
        }

        let record = WeightRecord(
            id: UUID(),
            weight: weight,
            date: selectedDate,
            note: note.isEmpty ? nil : note,
            photoData: selectedPhotoData
        )
        modelContext.insert(record)
        UserDefaults.standard.set(weight, forKey: "user_weight")

        if existingRecords.isEmpty {
            // First ever record: show alert then dismiss inside alert action
            weightDiff = 0
        }
        showComparisonAlert = true
    }
}

#Preview {
    WeightInputView()
}
