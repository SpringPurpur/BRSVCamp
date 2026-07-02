import SwiftUI
import PhotosUI
import Supabase

struct ExpenseCreateSheet: View {
    enum Mode {
        case create
        case edit(Expense)
    }

    private struct SplitRowState: Identifiable {
        let member: GroupMember
        var included: Bool
        var amountText: String
        var percentText: String
        var id: UUID { member.id }
    }

    let mode: Mode
    var onDone: () -> Void

    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var description: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    // Doar relevant în modul create — o cheltuială existentă își păstrează grupul din editing.
    @State private var selectedGroupId: UUID?
    @State private var rows: [SplitRowState] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var existingReceiptURL: URL?
    @State private var removeExistingPhoto = false
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(onDone: @escaping () -> Void) {
        self.mode = .create
        self.onDone = onDone
        _description = State(initialValue: "")
        _amountText = State(initialValue: "")
        _category = State(initialValue: .other)
        _date = State(initialValue: Date())
        _existingReceiptURL = State(initialValue: nil)
    }

    init(editing expense: Expense, onDone: @escaping () -> Void) {
        self.mode = .edit(expense)
        self.onDone = onDone
        _description = State(initialValue: expense.description)
        _amountText = State(initialValue: String(format: "%.2f", expense.amount))
        _category = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _existingReceiptURL = State(initialValue: expense.receiptURL)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    // Editarea nu schimbă grupul unei cheltuieli existente — doar creare folosește picker-ul.
    private var effectiveGroupId: UUID? {
        switch mode {
        case .create: return selectedGroupId ?? groupService.activeGroupId ?? groupService.myGroups.first?.groupId
        case .edit:   return groupService.activeGroupId
        }
    }

    // Doar plătitorul poate atinge poza de bon — RLS-ul de pe storage.objects pentru bucket-ul
    // "receipts" verifică identitatea uploader-ului, nu apartenența la grup, deci un admin care
    // editează cheltuiala altcuiva n-ar putea înlocui poza oricum.
    private var canEditPhoto: Bool {
        switch mode {
        case .create: return true
        case .edit(let expense): return expense.paidBy.id == auth.currentUserId
        }
    }

    private var totalAmount: Double { Double(amountText) ?? 0 }
    private var allocatedTotal: Double {
        rows.filter(\.included).reduce(0) { $0 + (Double($1.amountText) ?? 0) }
    }
    private var remaining: Double { totalAmount - allocatedTotal }
    private var isFullyAllocated: Bool { abs(remaining) < 0.01 }
    private var hasParticipants: Bool { rows.contains { $0.included } }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
            && totalAmount > 0
            && hasParticipants
            && isFullyAllocated
            && !isSaving
    }

    private var allocationSummary: String {
        "Alocat \(allocatedTotal.formatted(.currency(code: "RON"))) din \(totalAmount.formatted(.currency(code: "RON"))) — rămas \(remaining.formatted(.currency(code: "RON")))"
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("Grup") {
                        Picker("Grup", selection: Binding(
                            get: { selectedGroupId ?? groupService.activeGroupId ?? groupService.myGroups.first?.groupId },
                            set: { selectedGroupId = $0 }
                        )) {
                            ForEach(groupService.myGroups) { membership in
                                Text(membership.group.name).tag(Optional(membership.groupId))
                            }
                        }
                    }
                }

