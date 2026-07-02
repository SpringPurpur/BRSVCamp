import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistem"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// Preferință pur locală (UserDefaults), NElegată de userId — spre deosebire de
// MapVisibilityPreferences/UserPreferencesService, tema e o preferință de device, nu de cont,
// și trebuie să se aplice și pe ecranul de login/onboarding, dinaintea autentificării.
@Observable
final class ThemePreferences {
    var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    // nil = nicio suprascriere, cade pe AccentColor implicit (albastru) — nu un hex hardcodat
    // pentru "default", ca userii existenți să nu vadă nicio schimbare până nu aleg explicit.
    var accentColorHex: String? {
        didSet {
            if let accentColorHex {
                UserDefaults.standard.set(accentColorHex, forKey: Keys.accentColor)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.accentColor)
            }
        }
    }

    var accentColor: Color? {
        accentColorHex.map { Color(hex: $0) }
    }

    private enum Keys {
        static let appearanceMode = "theme.appearanceMode"
        static let accentColor = "theme.accentColorHex"
    }

    init() {
        appearanceMode = UserDefaults.standard.string(forKey: Keys.appearanceMode)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        accentColorHex = UserDefaults.standard.string(forKey: Keys.accentColor)
    }
}
