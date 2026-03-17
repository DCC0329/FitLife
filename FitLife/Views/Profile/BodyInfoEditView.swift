import SwiftUI

struct BodyInfoEditView: View {
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_age") private var userAge: Int = 25
    @AppStorage("user_gender") private var userGender: String = "男"
    @AppStorage("user_height") private var userHeight: Double = 170.0
    @AppStorage("user_weight") private var userWeight: Double = 65.0
    @AppStorage("goal_weight") private var goalWeight: Double = 60.0
    @AppStorage("start_weight") private var startWeight: Double = 0

    private let iconBlue = Color(hex: "5B8DEF")

    var body: some View {
        Form {
            Section("基本信息") {
                HStack {
                    Label("昵称", systemImage: "person.fill")
                        .foregroundColor(iconBlue)
                    Spacer()
                    TextField("请输入昵称", text: $userName)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Label("年龄", systemImage: "calendar")
                        .foregroundColor(iconBlue)
                    Spacer()
                    Stepper("\(userAge) 岁", value: $userAge, in: 1...120)
                }
                HStack {
                    Label("性别", systemImage: "figure.stand")
                        .foregroundColor(iconBlue)
                    Spacer()
                    Picker("", selection: $userGender) {
                        Text("男").tag("男")
                        Text("女").tag("女")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }

            Section("身体数据") {
                HStack {
                    Label("身高", systemImage: "ruler")
                        .foregroundColor(iconBlue)
                    Spacer()
                    TextField("身高", value: $userHeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("cm")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("体重", systemImage: "scalemass.fill")
                        .foregroundColor(iconBlue)
                    Spacer()
                    TextField("体重", value: $userWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("目标体重", systemImage: "target")
                        .foregroundColor(iconBlue)
                    Spacer()
                    TextField("目标", value: $goalWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
            }

            Section("减肥目标") {
                HStack {
                    Label("初始体重", systemImage: "flag.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    TextField("初始", value: $startWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg")
                        .foregroundColor(.secondary)
                }

                if startWeight > 0 && goalWeight > 0 {
                    let progress = startWeight > goalWeight ? min(max((startWeight - userWeight) / (startWeight - goalWeight), 0), 1.0) : 0
                    HStack {
                        Text("减肥进度")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.primaryGreen)
                    }

                    ProgressView(value: progress)
                        .tint(AppTheme.primaryGreen)

                    HStack {
                        Text("已减 \(String(format: "%.1f", startWeight - userWeight)) kg")
                            .font(.caption)
                            .foregroundColor(startWeight - userWeight > 0 ? AppTheme.primaryGreen : .red)
                        Spacer()
                        Text("还需减 \(String(format: "%.1f", max(userWeight - goalWeight, 0))) kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("身体信息")
        .navigationBarTitleDisplayMode(.inline)
    }
}
