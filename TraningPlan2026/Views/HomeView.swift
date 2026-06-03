//
//  HomeView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct HomeView: View {
    let authService: AuthService
    let featureGate: FeatureGateService
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @StateObject private var mealViewModel = MealViewModel()
    @StateObject private var progressViewModel = BodyProgressViewModel()
    @StateObject private var coachChatViewModel = CoachChatViewModel()
    @State private var selectedTab = 0
    @State private var isBootstrapping = true
    
    private var shouldShowStartupOverlay: Bool {
        isBootstrapping &&
        workoutViewModel.workouts.isEmpty &&
        workoutViewModel.workoutPlan == nil &&
        mealViewModel.meals.isEmpty &&
        mealViewModel.mealPlan == nil
    }
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .task { await waitForInitialData() }
        .task { await refreshNotifications() }
        .task { evaluateCoachInactivityPrompt() }
        .onChange(of: workoutViewModel.isInitialDataReady) { _, _ in
            evaluateBootstrapState()
        }
        .onChange(of: mealViewModel.isInitialDataReady) { _, _ in
            evaluateBootstrapState()
        }
        .onChange(of: workoutViewModel.workouts.count) { _, _ in
            Task { await refreshNotifications() }
            evaluateCoachInactivityPrompt()
        }
        .onChange(of: mealViewModel.meals.count) { _, _ in
            Task { await refreshNotifications() }
            evaluateCoachInactivityPrompt()
        }
        .onChange(of: progressViewModel.entries.count) { _, _ in
            Task { await refreshNotifications() }
            evaluateCoachInactivityPrompt()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            workoutViewModel.refreshAllData()
            mealViewModel.refreshAllData()
            Task { await refreshNotifications() }
            evaluateCoachInactivityPrompt()
        }
        .preferredColorScheme(.dark)
        .alert("Greška", isPresented: Binding(
            get: { workoutViewModel.errorMessage != nil || mealViewModel.errorMessage != nil || progressViewModel.errorMessage != nil },
            set: { if !$0 { workoutViewModel.errorMessage = nil; mealViewModel.errorMessage = nil; progressViewModel.errorMessage = nil } }
        )) {
            Text(workoutViewModel.errorMessage ?? mealViewModel.errorMessage ?? progressViewModel.errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            if shouldShowStartupOverlay {
                AppStartupLoadingView()
            } else {
                AppDesign.background.ignoresSafeArea()
                
                Group {
                    if selectedTab == 0 {
                        HomeDashboardView(
                            workoutViewModel: workoutViewModel,
                            mealViewModel: mealViewModel,
                            progressViewModel: progressViewModel,
                            coachChatViewModel: coachChatViewModel
                        )
                    } else if selectedTab == 1 {
                        WorkoutsView(viewModel: workoutViewModel)
                        } else if selectedTab == 2 {
                            if featureGate.hasNutrition {
                                MealsView(viewModel: mealViewModel)
                            } else {
                                VStack {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 42))
                                        .foregroundStyle(AppDesign.textSecondary)
                                    Text("Ishrana nije aktivirana")
                                        .font(.headline)
                                        .foregroundStyle(AppDesign.textPrimary)
                                    Text("Nadogradi u profilu")
                                        .font(.subheadline)
                                        .foregroundStyle(AppDesign.textSecondary)
                                    Spacer()
                                }
                            }
                        } else if selectedTab == 3 {
                            BodyProgressView(viewModel: progressViewModel)
                        } else {
                            ProfileView(authService: authService, featureGate: featureGate)
                        }
                    }
                    
                    CustomBottomBar(selectedTab: $selectedTab, hasNutrition: featureGate.hasNutrition)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background(Color.clear)
                }
            }
        }
    
    private func waitForInitialData() async {
        let start = Date()
        while isBootstrapping {
            if workoutViewModel.isInitialDataReady && mealViewModel.isInitialDataReady {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBootstrapping = false
                }
                return
            }
            
            // Fallback da se UI ne blokira zauvek u slučaju loše mreže.
            if Date().timeIntervalSince(start) > 8 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBootstrapping = false
                }
                return
            }
            
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
    }
    
    private func evaluateBootstrapState() {
        guard isBootstrapping else { return }
        if workoutViewModel.isInitialDataReady && mealViewModel.isInitialDataReady {
            withAnimation(.easeInOut(duration: 0.2)) {
                isBootstrapping = false
            }
        }
    }
    
    private func refreshNotifications() async {
        await NotificationService.shared.refreshNotifications(
            workouts: workoutViewModel.workouts,
            meals: mealViewModel.meals,
            progressEntries: progressViewModel.entries
        )
    }
    
    private func evaluateCoachInactivityPrompt() {
        coachChatViewModel.evaluateInactivityAndPromptIfNeeded(
            workouts: workoutViewModel.workouts,
            meals: mealViewModel.meals,
            progressEntries: progressViewModel.entries
        )
    }
}

private struct AppStartupLoadingView: View {
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(AppDesign.accent)
                    .scaleEffect(1.2)
                Text("Učitavanje podataka...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.textSecondary)
            }
        }
    }
}

private struct CustomBottomBar: View {
    @Binding var selectedTab: Int
    let hasNutrition: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            tabButton(index: 0, title: "Home", icon: "house.fill")
            tabButton(index: 1, title: "Treninzi", icon: "figure.run")
            if hasNutrition {
                tabButton(index: 2, title: "Ishrana", icon: "fork.knife")
            }
            tabButton(index: hasNutrition ? 3 : 2, title: "Napredak", icon: "chart.line.uptrend.xyaxis")
            tabButton(index: hasNutrition ? 4 : 3, title: "Profil", icon: "person.fill")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppDesign.card.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func tabButton(index: Int, title: String, icon: String) -> some View {
        Button {
            if selectedTab != index {
                Haptics.light()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(selectedTab == index ? Color.black : AppDesign.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        selectedTab == index
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [AppDesign.accent, AppDesign.accent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                    )
            )
        }
        .accessibilityLabel(title)
        .buttonStyle(.plain)
    }
}
