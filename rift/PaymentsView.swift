import SwiftUI
import SwiftData
import UIKit

enum TransactionFilter: String, CaseIterable {
    case all      = "All"
    case expenses = "Expenses"
    case income   = "Income"
}

struct PaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var showCalendar  = false
    @State private var showExportDialog = false

    private var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            let matchesFilter: Bool = switch filter {
            case .all:      true
            case .expenses: transaction.isExpense
            case .income:  !transaction.isExpense
            }
            let matchesSearch = searchText.isEmpty ||
                transaction.title.localizedCaseInsensitiveContains(searchText) ||
                transaction.category.localizedCaseInsensitiveContains(searchText) ||
                transaction.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesFilter && matchesSearch
        }
    }

    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { t in
            t.date.formatted(.dateTime.month(.wide).year())
        }
        return grouped.sorted { a, b in
            let dA = filteredTransactions.first { $0.date.formatted(.dateTime.month(.wide).year()) == a.key }?.date ?? .distantPast
            let dB = filteredTransactions.first { $0.date.formatted(.dateTime.month(.wide).year()) == b.key }?.date ?? .distantPast
            return dA > dB
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "creditcard",
                        description: Text("Your transactions will appear here.")
                    )
                } else {
                    List {
                        filterPicker
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())

                        ForEach(groupedTransactions, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.value) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .listRowInsets(EdgeInsets())
                                }
                                .onDelete { indexSet in
                                    delete(from: group.value, at: indexSet)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Payments")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCalendar = true } label: {
                        DynamicCalendarIcon()
                            .offset(y: 1)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showExportDialog = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .offset(y: -1)
                    }
                    .disabled(filteredTransactions.isEmpty)
                }
            }
            .confirmationDialog("Export Payments", isPresented: $showExportDialog, titleVisibility: .visible) {
                Button("Export as CSV")  { shareCSV() }
                Button("Export as PDF")  { sharePDF() }
                Button("Export as Image") {
                    Task { @MainActor in shareImage() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(filteredTransactions.count) transaction\(filteredTransactions.count == 1 ? "" : "s")")
            }
            .navigationDestination(isPresented: $showCalendar) {
                CalendarView()
            }
        }
    }

    // MARK: - Filter picker

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(TransactionFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
    }

    // MARK: - Delete

    private func delete(from group: [Transaction], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(group[index]) }
    }

    // MARK: - CSV Export

    private func shareCSV() {
        var lines = ["Date,Title,Category,Type,Amount,Tags,Note"]
        for t in filteredTransactions {
            let date   = t.date.formatted(date: .numeric, time: .omitted)
            let type   = t.isExpense ? "Expense" : "Income"
            let tags   = t.tags.joined(separator: ";")
            let amount = String(format: "%.2f", t.amount)
            let title  = t.title.replacingOccurrences(of: "\"", with: "\"\"")
            let note   = t.note.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append("\"\(date)\",\"\(title)\",\"\(t.category)\",\"\(type)\",\(amount),\"\(tags)\",\"\(note)\"")
        }
        let data = lines.joined(separator: "\n").data(using: .utf8) ?? Data()
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent("rift_payments.csv")
        try? data.write(to: url)
        presentShareSheet([url])
    }

    // MARK: - PDF Export

    private func sharePDF() {
        let data = generatePDF()
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent("rift_payments.pdf")
        try? data.write(to: url)
        presentShareSheet([url])
    }

    private func generatePDF() -> Data {
        let pageW: CGFloat  = 595.2
        let pageH: CGFloat  = 841.8
        let margin: CGFloat = 48
        let colX: [CGFloat] = [margin + 4, margin + 86, margin + 236, margin + 336, margin + 430]

        // Explicit colors so the PDF always renders in light-mode style
        // regardless of the device's current appearance setting
        let colorBlack    = UIColor(white: 0.08, alpha: 1)
        let colorSecond   = UIColor(white: 0.45, alpha: 1)
        let colorRowAlt   = UIColor(white: 0.96, alpha: 1)
        let colorHeader   = UIColor(white: 0.90, alpha: 1)
        let colorDivider  = UIColor(white: 0.80, alpha: 1)
        let colorRed      = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        let colorGreen    = UIColor(red: 0.12, green: 0.60, blue: 0.25, alpha: 1)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            var y: CGFloat = margin

            // Title
            "Rift — Payment Report".draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold),
                                 .foregroundColor: colorBlack])
            y += 34

            // Meta
            let small: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10),
                                                         .foregroundColor: colorSecond]
            "Generated \(Date().formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: y), withAttributes: small)
            y += 14

            let totalExp = filteredTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
            let totalInc = filteredTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
            "\(filteredTransactions.count) transactions  ·  Income \(totalInc.currencyFormatted(for: currencyCode))  ·  Expenses \(totalExp.currencyFormatted(for: currencyCode))  ·  Net \((totalInc - totalExp).currencyFormatted(for: currencyCode))"
                .draw(at: CGPoint(x: margin, y: y), withAttributes: small)
            y += 22

            // Table header background
            cgCtx.setFillColor(colorHeader.cgColor)
            cgCtx.fill(CGRect(x: margin, y: y, width: pageW - margin * 2, height: 22))

            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                                                               .foregroundColor: colorSecond]
            zip(["Date", "Title", "Category", "Type", "Amount"], colX).forEach { text, x in
                text.draw(at: CGPoint(x: x, y: y + 6), withAttributes: headerAttrs)
            }
            y += 22

            // Divider
            cgCtx.setStrokeColor(colorDivider.cgColor)
            cgCtx.setLineWidth(0.5)
            cgCtx.move(to: CGPoint(x: margin, y: y))
            cgCtx.addLine(to: CGPoint(x: pageW - margin, y: y))
            cgCtx.strokePath()

            let rowAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10),
                                                            .foregroundColor: colorBlack]
            for (i, t) in filteredTransactions.enumerated() {
                if y > pageH - margin - 20 { ctx.beginPage(); y = margin }

                let rowH: CGFloat = 22
                if i % 2 == 0 {
                    cgCtx.setFillColor(colorRowAlt.cgColor)
                    cgCtx.fill(CGRect(x: margin, y: y, width: pageW - margin * 2, height: rowH))
                }

                let ty = y + 6
                let amountColor = t.isExpense ? colorRed : colorGreen
                t.date.formatted(date: .abbreviated, time: .omitted)
                    .draw(at: CGPoint(x: colX[0], y: ty), withAttributes: rowAttrs)
                t.title.draw(at: CGPoint(x: colX[1], y: ty), withAttributes: rowAttrs)
                t.category.draw(at: CGPoint(x: colX[2], y: ty), withAttributes: rowAttrs)
                (t.isExpense ? "Expense" : "Income")
                    .draw(at: CGPoint(x: colX[3], y: ty), withAttributes: rowAttrs)
                "\(t.isExpense ? "-" : "+")\(t.amount.currencyFormatted(for: currencyCode))"
                    .draw(at: CGPoint(x: colX[4], y: ty),
                          withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .medium),
                                           .foregroundColor: amountColor])
                y += rowH
            }

            // Footer
            "Rift · All data stays on your device."
                .draw(at: CGPoint(x: margin, y: pageH - margin - 10), withAttributes: small)
        }
    }

    // MARK: - Image Export

    @MainActor
    private func shareImage() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let screen     = windowScene.screen
        let screenSize = screen.bounds.size
        let scale      = screen.scale

        let content = PhoneExportView(transactions: filteredTransactions, currencyCode: currencyCode)
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        host.view.bounds = CGRect(origin: .zero, size: screenSize)
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: screenSize, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }

        presentShareSheet([image])
    }

    // MARK: - Share Sheet

    private func presentShareSheet(_ items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = root.view
        ac.popoverPresentationController?.sourceRect = CGRect(
            x: windowScene.screen.bounds.midX, y: 80, width: 0, height: 0
        )
        root.present(ac, animated: true)
    }
}

