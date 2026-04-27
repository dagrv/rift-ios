import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @AppStorage("appAppearance") private var appearance: String = "system"
    @AppStorage("accentColorName") private var accentColorName: String = "green"

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var accentColor: Color {
        AppAccentColor(rawValue: accentColorName)?.color ?? .green
    }

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                OverviewView().background(TabBarImageConfigurator())
            } label: {
                Label("Overview", systemImage: "house")
                    .environment(\.symbolVariants, .none)
            }
            Tab(value: 1) {
                PaymentsView().background(TabBarImageConfigurator())
            } label: {
                Label("Payments", systemImage: "creditcard")
                    .environment(\.symbolVariants, .none)
            }
            Tab(value: 2) {
                NewTransactionView().background(TabBarImageConfigurator())
            } label: {
                Label("New", systemImage: "plus.square")
                    .environment(\.symbolVariants, .none)
            }
            Tab(value: 3) {
                AnalyticsView().background(TabBarImageConfigurator())
            } label: {
                Label("Analytics", systemImage: "chart.bar")
                    .environment(\.symbolVariants, .none)
            }
            Tab(value: 4) {
                BudgetsView().background(TabBarImageConfigurator())
            } label: {
                Label("Budgets", systemImage: "dollarsign.circle")
                    .environment(\.symbolVariants, .none)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .switchToOverview)) { _ in
            selectedTab = 0
        }
    }
}

// MARK: - UIKit bridge: outline image + filled selectedImage on every tab bar item

private struct TabBarImageConfigurator: UIViewControllerRepresentable {

    static let pairs: [(outline: String, fill: String)] = [
        ("house",             "house.fill"),
        ("creditcard",        "creditcard.fill"),
        ("plus.square",       "plus.square.fill"),
        ("chart.bar",         "chart.bar.fill"),
        ("dollarsign.circle", "dollarsign.circle.fill"),
    ]

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ vc: Controller, context: Context) {
        vc.applyIcons()
    }

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyIcons()
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyIcons()
        }

        func applyIcons() {
            guard let tabBar = findTabBar() else { return }
            guard let items = tabBar.items else { return }
            for (i, pair) in TabBarImageConfigurator.pairs.enumerated() {
                guard i < items.count else { break }
                items[i].image         = UIImage(systemName: pair.outline)
                items[i].selectedImage = UIImage(systemName: pair.fill)
            }
        }

        /// Walks parent VCs first, then falls back to searching the key window.
        private func findTabBar() -> UITabBar? {
            // 1. Walk up the VC hierarchy
            var vc: UIViewController? = self
            while vc != nil {
                if let tbc = vc as? UITabBarController { return tbc.tabBar }
                if let tbc = vc?.tabBarController       { return tbc.tabBar }
                vc = vc?.parent
            }
            // 2. Fall back to scanning the key window
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows where window.isKeyWindow {
                    if let tb = TabBarImageConfigurator.search(in: window) { return tb }
                }
            }
            return nil
        }
    }

    static func search(in view: UIView) -> UITabBar? {
        if let tb = view as? UITabBar { return tb }
        for sub in view.subviews {
            if let tb = search(in: sub) { return tb }
        }
        return nil
    }
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
