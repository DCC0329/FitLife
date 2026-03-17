import SwiftUI
import SwiftData
import PhotosUI

struct WeightInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 65.0
    @State private var note: String = ""
    @State private var selectedDate: Date = .now
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

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
                        TextField("65.0", value: $weight, format: .number)
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
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let saved = UserDefaults.standard.object(forKey: "user_weight") as? Double, saved > 0 {
                    weight = saved
                }
            }
        }
    }

    private func saveRecord() {
        let record = WeightRecord(
            id: UUID(),
            weight: weight,
            date: selectedDate,
            note: note.isEmpty ? nil : note,
            photoData: selectedPhotoData
        )
        modelContext.insert(record)

        // Also update current weight in UserDefaults
        UserDefaults.standard.set(weight, forKey: "user_weight")

        dismiss()
    }
}

#Preview {
    WeightInputView()
}
