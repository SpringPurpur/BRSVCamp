import SwiftUI

struct AppearanceSettingsView: View {
    let theme: ThemePreferences

    private let presetColors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .red, .indigo]

    var body: some View {
        List {
            Section("Mod") {
                Picker("Mod", selection: Binding(
                    get: { theme.appearanceMode },
                    set: { theme.appearanceMode = $0 }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(presetColors, id: \.self) { color in
                        let hex = color.toHex()
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if theme.accentColorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { theme.accentColorHex = hex }
                    }
                }
                .padding(.vertical, 6)

                ColorPicker("Culoare personalizată", selection: Binding(
                    get: { theme.accentColor ?? .accentColor },
                    set: { theme.accentColorHex = $0.toHex() }
                ), supportsOpacity: false)

                if theme.accentColorHex != nil {
                    Button("Resetează la implicit") {
                        theme.accentColorHex = nil
                    }
                }
            } header: {
                Text("Culoare accent")
            }
        }
        .navigationTitle("Aspect")
        .navigationBarTitleDisplayMode(.inline)
    }
}
