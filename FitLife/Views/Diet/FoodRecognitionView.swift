import SwiftUI
import PhotosUI
import SwiftData

struct FoodRecognitionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var displayImage: Image?

    @State private var isAnalyzing = false
    @State private var analysisResult: FoodAnalysis?
    @State private var errorMessage: String?

    @State private var selectedMealType: MealType = .lunch
    @State private var showCamera = false

    // Editable fields populated from AI result
    @State private var editFoodName: String = ""
    @State private var editCalories: Double = 0
    @State private var editProtein: Double = 0
    @State private var editCarbs: Double = 0
    @State private var editFat: Double = 0
    @State private var editFiber: Double = 0
    @State private var editWaterMl: Double = 0
    @State private var editSuggestions: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        photoPicker
                        cameraButton
                    }
                    imagePreview

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    if isAnalyzing {
                        loadingView
                    }

                    if analysisResult != nil {
                        editableResultCard
                        mealTypePicker
                        saveButton
                    } else if selectedImageData != nil && !isAnalyzing {
                        recognizeButton
                    }
                }
                .padding(AppTheme.padding)
            }
            .navigationTitle("食物识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryGreen)
                }
            }
            .background(AppTheme.background)
        }
    }

    // MARK: - Photo Picker

    private var photoPicker: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                Text("相册")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primaryGreen)
            .cornerRadius(AppTheme.cornerRadius)
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                analysisResult = nil
                errorMessage = nil
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    if let uiImage = UIImage(data: data) {
                        displayImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title3)
                Text("拍照")
                    .font(.headline)
            }
            .foregroundColor(AppTheme.primaryGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.lightGreen)
            .cornerRadius(AppTheme.cornerRadius)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(imageData: $selectedImageData)
                .onDisappear {
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        displayImage = Image(uiImage: uiImage)
                        analysisResult = nil
                        errorMessage = nil
                    }
                }
        }
    }

    // MARK: - Image Preview

    @ViewBuilder
    private var imagePreview: some View {
        if let displayImage {
            displayImage
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius, x: 0, y: AppTheme.shadowY)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.primaryGreen.opacity(0.5))
                Text("请选择一张食物照片")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(AppTheme.lightGreen.opacity(0.4))
            .cornerRadius(AppTheme.cornerRadius)
        }
    }

    // MARK: - Recognize Button

    private var recognizeButton: some View {
        Button {
            recognizeFood()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("识别食物")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primaryGreen)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryGreen))
                .scaleEffect(1.2)
            Text("正在分析食物...")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.primaryText)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(AppTheme.smallCornerRadius)
    }

    // MARK: - Editable Result Card

    private var editableResultCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("识别结果（可修改）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(AppTheme.primaryGreen)
            }

            Divider()

            // Food name
            HStack {
                Text("食物名称")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
                    .frame(width: 64, alignment: .leading)
                TextField("食物名称", text: $editFoodName)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.trailing)
            }

            Divider()

            // Nutrients
            editableNutrientRow(icon: "flame.fill", label: "热量", unit: "千卡", color: AppTheme.primaryGreen, value: $editCalories)
            editableNutrientRow(icon: "flame.fill", label: "蛋白质", unit: "g", color: .orange, value: $editProtein)
            editableNutrientRow(icon: "leaf.fill", label: "碳水", unit: "g", color: AppTheme.primaryGreen, value: $editCarbs)
            editableNutrientRow(icon: "drop.fill", label: "脂肪", unit: "g", color: .purple, value: $editFat)
            editableNutrientRow(icon: "circle.grid.cross.fill", label: "纤维", unit: "g", color: .brown, value: $editFiber)
            editableNutrientRow(icon: "drop.triangle.fill", label: "水分", unit: "ml", color: .blue, value: $editWaterMl)

            if !editSuggestions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("饮食建议")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primaryText)
                    Text(editSuggestions)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private func editableNutrientRow(icon: String, label: String, unit: String, color: Color, value: Binding<Double>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .font(.subheadline.weight(.semibold))
            Text(unit)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
                .frame(width: 24, alignment: .leading)
        }
    }

    // MARK: - Meal Type Picker

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择餐次")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.primaryText)

            HStack(spacing: 10) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Button {
                        selectedMealType = type
                    } label: {
                        Text(type.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(selectedMealType == type ? .white : AppTheme.primaryGreen)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedMealType == type
                                    ? AnyShapeStyle(AppTheme.primaryGreen)
                                    : AnyShapeStyle(AppTheme.lightGreen)
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveRecord()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                Text("保存")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primaryGreen)
            .cornerRadius(AppTheme.cornerRadius)
        }
    }

    // MARK: - Actions

    private func recognizeFood() {
        guard let imageData = selectedImageData else { return }

        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil

        Task {
            do {
                let result = try await AIServiceManager.shared.recognizeFood(imageData: imageData)
                await MainActor.run {
                    analysisResult = result
                    editFoodName = result.foodName
                    editCalories = result.calories
                    editProtein = result.protein
                    editCarbs = result.carbs
                    editFat = result.fat
                    editFiber = result.fiber
                    editWaterMl = result.waterMl
                    editSuggestions = result.suggestions
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    private func saveRecord() {
        let record = FoodRecord(
            mealType: selectedMealType,
            foodName: editFoodName.isEmpty ? "食物" : editFoodName,
            calories: editCalories,
            protein: editProtein,
            carbs: editCarbs,
            fat: editFat,
            fiber: editFiber,
            waterMl: editWaterMl,
            imageData: selectedImageData
        )

        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    FoodRecognitionView()
        .modelContainer(for: FoodRecord.self, inMemory: true)
}
