import SwiftUI

// MARK: - Country Flag View

struct CountryFlag: View {
    let code: String
    var width: CGFloat = 44

    private var emoji: String {
        code.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar(127397 + $0.value)
        }.reduce("") { $0 + String($1) }
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: width))
            .frame(width: width * 1.4, height: width * 0.95)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.08)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

// MARK: - Data

private struct LanguageOption: Identifiable {
    let id: String
    let countryCode: String
    let name: String
}

private struct CurrencyOption: Identifiable {
    let id: String
    let countryCode: String
    let symbol: String
    let name: String
}

private let supportedLanguages: [LanguageOption] = [
    LanguageOption(id: "en", countryCode: "US", name: "English"),
    LanguageOption(id: "fr", countryCode: "FR", name: "Français"),
    LanguageOption(id: "de", countryCode: "DE", name: "Deutsch"),
    LanguageOption(id: "it", countryCode: "IT", name: "Italiano"),
]

private let supportedCurrencies: [CurrencyOption] = [
    CurrencyOption(id: "USD", countryCode: "US", symbol: "$", name: "US Dollar"),
    CurrencyOption(id: "EUR", countryCode: "EU", symbol: "€", name: "Euro"),
    CurrencyOption(id: "JPY", countryCode: "JP", symbol: "¥", name: "Japanese Yen"),
]

private let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]

// MARK: - Preferences View

struct PreferencesView: View {
    @AppStorage("appAppearance")          private var appearance:     String = "system"
    @AppStorage("accentColorName")        private var accentColorName: String = "green"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("currencyCode")           private var currencyCode:   String = "USD"
    @AppStorage("userName")               private var userName:       String = ""
    @AppStorage("userEmail")              private var userEmail:      String = ""
    @AppStorage("memberSince")            private var memberSince:    Double = 0
    @Environment(\.dismiss) private var dismiss

    private var selectedAccent: AppAccentColor {
        AppAccentColor(rawValue: accentColorName) ?? .green
    }

    private var currentLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private var initials: String {
        let parts = userName.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var memberSinceText: String {
        guard memberSince > 0 else { return "" }
        let date = Date(timeIntervalSince1970: memberSince)
        return "Member since " + date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Profile card
                Section {
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: rainbowColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 78, height: 78)
                            if initials.isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(.white)
                            } else {
                                Text(initials)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

                        VStack(spacing: 4) {
                            Text(userName.isEmpty ? "Your Name" : userName)
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(userName.isEmpty ? .secondary : .primary)
                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !memberSinceText.isEmpty {
                                Text(memberSinceText)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                // MARK: Editable profile fields
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("Name", text: $userName)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("Email", text: $userEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Light",  systemImage: "sun.max.fill").tag("light")
                        Label("Dark",   systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Accent Color") {
                    accentColorPicker
                }

                Section {
                    currencyPicker
                } header: {
                    Text("Currency")
                }

                Section {
                    languagePicker
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Change in iOS Settings", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Select a language in iOS Settings → Rift → Language.")
                }

                Section("About") {
                    LabeledContent("App", value: "Rift")
                    LabeledContent("Version", value: "1.0")
                }

                Section("Feedback") {
                    Button {
                        if let url = URL(string: "mailto:support@rift.app?subject=Rift%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                    Button {
                        if let url = URL(string: "mailto:support@rift.app?subject=Rift%20Bug%20Report") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Report a Bug", systemImage: "ant")
                            .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Accent Picker

    private var accentColorPicker: some View {
        HStack(spacing: 0) {
            ForEach(AppAccentColor.allCases, id: \.rawValue) { option in
                Button {
                    accentColorName = option.rawValue
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(option.color).frame(width: 38, height: 38)
                            if selectedAccent == option {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .frame(width: 38, height: 38)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(option.label)
                            .font(.caption2)
                            .foregroundStyle(selectedAccent == option ? option.color : .secondary)
                            .fontWeight(selectedAccent == option ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Currency Picker

    private var currencyPicker: some View {
        HStack(spacing: 0) {
            ForEach(supportedCurrencies) { currency in
                Button { currencyCode = currency.id } label: {
                    VStack(spacing: 6) {
                        CountryFlag(code: currency.countryCode, width: 36)
                        Text(currency.id)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(currencyCode == currency.id ? Color.primary : .secondary)
                        Text(currency.symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(currencyCode == currency.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Language Picker

    private var languagePicker: some View {
        HStack(spacing: 0) {
            ForEach(supportedLanguages) { lang in
                VStack(spacing: 6) {
                    CountryFlag(code: lang.countryCode, width: 36)
                    Text(lang.name)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(currentLanguageCode == lang.id ? Color.primary : .secondary)
                        .fontWeight(currentLanguageCode == lang.id ? .semibold : .regular)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(currentLanguageCode == lang.id ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PreferencesView()
}
