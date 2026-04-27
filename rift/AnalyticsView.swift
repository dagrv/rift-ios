import SwiftUI
import SwiftData
import Charts

enum AnalyticsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"
}

enum AnalyticsTypeFilter: String, CaseIterable {
    case expenses = "Expenses"
    case income   = "Income"
    case both     = "Both"
}

struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
}

struct DailyTotal: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let isExpense: Bool
}

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var period: AnalyticsPeriod = .month
    @State private var typeFilter: AnalyticsTypeFilter = .expenses
    @State private var comparisonDate: Date = {
        let cal = Calendar.current
        let thisStart = cal.dateInterval(of: .month, for: Date())!.start
        return cal.date(byAdding: .month, value: -1, to: thisStart)!
    }()
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false

    private var periodStart: Date? {
        let now = Date()
        return switch period {
        case .week:  Calendar.current.date(byAdding: .day,   value: -7,  to: now)
        case .month: Calendar.current.date(byAdding: .month, value: -1,  to: now)
        case .year:  Calendar.current.date(byAdding: .year,  value: -1,  to: now)
        case .all:   nil
        }
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { t in
            let typeOK: Bool = switch typeFilter {
            case .expenses: t.isExpense
            case .income:  !t.isExpense
            case .both:     true
            }
            return typeOK && (periodStart == nil || t.date >= periodStart!)
        }
    }

    private var allPeriodTransactions: [Transaction] {
        transactions.filter { t in periodStart == nil || t.date >= periodStart! }
    }

    private var categoryTotals: [CategoryTotal] {
        let grouped = Dictionary(grouping: filteredTransactions, by: \.category)
        return grouped.map { key, value in
            CategoryTotal(category: key, total: value.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.total > $1.total }
    }

    private var totalAmount: Double {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Gauge data

    private var topCategoryShare: Double {
        guard totalAmount > 0, let top = categoryTotals.first else { return 0 }
        return min(top.total / totalAmount, 1.0)
    }

    private var topCategoryColor: Color {
        guard let top = categoryTotals.first else { return .accentColor }
        return CategoryData.color(for: top.category)
    }

    private var savingsRate: Double {
        let income   = allPeriodTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
        let expenses = allPeriodTransactions.filter {  $0.isExpense }.reduce(0) { $0 + $1.amount }
        guard income > 0 else { return 0 }
        return max(0, min((income - expenses) / income, 1.0))
    }

    private var savingsColor: Color {
        savingsRate >= 0.2 ? .green : savingsRate > 0 ? .orange : .red
    }

    // MARK: - Month comparison helpers

    private var thisMonthStart: Date {
        Calendar.current.dateInterval(of: .month, for: Date())!.start
    }
    private var comparisonMonthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: comparisonDate)!
    }
    private var availableComparisonMonths: [Date] {
        (1...12).compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: thisMonthStart) }
    }
    private func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, equalTo: b, toGranularity: .month)
    }
    private func typeMatchesFilter(_ t: Transaction) -> Bool {
        switch typeFilter {
        case .expenses: return t.isExpense
        case .income:   return !t.isExpense
        case .both:     return true
        }
    }
    private var thisMonthTotal: Double {
        transactions
            .filter { $0.date >= thisMonthStart && typeMatchesFilter($0) }
            .reduce(0) { $0 + $1.amount }
    }
    private var comparisonMonthTotal: Double {
        transactions
            .filter { $0.date >= comparisonDate && $0.date < comparisonMonthEnd && typeMatchesFilter($0) }
            .reduce(0) { $0 + $1.amount }
    }
    private var monthDelta: Double {
        guard comparisonMonthTotal > 0 else { return 0 }
        return (thisMonthTotal - comparisonMonthTotal) / comparisonMonthTotal
    }
    private var thisMonthName: String {
        thisMonthStart.formatted(.dateTime.month(.wide).year())
    }
    private var comparisonMonthName: String {
        comparisonDate.formatted(.dateTime.month(.wide).year())
    }
    private var amountColor: Color {
        switch typeFilter {
        case .expenses: return .red
        case .income:   return .green
        case .both:     return .primary
        }
    }
    private var deltaColor: Color {
        let isIncrease = monthDelta >= 0
        switch typeFilter {
        case .expenses: return isIncrease ? .red : .green
        case .income:   return isIncrease ? .green : .red
        case .both:     return isIncrease ? .green : .red
        }
    }
    private var monthMaxAmount: Double {
        max(thisMonthTotal, comparisonMonthTotal, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    controls
                    if filteredTransactions.isEmpty {
                        let emptyDescription: Text = {
                            switch typeFilter {
                            case .expenses: return Text("No expenses for this period.")
                            case .income:   return Text("No income for this period.")
                            case .both:     return Text("No transactions for this period.")
                            }
                        }()
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.bar",
                            description: emptyDescription
                        )
                        .padding(.top, 40)
                    } else {
                        totalCard
                        monthComparisonSection
                        gaugesSection
                        donutChart
                        categoryList
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            Picker("Type", selection: $typeFilter) {
                ForEach(AnalyticsTypeFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Total Card

    private var totalCard: some View {
        VStack(spacing: 4) {
            Text(typeFilter == .expenses ? "Total Spent" : typeFilter == .income ? "Total Earned" : "Combined")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(isPrivateMode ? "****" : totalAmount.currencyFormatted(for: currencyCode))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(isPrivateMode ? Color.secondary : (typeFilter == .expenses ? Color.red : typeFilter == .income ? Color.green : Color.primary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Gauges

    private var gaugesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                gaugeCard(
                    value: topCategoryShare,
                    color: topCategoryColor,
                    title: "Top Category",
                    subtitle: categoryTotals.first.map { $0.category } ?? "—"
                )
                gaugeCard(
                    value: savingsRate,
                    color: savingsColor,
                    title: "Savings Rate",
                    subtitle: savingsRate > 0 ? "On track" : "Over budget"
                )
            }
        }
    }

    private func gaugeCard(value: Double, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Gauge(value: value) {
                EmptyView()
            } currentValueLabel: {
                Text(isPrivateMode ? "**" : "\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            } minimumValueLabel: {
                Text("0").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("100").font(.caption2).foregroundStyle(.secondary)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [color, color, .white]))
            .scaleEffect(1.15)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(subtitle))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Donut Chart

    private var donutChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .padding(.horizontal, 4)

            InteractiveDonutChart(
                segments: categoryTotals,
                total: totalAmount,
                currencyCode: currencyCode,
                typeLabel: typeFilter == .expenses ? "Spent" : typeFilter == .income ? "Earned" : "Total",
                isPrivateMode: isPrivateMode
            )
            .id("\(period.rawValue)-\(typeFilter.rawValue)-\(categoryTotals.map { $0.category }.joined())")
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            .blur(radius: isPrivateMode ? 24 : 0)
            .overlay {
                if isPrivateMode {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.thickMaterial)
                        VStack(spacing: 8) {
                            Image(systemName: "eye.slash.fill")
                                .font(.title2).foregroundStyle(.secondary)
                            Text("Hidden in Private Mode")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPrivateMode)
        }
    }

    // MARK: - Category Breakdown

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(categoryTotals.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(CategoryData.color(for: item.category).opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: CategoryData.icon(for: item.category))
                                .foregroundStyle(CategoryData.color(for: item.category))
                                .font(.system(size: 16))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(item.category))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(CategoryData.color(for: item.category))
                                        .frame(width: geo.size.width * (totalAmount > 0 ? item.total / totalAmount : 0))
                                }
                            }
                            .frame(height: 8)
                            .blur(radius: isPrivateMode ? 8 : 0)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(isPrivateMode ? "****" : item.total.currencyFormatted(for: currencyCode))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if totalAmount > 0 && !isPrivateMode {
                                Text("\(Int(item.total / totalAmount * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    if index < categoryTotals.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    // MARK: - Month Comparison

    private var monthComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month Comparison")
                .font(.headline)
                .padding(.horizontal, 4)

            // Month picker chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableComparisonMonths, id: \.self) { month in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                comparisonDate = month
                            }
                        } label: {
                            Text(month.formatted(.dateTime.month(.abbreviated).year()))
                                .font(.caption)
                                .fontWeight(isSameMonth(comparisonDate, month) ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isSameMonth(comparisonDate, month)
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(.secondarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    isSameMonth(comparisonDate, month)
                                        ? Color.accentColor
                                        : Color.primary
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: isSameMonth(comparisonDate, month))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }

            VStack(spacing: 16) {
                // Amounts + delta chip
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(comparisonMonthName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(isPrivateMode ? "****" : comparisonMonthTotal.currencyFormatted(for: currencyCode))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: comparisonMonthTotal)
                    }
                    Spacer()
                    deltaChip
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(thisMonthName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(isPrivateMode ? "****" : thisMonthTotal.currencyFormatted(for: currencyCode))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(isPrivateMode ? Color.secondary : amountColor)
                    }
                }

                // Comparison bars
                VStack(spacing: 8) {
                    comparisonBar(
                        label: comparisonDate.formatted(.dateTime.month(.abbreviated)),
                        fraction: comparisonMonthTotal / monthMaxAmount,
                        color: Color.secondary.opacity(0.4)
                    )
                    comparisonBar(
                        label: thisMonthStart.formatted(.dateTime.month(.abbreviated)),
                        fraction: thisMonthTotal / monthMaxAmount,
                        color: amountColor.opacity(0.8)
                    )
                }
                .blur(radius: isPrivateMode ? 10 : 0)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    private func comparisonBar(label: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 4 : 0))
                }
            }
            .frame(height: 9)
        }
    }

    @ViewBuilder
    private var deltaChip: some View {
        if comparisonMonthTotal > 0 {
            let isIncrease = monthDelta >= 0
            VStack(spacing: 3) {
                Image(systemName: isIncrease ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text("\(abs(Int(monthDelta * 100)))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(deltaColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(deltaColor.opacity(0.12), in: Capsule())
        }
    }
}

// MARK: - Interactive Donut Chart

struct InteractiveDonutChart: View {
    let segments: [CategoryTotal]
    let total: Double
    let currencyCode: String
    let typeLabel: String   // e.g. "Spent", "Earned", "Total"
    var isPrivateMode: Bool = false

    @State private var selectedCategory: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // ── Chart ────────────────────────────────────────────────
                Chart(segments) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.54),
                        outerRadius: selectedCategory == item.category
                            ? .ratio(0.97) : .ratio(0.86),
                        angularInset: 2.5
                    )
                    .cornerRadius(6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                CategoryData.color(for: item.category).mix(with: .white, by: 0.25),
                                CategoryData.color(for: item.category),
                                CategoryData.color(for: item.category).mix(with: .black, by: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(
                        selectedCategory == nil || selectedCategory == item.category
                            ? 1.0 : 0.30
                    )
                }
                .chartLegend(.hidden)
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: selectedCategory)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(at: location, in: geo.size)
                            }
                    }
                }
                .frame(height: 260)

                // ── Center label ─────────────────────────────────────────
                centerLabel
                    .frame(width: 112)
                    .allowsHitTesting(false)
            }

            // ── Legend strip ─────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(segments) { item in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                selectedCategory = selectedCategory == item.category
                                    ? nil : item.category
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(CategoryData.color(for: item.category))
                                    .frame(width: 9, height: 9)
                                Text(LocalizedStringKey(item.category))
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == item.category
                                    ? CategoryData.color(for: item.category).opacity(0.14)
                                    : Color(.secondarySystemFill),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(
                            selectedCategory == nil || selectedCategory == item.category
                                ? 1 : 0.40
                        )
                        .animation(.spring(response: 0.3), value: selectedCategory)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Center label

    @ViewBuilder
    private var centerLabel: some View {
        ZStack {
            // Idle: total
            VStack(spacing: 5) {
                Text(typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(isPrivateMode ? "****" : total.currencyFormatted(for: currencyCode))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text("\(segments.count) cat.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .opacity(selectedCategory == nil ? 1 : 0)
            .scaleEffect(selectedCategory == nil ? 1 : 0.80)

            // Selected: detail
            if let cat = selectedCategory,
               let seg = segments.first(where: { $0.category == cat }) {
                VStack(spacing: 5) {
                    Image(systemName: CategoryData.icon(for: cat))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CategoryData.color(for: cat))
                    Text(isPrivateMode ? "****" : seg.total.currencyFormatted(for: currencyCode))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text("\(Int(seg.total / total * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale(scale: 0.80).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selectedCategory)
    }

    // MARK: - Tap handling

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center   = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx       = location.x - center.x
        let dy       = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerR   = min(size.width, size.height) / 2
        let innerR   = outerR * 0.54

        // Tap in center hole → deselect
        guard distance >= innerR * 0.85 else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedCategory = nil
            }
            return
        }

        // Tap outside chart area → ignore
        guard distance <= outerR * 1.05 else { return }

        // Convert position to clockwise angle from top (0°–360°)
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        angle = (angle + 90).truncatingRemainder(dividingBy: 360)

        // Map to category by cumulative total
        let target = (angle / 360) * total
        var cumulative = 0.0
        for item in segments {
            cumulative += item.total
            if target <= cumulative {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    selectedCategory = selectedCategory == item.category ? nil : item.category
                }
                return
            }
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedCategory = nil
        }
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
