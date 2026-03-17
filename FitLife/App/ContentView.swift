import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    private let tabs: [(icon: String, selectedIcon: String)] = [
        ("house", "house.fill"),
        ("fork.knife", "fork.knife"),
        ("dumbbell", "dumbbell.fill"),
        ("chart.bar", "chart.bar.fill"),
        ("person", "person.fill")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case 0: HomeView()
                case 1: DietView()
                case 2: TrainingView()
                case 3: ReportView()
                case 4: ProfileView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 70)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = index
                        }
                    } label: {
                        ZStack {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.lavender.opacity(0.25))
                                    .frame(width: 48, height: 36)
                            }

                            Image(systemName: selectedTab == index ? tabs[index].selectedIcon : tabs[index].icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(selectedTab == index ? AppTheme.lavender : .gray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .background(
                Rectangle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
                    .ignoresSafeArea(.all, edges: .bottom)
            )
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    ContentView()
}
