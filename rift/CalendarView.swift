import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedDate: Date? = nil

    private var cal: Calendar { Calendar.current }

    private var startOfMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let weekday = cal.component(.weekday, from: startOfMonth) - 1
        let firstDay = cal.firstWeekday - 1
        return (weekday - firstDay + 7) % 7
    }

    private var weekdayHeaders: [String] {
        let symbols = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // Single array with unique sequential IDs avoids LazyVGrid duplicate-ID warnings
    private struct GridCell: Identifiable {
        let id: Int
        let dayNumber: Int?
        let date: Date?
    }

    private var gridCells: [GridCell] {
        var cells = (0..<leadingBlanks).map { GridCell(id: $0, dayNumber: nil, date: nil) }
        for day in 1...max(daysInMonth, 1) {
            cells.append(GridCell(
                id: leadingBlanks + day - 1,
                dayNumber: day,
                date: cal.date(byAdding: .day, value: day - 1, to: startOfMonth)
            ))
        }
        return cells
    }

    private func spending(for date: Date) -> Double {
        transactions.filter { $0.isExpense && cal.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
    }

    private func income(for date: Date) -> Double {
        transactions.filter { !$0.isExpense && cal.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
    }

    private func dayTransactions(for date: Date) -> [Transaction] {
        transactions.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func moveMonth(by value: Int) {
        selectedMonth = cal.date(byAdding: .month, value: value, to: selectedMonth) ?? selectedMonth
        selectedDate = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthNavigator
                calendarGrid
                if let date = selectedDate {
                    selectedDaySection(for: date)
                }
            }
            .padding()
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(selectedMonth.formatted(.dateTime.month(.wide)))
                    .font(.title3).fontWeight(.semibold)
                Text(selectedMonth.formatted(.dateTime.year()))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { symbol in
                    Text(symbol.prefix(2))
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)

            Divider()

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(gridCells) { cell in
                    if let day = cell.dayNumber, let date = cell.date {
                        let s = spending(for: date)
                        let i = income(for: date)
                        let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false

                        CalendarDayCell(
                            day: day,
                            spending: s,
                            income: i,
                            isSelected: isSelected,
                            isToday: cal.isDateInToday(date)
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.18)) {
                                selectedDate = isSelected ? nil : date
                            }
                        }
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Selected Day

    private func selectedDaySection(for date: Date) -> some View {
        let items = dayTransactions(for: date)
        return VStack(alignment: .leading, spacing: 12) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.headline)
                .padding(.horizontal, 4)

            if items.isEmpty {
                Text("No transactions on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != items.last?.id {
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

// MARK: - Day Cell

struct CalendarDayCell: View {
    let day: Int
    let spending: Double
    let income: Double
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day)")
                .font(.system(size: 15, weight: isToday ? .bold : .regular))
                .foregroundStyle(isSelected || isToday ? Color.accentColor : .primary)

            HStack(spacing: 2) {
                if spending > 0 {
                    Circle().fill(Color.red).frame(width: 5, height: 5)
                }
                if income > 0 {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.12)
                        : isToday ? Color.accentColor.opacity(0.06) : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .modelContainer(try! ModelContainer(for: Transaction.self, Budget.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
