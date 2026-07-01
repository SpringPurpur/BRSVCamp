import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem { Label("Hartă", systemImage: "map.fill") }

            BlogView()
                .tabItem { Label("Blog", systemImage: "doc.text.fill") }

            ExpensesView()
                .tabItem { Label("Cheltuieli", systemImage: "creditcard.fill") }

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
    }
}