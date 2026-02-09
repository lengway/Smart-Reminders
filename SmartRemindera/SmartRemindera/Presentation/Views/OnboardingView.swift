import SwiftUI

struct OnboardingView: View {
    @Binding var dailyGoal: Int
    let dismiss: () -> Void
    @State private var page = 0
    
    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardingPage(
                    title: "Умные напоминания",
                    subtitle: "Приложение адаптируется под твои привычки: время, геозоны, эскалации",
                    image: "brain.head.profile"
                ).tag(0)
                OnboardingPage(
                    title: "Разреши уведомления",
                    subtitle: "Так ты получишь вовремя подсказки и Live Activities",
                    image: "bell.badge.fill"
                ).tag(1)
                OnboardingGoalPage(dailyGoal: $dailyGoal).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < 2 ? "Далее" : "Начать")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let image: String
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: image)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

private struct OnboardingGoalPage: View {
    @Binding var dailyGoal: Int
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Дневная цель")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Сколько напоминаний ты хочешь закрывать ежедневно?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Stepper(value: $dailyGoal, in: 1...10) {
                Text("Цель: \(dailyGoal) в день")
            }
            .accessibilityLabel("Установить дневную цель")
            Spacer()
        }
        .padding()
    }
}
