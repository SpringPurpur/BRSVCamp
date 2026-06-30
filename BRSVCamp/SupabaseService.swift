import Foundation
import Supabase

// Singleton accesibil din orice fișier din target
let supabase = SupabaseClient(
    supabaseURL: URL(string: SupabaseConfig.url)!,
    supabaseKey: SupabaseConfig.anonKey
)
