//
//  ContentView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct ContentView: View {
    let authService: AuthService
    
    var body: some View {
        HomeView(authService: authService)
    }
}
