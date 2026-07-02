import SwiftUI
import Supabase

// MARK: - ExpensesView

struct ExpensesView: View {
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(AuthService.self)    private var auth
    @State private var selectedExpense: Expense?
    @State private var showCreateSheet = false

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
                        showCreateSheet = true
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
        .sheet(isPresented: $showCreateSheet) {
            ExpenseCreateSheet { showCreateSheet = false }
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
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showFullscreenPhoto = false
    @State private var isDeleting = false
    @State private var isSettling = false

    private var canManage: Bool {
        expense.paidBy.id == currentUserId || groupService.activeUserRole == "admin"
    }

    private var mySplit: ExpenseSplit? {
        expense.splits.first { $0.member.id == currentUserId }
    }

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

                    if expense.editCount > 0 {
                        Text("Editat de \(expense.editCount) ori" + (expense.lastEditedAt.map {
                            " · ultima oară \($0.formatted(.relative(presentation: .named)))"
                        } ?? ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let receiptURL = expense.receiptURL {
                        AsyncImage(url: receiptURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.15)
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { showFullscreenPhoto = true }
                        .fullScreenCover(isPresented: $showFullscreenPhoto) {
                            FullScreenImageViewer(url: receiptURL)
                        }
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

                    if let mySplit, !mySplit.settled {
                        Button {
                            Task { await markMySplitSettled(splitId: mySplit.id) }
                        } label: {
                            Label("Marchează partea mea ca achitată", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSettling)
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                if canManage {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Editează", systemImage: "pencil") { showEditSheet = true }
                            Button("Șterge", systemImage: "trash", role: .destructive) {
                                showDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Închide") { dismiss() }
                }
            }
            .confirmationDialog("Ștergi această cheltuială?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Șterge", role: .destructive) { Task { await deleteExpense() } }
                Button("Anulează", role: .cancel) {}
            }
            .sheet(isPresented: $showEditSheet) {
                ExpenseCreateSheet(editing: expense) {
                    showEditSheet = false
                    dismiss()
                }
            }
            .disabled(isDeleting)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func markMySplitSettled(splitId: UUID) async {
        isSettling = true
        struct SettleSplit: Encodable {
            let settled: Bool
            let settled_at: String
        }
        let payload = SettleSplit(settled: true, settled_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await supabase.from("expense_splits")
            .update(payload)
            .eq("id", value: splitId.uuidString)
            .execute()
        if let groupId = groupService.activeGroupId {
            await dataStore.loadExpenses(groupId: groupId)
        }
        isSettling = false
    }

    private func deleteExpense() async {
        guard let groupId = groupService.activeGroupId else { return }
        isDeleting = true
        if expense.receiptURL != nil {
            let path = "\(expense.paidBy.id.uuidString)/\(expense.id.uuidString).jpg"
            _ = try? await supabase.storage.from("receipts").remove(paths: [path])
        }
        _ = try? await supabase.from("expenses")
            .delete()
            .eq("id", value: expense.id.uuidString)
            .execute()
        await dataStore.loadExpenses(groupId: groupId)
        dismiss()
    }
}
