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
        let url = URL(string: "https://fduykeeoygffgxkvwmyl.supabase.co")!
        let key = "sb_publishable_najmruv4yCXU1Qp-tiyE4A_WYPMWxo5"
        
        let options = SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
        
        // Kreiraj Supabase klijent sa opt-in podešavanjem za novi Auth initial session behavior.
        supabase = SupabaseClient(supabaseURL: url, supabaseKey: key, options: options)
    }
}


