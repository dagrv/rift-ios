import SwiftUI

// MARK: - Calculator Engine

@Observable
final class CalculatorEngine {
    var display: String = "0"

    private var previous: Double = 0
    private var pendingOp: String? = nil
    private var resetOnNextDigit = false
    private var justEvaluated = false

    func press(_ key: CalcKey) {
        switch key {

        case .digit(let n):
            if resetOnNextDigit || display == "0" {
                display = "\(n)"
                resetOnNextDigit = false
            } else {
                if display.count < 12 { display += "\(n)" }
            }
            justEvaluated = false

        case .decimal:
            if resetOnNextDigit { display = "0."; resetOnNextDigit = false }
            else if !display.contains(".") { display += "." }

        case .clear:
            display = "0"; previous = 0; pendingOp = nil
            resetOnNextDigit = false; justEvaluated = false

        case .negative:
            if let v = Double(display) { display = format(-v) }

        case .percent:
            guard let v = Double(display) else { return }
            if let op = pendingOp, op == "+" || op == "−" {
                display = format(previous * v / 100)
            } else {
                display = format(v / 100)
            }

        case .op(let symbol):
            if let v = Double(display) {
                if pendingOp != nil && !resetOnNextDigit && !justEvaluated {
                    let result = evaluate(previous, pendingOp!, v)
                    display = format(result); previous = result
                } else {
                    previous = v
                }
            }
            pendingOp = symbol
            resetOnNextDigit = true
            justEvaluated = false

        case .equals:
            guard let v = Double(display), let op = pendingOp else { return }
            let result = evaluate(previous, op, v)
            display = format(result)
            previous = result
            pendingOp = nil
            resetOnNextDigit = true
            justEvaluated = true
        }
    }

    private func evaluate(_ a: Double, _ op: String, _ b: Double) -> Double {
        switch op {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b != 0 ? a / b : 0
        default: return b
        }
    }

    private func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "Error" }
        if value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e12 {
            return String(Int64(value))
        }
        var s = String(format: "%.10g", value)
        if s.contains(".") {
            s = s.replacingOccurrences(of: "(\\d)\\.?(0+)$", with: "$1", options: .regularExpression)
        }
        return s
    }
}

// MARK: - Key Model

enum CalcKey: Hashable {
    case digit(Int), decimal, op(String), equals, clear, negative, percent

    var label: String {
        switch self {
        case .digit(let n): return "\(n)"
        case .decimal:      return "."
        case .op(let s):    return s
        case .equals:       return "="
        case .clear:        return "AC"
        case .negative:     return "+/−"
        case .percent:      return "%"
        }
    }

    var bg: Color {
        switch self {
        case .op, .equals:          return .orange
        case .clear, .negative, .percent: return Color(.systemGray4)
        default:                    return Color(.systemGray2)
        }
    }

    var fg: Color { .white }

    var fontSize: CGFloat {
        switch self {
        case .op, .equals: return 34
        default:           return 26
        }
    }
}

// MARK: - Main View

struct CalculatorView: View {
    @State private var engine = CalculatorEngine()
    @State private var mode: CalcMode = .calculator

