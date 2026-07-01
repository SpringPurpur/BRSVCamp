import SwiftUI

// MARK: - ExpensesView

struct ExpensesView: View {
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(AuthService.self)    private var auth
    @State private var selectedExpense: Expense?

    private var expenses: [Expense] { dataStore.expenses }
    private var currentUserId: UUID? { auth.currentUserId }

    private var totalTrip: Double { expenses.reduce(0) { $0 + $1.amount } }

    private var iPaid: Double {
        expenses
            .filter { $0.paidBy.id == currentUserId }
            .reduce(0) { $0 + $1.amount }
    }

    private var iOwe: Double {
        expenses
            .filter { $0.paidBy.id != currentUserId }
            .flatMap { $0.splits }
            .filter { $0.member.id == currentUserId && !$0.settled }
            .reduce(0) { $0 + $1.amount }
    }

    private var owedToMe: Double {
        expenses
            .filter { $0.paidBy.id == currentUserId }
            .flatMap { $0.splits }
            .filter { $0.member.id != currentUserId && !$0.settled }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TripSummaryCard(
                        total: totalTrip,
                        iPaid: iPaid,
                        iOwe: iOwe,
                        owedToMe: owedToMe
                    )
                    .padding(.horizontal)

                    LazyVStack(spacing: 10) {
                        ForEach(expenses) { expense in
                            ExpenseRow(expense: expense, currentUserId: currentUserId)
                                .onTapGesture { selectedExpense = expense }
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Cheltuieli")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: add expense / scan receipt
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailSheet(expense: expense, currentUserId: currentUserId)
        }
    }
}

// MARK: - Summary Card

struct TripSummaryCard: View {
    let total: Double
    let iPaid: Double
    let iOwe: Double
    let owedToMe: Double

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total trip")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(total, format: .currency(code: "RON"))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "tent.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .background(
                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            // Stats row
            HStack(spacing: 0) {
                SummaryStatCell(
                    label: "Eu am plătit",
                    value: iPaid,
                    color: .blue
                )
                Divider()
                SummaryStatCell(
                    label: iOwe > 0 ? "Datorez" : "Fără datorii",
                    value: iOwe,
                    color: iOwe > 0 ? .red : .green
                )
                Divider()
                SummaryStatCell(
                    label: "Mi se datorează",
                    value: owedToMe,
                    color: owedToMe > 0 ? .orange : .secondary
                )
            }
            .frame(height: 64)
            .background(.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

struct SummaryStatCell: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value, format: .currency(code: "RON"))
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense
    let currentUserId: UUID?

    private var myShare: ExpenseSplit? {
        expense.splits.first { $0.member.id == currentUserId }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            Image(systemName: expense.category.systemImage)
                .font(.title3)
                .foregroundStyle(expense.category.color)
                .frame(width: 46, height: 46)
                .background(expense.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(expense.paidBy.avatarColor)
                        .frame(width: 14, height: 14)
                    Text("Plătit de \(expense.paidBy.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount, format: .currency(code: expense.currency))
                    .font(.subheadline.bold())

                if let share = myShare {
                    Text(share.settled ? "Achitat" : "Partea mea: \(share.amount, format: .currency(code: expense.currency))")
                        .font(.caption2)
                        .foregroundStyle(share.settled ? .green : .secondary)
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}

// MARK: - Expense Detail Sheet

struct ExpenseDetailSheet: View {
    let expense: Expense
    let currentUserId: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 14) {
                        Image(systemName: expense.category.systemImage)
                            .font(.title)
                            .foregroundStyle(expense.category.color)
                            .frame(width: 60, height: 60)
                            .background(expense.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.description)
                                .font(.headline)
                            Text(expense.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(expense.amount, format: .currency(code: expense.currency))
                            .font(.title2.bold())
                    }

                    Divider()

                    // Splits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Împărțit între")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        ForEach(expense.splits) { split in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(split.member.avatarColor.gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(split.member.initials)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }

                                Text(split.member.id == currentUserId ? "Tu" : split.member.name)
                                    .font(.subheadline)
                                    .fontWeight(split.member.id == currentUserId ? .bold : .regular)

                                Spacer()

                                Text(split.amount, format: .currency(code: expense.currency))
                                    .font(.subheadline)

                                Image(systemName: split.settled ? "checkmark.circle.fill" : "clock.fill")
                                    .foregroundStyle(split.settled ? .green : .orange)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Închide") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
