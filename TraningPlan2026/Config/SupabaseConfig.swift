//
//  SupabaseConfig.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let supabase: SupabaseClient
    
    private init() {
        let url = URL(string: "https://bypxfobpzzmokkejxlxd.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5cHhmb2Jwenptb2trZWp4bHhkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MDIwMzIsImV4cCI6MjA5NjA3ODAzMn0.NZWhMAXPRYp6WjVgYF_WfrmXSYemjpJqVvioDgaemD4"
        
        let options = SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
        
        // Kreiraj Supabase klijent sa opt-in podešavanjem za novi Auth initial session behavior.
        supabase = SupabaseClient(supabaseURL: url, supabaseKey: key, options: options)
    }
}