    enum CalcMode: String, CaseIterable {
        case calculator = "Calculator"
        case discount   = "Discount"
        case tip        = "Tip"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(CalcMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch mode {
            case .calculator: calculatorPanel
            case .discount:   DiscountPanel()
            case .tip:        TipPanel()
            }
        }
        .navigationTitle("Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Calculator Panel

    private var calculatorPanel: some View {
        VStack(spacing: 0) {
            displayRow

            Divider().padding(.horizontal)

            keypad
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    private var displayRow: some View {
        HStack {
            Spacer()
            Text(engine.display)
                .font(.system(size: 60, weight: .thin, design: .rounded))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                keyButton(.clear); keyButton(.negative)
                keyButton(.percent); keyButton(.op("÷"))
            }
            GridRow {
                keyButton(.digit(7)); keyButton(.digit(8))
                keyButton(.digit(9)); keyButton(.op("×"))
            }
            GridRow {
                keyButton(.digit(4)); keyButton(.digit(5))
                keyButton(.digit(6)); keyButton(.op("−"))
            }
            GridRow {
                keyButton(.digit(1)); keyButton(.digit(2))
                keyButton(.digit(3)); keyButton(.op("+"))
            }
            GridRow {
                keyButton(.digit(0)).gridCellColumns(2)
                keyButton(.decimal)
                keyButton(.equals)
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: CalcKey) -> some View {
        Button { engine.press(key) } label: {
            Text(key.label)
                .font(.system(size: key.fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(key.fg)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(key.bg)
                .clipShape(RoundedRectangle(cornerRadius: 36))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Discount Panel

struct DiscountPanel: View {
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @State private var priceText = ""
    @State private var discountText = ""

    private var currencySymbol: String {
        switch currencyCode {
        case "EUR": return "€"
        case "JPY": return "¥"
        default:    return "$"
        }
    }

    private var price: Double? { Double(priceText) }
    private var discount: Double? { Double(discountText) }

    private var savings: Double? {
        guard let p = price, let d = discount else { return nil }
        return p * d / 100
    }
    private var finalPrice: Double? {
        guard let p = price, let s = savings else { return nil }
        return p - s
    }

    var body: some View {
        Form {
            Section("Original Price") {
                HStack {
                    if currencyCode != "EUR" {
                        Text(currencySymbol).foregroundStyle(.secondary)
                    }
                    TextField("0.00", text: $priceText).keyboardType(.decimalPad)
                    if currencyCode == "EUR" {
                        Text(currencySymbol).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Discount") {
                HStack {
                    TextField("0", text: $discountText).keyboardType(.decimalPad)
                    Text("%").foregroundStyle(.secondary)
                }
            }
            if let savings, let finalPrice, let price {
                Section("Result") {
                    LabeledContent("Original Price", value: price.currencyFormatted(for: currencyCode))
                    LabeledContent("You Save", value: savings.currencyFormatted(for: currencyCode))
                        .foregroundStyle(.green)
                    LabeledContent("Final Price", value: finalPrice.currencyFormatted(for: currencyCode))
                        .bold()
                }
            }

            Section("Quick Discounts") {
                if let price {
                    let presets = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 50.0]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                        ForEach(presets, id: \.self) { pct in
                            Button {
                                discountText = String(Int(pct))
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(Int(pct))% off")
                                        .font(.caption).fontWeight(.medium)
                                    Text((price * pct / 100).currencyFormatted(for: currencyCode))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Enter a price to see quick discounts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Tip Panel

struct TipPanel: View {
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @State private var billText = ""
    @State private var peopleText = "1"
    @State private var selectedTip: Double = 15

    private var currencySymbol: String {
        switch currencyCode {
        case "EUR": return "€"
        case "JPY": return "¥"
        default:    return "$"
        }
    }

    private let tipOptions = [10.0, 15.0, 18.0, 20.0, 25.0]
    private var bill: Double? { Double(billText) }
    private var people: Int { Int(peopleText) ?? 1 }

    private var tipAmount: Double? {
        guard let b = bill else { return nil }
        return b * selectedTip / 100
    }
    private var total: Double? {
        guard let b = bill, let t = tipAmount else { return nil }
        return b + t
    }
    private var perPerson: Double? {
        guard let t = total else { return nil }
        return t / Double(max(people, 1))
    }

    var body: some View {
        Form {
            Section("Bill Amount") {
                HStack {
                    if currencyCode != "EUR" {
                        Text(currencySymbol).foregroundStyle(.secondary)
                    }
                    TextField("0.00", text: $billText).keyboardType(.decimalPad)
                    if currencyCode == "EUR" {
                        Text(currencySymbol).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Tip") {
                Picker("Tip %", selection: $selectedTip) {
                    ForEach(tipOptions, id: \.self) { Text("\(Int($0))%").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Split") {
                Stepper("**\(people)** \(people == 1 ? "person" : "people")", value: $peopleText,
                        in: "1"..."20", step: "1")
            }

            if let tipAmount, let total, let perPerson, let bill {
                Section("Result") {
                    LabeledContent("Bill", value: bill.currencyFormatted(for: currencyCode))
                    LabeledContent("Tip (\(Int(selectedTip))%)", value: tipAmount.currencyFormatted(for: currencyCode))
                    LabeledContent("Total", value: total.currencyFormatted(for: currencyCode)).bold()
                    if people > 1 {
                        LabeledContent("Per Person", value: perPerson.currencyFormatted(for: currencyCode))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }
}

// Stepper convenience for String-backed value
extension Stepper where Label == Text {
    init(_ title: LocalizedStringKey, value: Binding<String>, in range: ClosedRange<String>, step: String) {
        self.init(title) {
            if let n = Int(value.wrappedValue), n < (Int(range.upperBound) ?? 99) {
                value.wrappedValue = "\(n + 1)"
            }
        } onDecrement: {
            if let n = Int(value.wrappedValue), n > (Int(range.lowerBound) ?? 1) {
                value.wrappedValue = "\(n - 1)"
            }
        }
    }
}

#Preview {
    CalculatorView()
}
