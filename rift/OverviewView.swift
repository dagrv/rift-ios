import SwiftUI
import SwiftData
import Charts
import MapKit

struct DailySpend: Identifiable {
    let id = UUID()
    let day: String
    let date: Date
    let amount: Double
    let isExpense: Bool
}

struct OverviewView: View {
    @State private var showPreferences = false
    @State private var showCalculator = false
    @State private var searchText = ""
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var totalIncome: Double {
        transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { totalIncome - totalExpenses }

    private var recentTransactions: [Transaction] { Array(transactions.prefix(5)) }

    private var searchResults: [Transaction] {
        guard !searchText.isEmpty else { return [] }
        return transactions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var last7DaysSpend: [DailySpend] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [DailySpend] = []
        for offset in (0..<7).reversed() {
            let date  = calendar.date(byAdding: .day, value: -offset, to: today)!
            let label = offset == 0 ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))
            let exp = transactions
                .filter { $0.isExpense && calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            let inc = transactions
                .filter { !$0.isExpense && calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            result.append(DailySpend(day: label, date: date, amount: exp, isExpense: true))
            result.append(DailySpend(day: label, date: date, amount: inc, isExpense: false))
        }
        return result
    }

    private var isSearching: Bool { !searchText.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchBar

                    if isSearching {
                        searchResultsSection
                    } else {
                        balanceCard
                        summaryCards
                        spendingChart
                        recentSection
                    }
                }
                .padding()
            }
            .navigationTitle("Overview")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showPreferences = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCalculator = true } label: {
                        Image(systemName: "plusminus.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isPrivateMode.toggle()
                        }
                    } label: {
                        Image(systemName: isPrivateMode ? "eye.fill" : "eye.slash.fill")
                    }
                }
            }
            .sheet(isPresented: $showPreferences) {
                PreferencesView()
            }
            .navigationDestination(isPresented: $showCalculator) {
                CalculatorView()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15, weight: .medium))
            TextField("Search transactions…", text: $searchText)
                .font(.subheadline)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(searchResults.isEmpty ? "No results" : "\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                .font(.headline)
                .padding(.horizontal, 4)

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != searchResults.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }

    // MARK: - Balance & Summary

    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(isPrivateMode ? "****" : netBalance.currencyFormatted(for: currencyCode))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(isPrivateMode ? Color.primary : (netBalance >= 0 ? Color.primary : Color.red))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.7), value: netBalance)
                .animation(.spring(duration: 0.35), value: isPrivateMode)
            Text("All time")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            TimelineView(.animation) { context in
                let angle = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 4) / 4 * 360
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center,
                            startAngle: .degrees(angle),
                            endAngle: .degrees(angle + 360)
                        ),
                        lineWidth: 4
                    )
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(title: "Income", amount: totalIncome, color: .green, icon: "arrow.down.square.fill")
            SummaryCard(title: "Expenses", amount: totalExpenses, color: .red, icon: "arrow.up.square.fill")
        }
    }

    // MARK: - Chart

    private var spendingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 12) {
                if last7DaysSpend.allSatisfy({ $0.amount == 0 }) {
                    Text("No data yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    Chart(last7DaysSpend) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(item.isExpense ? Color.red.opacity(0.80) : Color.green.opacity(0.80))
                        .cornerRadius(5)
                        .position(by: .value("Type", item.isExpense ? "Expense" : "Income"))
                    }
                    .transaction { $0.animation = nil }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount == 0 ? "" : "$\(Int(amount))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            .blur(radius: isPrivateMode ? 24 : 0)
            .overlay {
                if isPrivateMode {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thickMaterial)
                        VStack(spacing: 8) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("Hidden in Private Mode")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPrivateMode)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)
                .padding(.horizontal, 4)

            if recentTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "tray",
                    description: Text("Add your first transaction in the New tab.")
                )
                .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != recentTransactions.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Subviews

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(LocalizedStringKey(title)).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(isPrivateMode ? "****" : amount.currencyFormatted(for: currencyCode))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: isPrivateMode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(CategoryData.color(for: transaction.category).opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: CategoryData.icon(for: transaction.category))
                            .foregroundStyle(CategoryData.color(for: transaction.category))
                            .font(.system(size: 16))
                    }
                    if transaction.imageData != nil {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.accentColor, in: Circle())
                            .offset(x: 3, y: 3)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.title).font(.subheadline).fontWeight(.medium)
                    Text(LocalizedStringKey(transaction.category)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isPrivateMode ? "****" : "\(transaction.isExpense ? "-" : "+")\(transaction.amount.currencyFormatted(for: currencyCode))")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isPrivateMode ? Color.primary : (transaction.isExpense ? Color.red : Color.green))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.35), value: isPrivateMode)
                    Text(transaction.date, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            TransactionDetailSheet(transaction: transaction)
        }
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var categoryColor: Color { CategoryData.color(for: transaction.category) }
    private var typeColor: Color { transaction.isExpense ? Color.red : Color.green }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Hero
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(categoryColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: CategoryData.icon(for: transaction.category))
                                .foregroundStyle(categoryColor)
                                .font(.system(size: 34, weight: .medium))
                        }
                        .padding(.top, 4)

                        Text(isPrivateMode ? "****" : "\(transaction.isExpense ? "-" : "+")\(transaction.amount.currencyFormatted(for: currencyCode))")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(typeColor)

                        Text(transaction.title)
                            .font(.title3).fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        Label(
                            transaction.isExpense ? "Expense" : "Income",
                            systemImage: transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                        )
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(typeColor)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(typeColor.opacity(0.12), in: Capsule())
                    }
                    .frame(maxWidth: .infinity)

                    // MARK: Detail rows
                    VStack(spacing: 0) {
                        detailRow(icon: CategoryData.icon(for: transaction.category),
                                  color: categoryColor, label: "Category",
                                  value: transaction.category)
                        Divider().padding(.leading, 56)
                        detailRow(icon: "calendar", color: .accentColor, label: "Date",
                                  value: transaction.date.formatted(.dateTime.month(.wide).day().year()))
                        Divider().padding(.leading, 56)
                        detailRow(icon: "clock.fill", color: .accentColor, label: "Time",
                                  value: transaction.date.formatted(.dateTime.hour().minute()))
                        if !transaction.note.isEmpty {
                            Divider().padding(.leading, 56)
                            detailRow(icon: "text.alignleft", color: .accentColor,
                                      label: "Note", value: transaction.note)
                        }
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // MARK: Tags
                    if !transaction.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Tags", systemImage: "tag.fill")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(transaction.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.subheadline).fontWeight(.medium)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Location
                    if transaction.hasLocation {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Location", systemImage: "mappin.circle.fill")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            let coord = CLLocationCoordinate2D(
                                latitude: transaction.locationLatitude,
                                longitude: transaction.locationLongitude
                            )
                            Map(position: .constant(.region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                            )))) {
                                Marker(transaction.locationName, coordinate: coord)
                                    .tint(.red)
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .disabled(true)
                            .allowsHitTesting(false)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.locationName)
                                    .font(.subheadline).fontWeight(.medium)
                                if !transaction.locationAddress.isEmpty {
                                    Text(transaction.locationAddress)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    // MARK: Receipt photo
                    if let data = transaction.imageData,
                       let uiImage = UIImage(data: data) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Receipt", systemImage: "photo.fill")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 15, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(value))
                    .font(.subheadline).fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    OverviewView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
