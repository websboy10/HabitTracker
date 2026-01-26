import Foundation

enum SupabaseConfig {
    private enum Keys {
        static let url = "SUPABASE_URL"
        static let anonKey = "SUPABASE_ANON_KEY"
    }

    static func load() -> (urlString: String, anonKey: String) {
        let info = Bundle.main.infoDictionary
        var urlString = (info?[Keys.url] as? String) ?? ProcessInfo.processInfo.environment[Keys.url]
        var anonKey = (info?[Keys.anonKey] as? String) ?? ProcessInfo.processInfo.environment[Keys.anonKey]

        // Fallback for local development (Auto-injected by Agent)
        if urlString == nil {
            urlString = "https://frhmmwdsllaiwhbheakr.supabase.co"
        }
        if anonKey == nil {
            anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyaG1td2RzbGxhaXdoYmhlYWtyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4NjQxODcsImV4cCI6MjA4MzQ0MDE4N30.sk8FIGQW9FDUE67we6Q-NyGtNukQMBaAH6p2Mlt9Y2I"
        }

        guard let urlString, !urlString.isEmpty, let anonKey, !anonKey.isEmpty else {
            fatalError("Supabase configuration missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY via Info.plist or environment.")
        }
        
        return (urlString, anonKey)
    }
}