// MARK: - Phone-sized Export View

private struct PhoneExportView: View {
    let transactions: [Transaction]
    let currencyCode: String

    private var totalExpenses: Double { transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount } }
    private var totalIncome:   Double { transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    private var net:           Double { totalIncome - totalExpenses }

    // How many rows fit depends on screen height; cap at 12 for readability
    private var visibleRows: [Transaction] { Array(transactions.prefix(12)) }

    var body: some View {
        ZStack {
            // Dark background matching the app's dark aesthetic
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rift")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(Date().formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 24)

                // ── Summary cards ───────────────────────────────────────
                HStack(spacing: 12) {
                    summaryPill(label: "Income",   value: totalIncome,   color: Color(red: 0.2, green: 0.8, blue: 0.4))
                    summaryPill(label: "Expenses", value: totalExpenses, color: Color(red: 0.95, green: 0.3, blue: 0.3))
                    summaryPill(label: "Net",      value: net,           color: net >= 0 ? .white : Color(red: 0.95, green: 0.3, blue: 0.3))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // ── Transaction list ────────────────────────────────────
                VStack(spacing: 0) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, t in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(t.category)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(t.isExpense ? "-" : "+")\(t.amount.currencyFormatted(for: currencyCode))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(t.isExpense ? Color(red: 0.95, green: 0.35, blue: 0.35)
                                                                 : Color(red: 0.25, green: 0.85, blue: 0.45))
                                Text(t.date, style: .date)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)

                        if index < visibleRows.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.leading, 20)
                        }
                    }

                    if transactions.count > visibleRows.count {
                        Text("+ \(transactions.count - visibleRows.count) more transactions")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)

                Spacer()

                // ── Footer ──────────────────────────────────────────────
                Text("All data stays on your device · Rift")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 40)
            }
        }
    }

    private func summaryPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text(value.currencyFormatted(for: currencyCode))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Dynamic Calendar Icon

struct DynamicCalendarIcon: View {
    private let day = Calendar.current.component(.day, from: Date())

    var body: some View {
        Image(systemName: "\(day).calendar")
    }
}

#Preview {
    PaymentsView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
