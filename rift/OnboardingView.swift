import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomePage { currentPage = 1 }
                    .tag(0)
                FeaturesPage { hasCompletedOnboarding = true }
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            backgroundGrid
            bottomFade
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer()
            appIcon
                .padding(.bottom, 48)
            Spacer()
            bottomContent
        }
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(Color(white: 0.11))
                .frame(width: 170, height: 170)
            Text("R")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(Color(white: 0.22))
        }
    }

    private var bottomContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text("Your Money,\nFinally Under Control")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("A personal finance tracker that actually\nmakes you want to open it.")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 36)

            OnboardingButton(title: "Get Started", action: onNext)
        }
        .padding(.bottom, 52)
    }

    private var backgroundGrid: some View {
        GeometryReader { geo in
            let tile: CGFloat = 88
            let cols = Int(geo.size.width / tile) + 2
            let rows = Int(geo.size.height / tile) + 2

            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.09))
                            .frame(width: tile - 6, height: tile - 6)
                            .offset(x: CGFloat(col) * tile - 3, y: CGFloat(row) * tile - 3)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Features Page

struct FeaturesPage: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                heroIcon
                    .padding(.bottom, 28)

                Text("Visualize spending,\nset budgets, hit your goals\n— all in one place.")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

                featureCards
                    .padding(.horizontal, 24)

                Spacer()

                privacyNote
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                OnboardingButton(title: "Continue", action: onContinue)
                    .padding(.bottom, 52)
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.13))
                .frame(width: 108, height: 108)
            Circle()
                .strokeBorder(Color(white: 0.2), lineWidth: 1)
                .frame(width: 108, height: 108)
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 46))
                .foregroundStyle(.white)
        }
    }

    private var featureCards: some View {
        VStack(spacing: 12) {
            FeatureCard(
                icon: "chart.bar.fill",
                title: "See Where Your Money Goes",
                description: "Beautiful charts and breakdowns to understand your spending at a glance."
            )
            FeatureCard(
                icon: "dollarsign.circle.fill",
                title: "Set Budgets That Stick",
                description: "Create smart budgets by category and watch your progress in real time."
            )
            FeatureCard(
                icon: "trophy.fill",
                title: "Hit Your Financial Goals",
                description: "Stay motivated, track every win, and build better money habits over time."
            )
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.orange)
                .font(.system(size: 13))

            Text("All your data stays on your iPhone. Rift never uploads or stores your financial information on external servers.")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Shared Components

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.18))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct OnboardingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView()
}
