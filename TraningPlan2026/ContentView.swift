//
//  ContentView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct ContentView: View {
    let authService: AuthService
    let featureGate: FeatureGateService
    
    var body: some View {
        HomeView(authService: authService, featureGate: featureGate)
    }
}
