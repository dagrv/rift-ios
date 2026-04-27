import SwiftUI
import SwiftData

@main
struct riftApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Transaction.self, Budget.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashDone = false

    var body: some View {
        ZStack {
            // Main content underneath
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }

            // Splash on top — fades away after the animation finishes
            if !splashDone {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Record the very first launch date
            if UserDefaults.standard.double(forKey: "memberSince") == 0 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "memberSince")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.45)) {
                    splashDone = true
                }
            }
        }
    }
}
