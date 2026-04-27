import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var showAddBudget = false
    @State private var editBudget: Budget? = nil

    var body: some View {
        NavigationStack {
            Group {
                if budgets.isEmpty {
                    ContentUnavailableView(
                        "No Budgets",
                        systemImage: "dollarsign.circle",
                        description: Text("Set up budgets to track your spending.")
                    )
                } else {
                    List {
                        ForEach(budgets) { budget in
                            BudgetCard(budget: budget, spent: spent(for: budget))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .leading) {
                                    Button { editBudget = budget } label: {
                                        Label("Edit", systemImage: "square.and.pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete(perform: deleteBudgets)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddBudget = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                BudgetSheet()
            }
            .sheet(item: $editBudget) { budget in
                BudgetSheet(budget: budget)
            }
        }
    }

    private func spent(for budget: Budget) -> Double {
        let now = Date()
        let startDate: Date? = switch budget.period {
        case .weekly:  Calendar.current.date(byAdding: .day,   value: -7,  to: now)
        case .monthly: Calendar.current.date(byAdding: .month, value: -1,  to: now)
        case .yearly:  Calendar.current.date(byAdding: .year,  value: -1,  to: now)
        }
        return transactions.filter { t in
            t.isExpense &&
            t.category == budget.category &&
            (startDate == nil || t.date >= startDate!)
        }.reduce(0) { $0 + $1.amount }
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(budgets[index]) }
    }
}

// MARK: - Budget Card

struct BudgetCard: View {
    let budget: Budget
    let spent: Double
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @AppStorage("isPrivateMode") private var isPrivateMode: Bool = false

    private var progress: Double {
        guard budget.limit > 0 else { return 0 }
        return min(spent / budget.limit, 1.0)
    }

    private var isOverBudget: Bool { spent > budget.limit }
    private var remaining: Double { max(budget.limit - spent, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CategoryData.color(for: budget.category).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: CategoryData.icon(for: budget.category))
                        .foregroundStyle(CategoryData.color(for: budget.category))
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.category)
                        .font(.headline)
                    Text(LocalizedStringKey(budget.period.rawValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isPrivateMode ? "****" : spent.currencyFormatted(for: currencyCode))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOverBudget ? Color.red : Color.primary)
                    Text(isPrivateMode ? "of ****" : "of \(budget.limit.currencyFormatted(for: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isOverBudget ? Color.red : CategoryData.color(for: budget.category))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)
                .blur(radius: isPrivateMode ? 8 : 0)

                HStack {
                    if isOverBudget {
                        Label(isPrivateMode ? "Over budget" : "Over by \((spent - budget.limit).currencyFormatted(for: currencyCode))", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text(isPrivateMode ? "**** remaining" : "\(remaining.currencyFormatted(for: currencyCode)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isPrivateMode {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(isOverBudget ? .red : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Budget Sheet (Add & Edit)

struct BudgetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var budget: Budget? = nil

    private static let customTag = "__custom__"

    @State private var pickerCategory = CategoryData.expenseCategories[0]
    @State private var customCategory = ""
    @State private var limitString = ""
    @State private var period: BudgetPeriod = .monthly

    private var currencySymbol: String {
        switch currencyCode {
        case "EUR": return "€"
        case "JPY": return "¥"
        default:    return "$"
        }
    }

    private var isCustom: Bool { pickerCategory == Self.customTag }
    private var effectiveCategory: String {
        isCustom ? customCategory.trimmingCharacters(in: .whitespaces) : pickerCategory
    }
    private var limit: Double { Double(limitString) ?? 0 }
    private var canSave: Bool { limit > 0 && !effectiveCategory.isEmpty }
    private var isEditing: Bool { budget != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $pickerCategory) {
                        ForEach(CategoryData.expenseCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Text("Custom").tag(Self.customTag)
                    }
                    if isCustom {
                        TextField("Category name", text: $customCategory)
                            .autocorrectionDisabled()
                    }
                }

                Section("Limit") {
                    HStack {
                        if currencyCode != "EUR" {
                            Text(currencySymbol).foregroundStyle(.secondary)
                        }
                        TextField("0.00", text: $limitString)
                            .keyboardType(.decimalPad)
                        if currencyCode == "EUR" {
                            Text(currencySymbol).foregroundStyle(.secondary)
                        }
                    }
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let budget else { return }
        if CategoryData.expenseCategories.contains(budget.category) {
            pickerCategory = budget.category
        } else {
            pickerCategory = Self.customTag
            customCategory = budget.category
        }
        limitString = budget.limit.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(budget.limit))
            : String(budget.limit)
        period = budget.period
    }

    private func save() {
        if let budget {
            budget.category = effectiveCategory
            budget.limit = limit
            budget.period = period
        } else {
            modelContext.insert(Budget(category: effectiveCategory, limit: limit, period: period))
        }
        dismiss()
    }
}

#Preview {
    BudgetsView()
        .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
