import SwiftUI

struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NoticeSection(title: "Cine suntem") {
                        Text("FriendCamp este o aplicație privată, folosită exclusiv de un grup restrâns de prieteni. Nu există un operator comercial — administratorul grupului este responsabil de datele stocate pentru acest grup.")
                    }

                    NoticeSection(title: "Ce date colectăm") {
                        BulletList(items: [
                            "Email și nume afișat, la crearea contului",
                            "Locație GPS, doar dacă activezi distribuirea locației",
                            "Nivel baterie, doar dacă activezi distribuirea bateriei",
                            "Fotografii și descrieri pentru puncte de interes și postări de blog",
                            "Cheltuieli și sume datorate, pentru decontarea în grup"
                        ])
                    }

                    NoticeSection(title: "Temeiul legal") {
                        Text("Procesăm datele pe baza consimțământului tău (Art. 6(1)(a) GDPR), exprimat la crearea contului. Poți retrage consimțământul oricând, dezactivând funcțiile relevante sau ștergându-ți contul.")
                    }

                    NoticeSection(title: "Cât timp păstrăm datele") {
                        Text("Datele sunt păstrate cât timp contul tău este activ. La ștergerea contului, toate datele personale (locații, postări, cheltuieli, fotografii) sunt șterse definitiv și imediat.")
                    }

                    NoticeSection(title: "Unde sunt găzduite") {
                        Text("Datele sunt găzduite pe Supabase, în regiunea UE (eu-central-1), în conformitate cu cerințele de rezidență a datelor din GDPR.")
                    }

                    NoticeSection(title: "Drepturile tale") {
                        BulletList(items: [
                            "Acces — poți vedea oricând datele tale în aplicație",
                            "Rectificare — poți edita profilul și datele introduse",
                            "Ștergere — poți șterge contul definitiv din Setări → Confidențialitate",
                            "Retragerea consimțământului — poți dezactiva oricând distribuirea locației, a bateriei sau a statusului online"
                        ])
                    }

                    NoticeSection(title: "Contact") {
                        Text("Pentru întrebări despre datele tale, contactează administratorul grupului direct.")
                    }
                }
                .padding()
            }
            .navigationTitle("Politica de Confidențialitate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Închide") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct NoticeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(item)
                }
            }
        }
    }
}
