import SwiftUI

struct PrivacySettingsView: View {
    let prefsService: UserPreferencesService
    @State private var showDeleteConfirm = false
    @State private var isExporting = false
    @State private var exportFileURL: URL?
    @State private var exportError: String?
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                PrivacyToggleRow(
                    icon: "location.fill",
                    iconColor: .blue,
                    title: "Distribuie locația",
                    subtitle: "Membrii grupului îți pot vedea poziția pe hartă",
                    isOn: prefsService.preferences.shareLocation
                ) { value in
                    Task { try? await prefsService.setShareLocation(value) }
                }

                PrivacyToggleRow(
                    icon: "battery.75",
                    iconColor: .green,
                    title: "Distribuie nivelul bateriei",
                    subtitle: "Apare pe chip-ul tău din status bar",
                    isOn: prefsService.preferences.shareBattery
                ) { value in
                    Task { try? await prefsService.setShareBattery(value) }
                }

                PrivacyToggleRow(
                    icon: "circle.fill",
                    iconColor: .green,
                    title: "Apari ca online",
                    subtitle: "Dacă dezactivezi, apari offline pentru toți membrii",
                    isOn: prefsService.preferences.appearOnline
                ) { value in
                    Task { try? await prefsService.setAppearOnline(value) }
                }
            } header: {
                Text("Date personale")
            } footer: {
                Text("Poți modifica oricând aceste preferințe. Modificările se aplică imediat pe toate dispozitivele.")
            }

            Section {
                if let url = exportFileURL {
                    ShareLink(item: url, preview: SharePreview("BRSVCamp Export")) {
                        Label("Descarcă datele mele", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        Task { await exportData() }
                    } label: {
                        HStack {
                            Label("Exportă datele mele", systemImage: "square.and.arrow.up")
                            if isExporting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isExporting)
                }
                if let exportError {
                    Text(exportError).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Portabilitatea datelor")
            } footer: {
                Text("Descarcă un fișier JSON cu profilul tău, locațiile, punctele de interes, postările și cheltuielile (Art. 20 GDPR).")
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Șterge contul și toate datele", systemImage: "person.crop.circle.badge.minus")
                }
            } footer: {
                Text("Această acțiune este ireversibilă. Vor fi șterse toate locațiile, postările, cheltuielile și apartenența la grupuri.")
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .navigationTitle("Confidențialitate")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Șterge contul",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Șterge definitiv", role: .destructive) {
                Task {
                    await auth.deleteAccount()
                    dismiss()
                }
            }
            Button("Anulează", role: .cancel) { }
        } message: {
            Text("Toate datele tale vor fi șterse permanent și nu pot fi recuperate.")
        }
    }

    private func exportData() async {
        isExporting = true
        exportError = nil
        exportFileURL = nil
        do {
            let data = try await supabase.rpc("export_user_data").execute().data
            let timestamp = Int(Date().timeIntervalSince1970)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("brsvcamp-export-\(timestamp).json")
            try data.write(to: url)
            await MainActor.run { exportFileURL = url }
        } catch {
            await MainActor.run { exportError = error.localizedDescription }
        }
        await MainActor.run { isExporting = false }
    }
}

// MARK: - PrivacyToggleRow

struct PrivacyToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            ))
            .labelsHidden()
        }
    }
}