                Section("Detalii") {
                    TextField("Descriere", text: $description)
                    TextField("Sumă (RON)", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Categorie", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }

                Section {
                    ForEach(rows.indices, id: \.self) { i in
                        splitRow(at: i)
                    }
                    Button("Împarte egal", action: splitEqually)
                        .disabled(!hasParticipants || totalAmount <= 0)
                } header: {
                    Text("Împărțit între")
                } footer: {
                    Text(allocationSummary)
                        .foregroundStyle(isFullyAllocated ? .green : .red)
                }

                if canEditPhoto {
                    Section("Bon fiscal") {
                        Menu {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Alege din galerie", systemImage: "photo.on.rectangle")
                            }
                            Button {
                                showCamera = true
                            } label: {
                                Label("Fă o poză", systemImage: "camera")
                            }
                        } label: {
                            Label(photoImage == nil && existingReceiptURL == nil ? "Adaugă poză" : "Schimbă poza",
                                  systemImage: "photo")
                        }
                        if let photoImage {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if let existingReceiptURL, !removeExistingPhoto {
                            AsyncImage(url: existingReceiptURL) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.gray.opacity(0.15)
                            }
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("Șterge poza", role: .destructive) {
                                removeExistingPhoto = true
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(isEditing ? "Editează cheltuiala" : "Cheltuială nouă")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anulează") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salvează") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .task {
                if rows.isEmpty { rows = buildInitialRows() }
            }
            .onChange(of: selectedGroupId) { _, _ in
                // Doar în modul create — userul a schimbat grupul înainte de a salva,
                // deci lista de participanți trebuie reconstruită pentru noul grup.
                if !isEditing { rows = buildInitialRows() }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        photoImage = uiImage
                        removeExistingPhoto = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    photoImage = image
                    removeExistingPhoto = false
                }
                .ignoresSafeArea()
            }
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func splitRow(at i: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                rows[i].included.toggle()
            } label: {
                Image(systemName: rows[i].included ? "checkmark.square.fill" : "square")
                    .foregroundStyle(rows[i].included ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(rows[i].member.avatarColor.gradient)
                .frame(width: 26, height: 26)
                .overlay {
                    Text(rows[i].member.initials)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }

            Text(rows[i].member.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if rows[i].included {
                TextField("Sumă", text: $rows[i].amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .onChange(of: rows[i].amountText) { _, newValue in syncPercent(at: i, fromAmount: newValue) }
                Text("/").foregroundStyle(.tertiary)
                TextField("%", text: $rows[i].percentText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onChange(of: rows[i].percentText) { _, newValue in syncAmount(at: i, fromPercent: newValue) }
                Text("%").foregroundStyle(.tertiary)
            }
        }
    }

    // Conversie doar per-rând — nu redistribuie restul participanților.
    private func syncPercent(at i: Int, fromAmount text: String) {
        guard let amount = Double(text), totalAmount > 0 else { return }
        let pctText = String(format: "%.2f", (amount / totalAmount) * 100)
        // Scriem doar dacă diferă — altfel cele două TextField-uri s-ar tot rescrie una pe alta.
        if rows[i].percentText != pctText { rows[i].percentText = pctText }
    }

    private func syncAmount(at i: Int, fromPercent text: String) {
        guard let pct = Double(text), totalAmount > 0 else { return }
        let newAmountText = String(format: "%.2f", (pct / 100) * totalAmount)
        if rows[i].amountText != newAmountText { rows[i].amountText = newAmountText }
    }

    private func splitEqually() {
        let includedIndices = rows.indices.filter { rows[$0].included }
        guard !includedIndices.isEmpty, totalAmount > 0 else { return }
        let share = totalAmount / Double(includedIndices.count)
        let shareText = String(format: "%.2f", share)
        let pctText = String(format: "%.2f", (share / totalAmount) * 100)
        for i in includedIndices {
            rows[i].amountText = shareText
            rows[i].percentText = pctText
        }
    }

    private func buildInitialRows() -> [SplitRowState] {
        let existingSplits: [ExpenseSplit]
        if case .edit(let expense) = mode {
            existingSplits = expense.splits
        } else {
            existingSplits = []
        }
        return dataStore.members.filter { $0.groupId == effectiveGroupId }.map { member in
            if let split = existingSplits.first(where: { $0.member.id == member.id }) {
                let pct = totalAmount > 0 ? (split.amount / totalAmount) * 100 : 0
                return SplitRowState(
                    member: member, included: true,
                    amountText: String(format: "%.2f", split.amount),
                    percentText: String(format: "%.2f", pct)
                )
            } else {
                return SplitRowState(member: member, included: false, amountText: "", percentText: "")
            }
        }
    }

    private func save() async {
        guard let userId = auth.currentUserId,
              let groupId = effectiveGroupId else { return }
        isSaving = true
        errorMessage = nil
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let includedRows = rows.filter(\.included)
        do {
            switch mode {
            case .create:
                struct NewExpense: Encodable {
                    let group_id: UUID
                    let paid_by: UUID
                    let amount: Double
                    let currency: String
                    let category: String
                    let description: String
                    let date: String
                }
                let payload = NewExpense(
                    group_id: groupId,
                    paid_by: userId,
                    amount: totalAmount,
                    currency: "RON",
                    category: category.dbValue,
                    description: trimmedDescription,
                    date: isoDateOnly(date)
                )
                struct InsertedExpense: Decodable { let id: UUID }
                let inserted: InsertedExpense = try await supabase
                    .from("expenses")
                    .insert(payload)
                    .select("id")
                    .single()
                    .execute()
                    .value

                try await insertSplits(expenseId: inserted.id, rows: includedRows)

                if let photoImage, let jpegData = compressedJPEGData(from: photoImage) {
                    let path = "\(userId.uuidString)/\(inserted.id.uuidString).jpg"
                    try await supabase.storage.from("receipts")
                        .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg"))
                    try await supabase.from("expenses")
                        .update(["receipt_url": path])
                        .eq("id", value: inserted.id.uuidString)
                        .execute()
                }

            case .edit(let existing):
                struct UpdateExpense: Encodable {
                    let amount: Double
                    let currency: String
                    let category: String
                    let description: String
                    let date: String
                }
                let payload = UpdateExpense(
                    amount: totalAmount,
                    currency: "RON",
                    category: category.dbValue,
                    description: trimmedDescription,
                    date: isoDateOnly(date)
                )
                try await supabase.from("expenses")
                    .update(payload)
                    .eq("id", value: existing.id.uuidString)
                    .execute()

                // Refacem splits-urile de la zero — mai simplu decât un diff, la fel ca la
                // editarea pozelor de blog (șterge tot ce era, inserează ce e acum inclus).
                _ = try? await supabase.from("expense_splits")
                    .delete()
                    .eq("expense_id", value: existing.id.uuidString)
                    .execute()
                try await insertSplits(expenseId: existing.id, rows: includedRows)

                if canEditPhoto {
                    let path = "\(existing.paidBy.id.uuidString)/\(existing.id.uuidString).jpg"
                    if removeExistingPhoto, photoImage == nil {
                        _ = try? await supabase.storage.from("receipts").remove(paths: [path])
                        let nilPayload: [String: String?] = ["receipt_url": nil]
                        _ = try? await supabase.from("expenses")
                            .update(nilPayload)
                            .eq("id", value: existing.id.uuidString)
                            .execute()
                    } else if let photoImage, let jpegData = compressedJPEGData(from: photoImage) {
                        try await supabase.storage.from("receipts")
                            .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                        try await supabase.from("expenses")
                            .update(["receipt_url": path])
                            .eq("id", value: existing.id.uuidString)
                            .execute()
                    }
                }
            }

            // La fel ca la Blog — reîncarcă lista cheltuielilor grupului ACTIV, nu neapărat
            // grupId-ul acestei cheltuieli.
            if let activeId = groupService.activeGroupId {
                await dataStore.loadExpenses(groupId: activeId)
            }
            onDone()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func insertSplits(expenseId: UUID, rows: [SplitRowState]) async throws {
        guard !rows.isEmpty else { return }
        struct NewSplit: Encodable {
            let expense_id: UUID
            let user_id: UUID
            let amount: Double
        }
        let payloads = rows.map {
            NewSplit(expense_id: expenseId, user_id: $0.member.id, amount: Double($0.amountText) ?? 0)
        }
        try await supabase.from("expense_splits").insert(payloads).execute()
    }

    private func isoDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }
}
