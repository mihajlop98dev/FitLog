//
//  WorkoutsView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct WorkoutsView: View {
    enum TrainingSection: String, CaseIterable {
        case plan = "Plan treninga"
        case completed = "Završeni treninzi"
    }
    
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingAddWorkout = false
    @State private var showingCalendar = false
    @AppStorage("workouts.selectedSection") private var selectedSectionRaw: String = TrainingSection.plan.rawValue
    @State private var hasAnimatedIn = false
    @State private var deletingWorkoutId: String?
    @Namespace private var cardTransition
    
    private var selectedSection: TrainingSection {
        get { TrainingSection(rawValue: selectedSectionRaw) ?? .plan }
        nonmutating set { selectedSectionRaw = newValue.rawValue }
    }
    
    private var suggestedPlanWorkouts: [WorkoutViewModel.SuggestedWorkout] {
        viewModel.suggestedPlanWorkouts
    }
    
    private var completedWorkoutsSorted: [Workout] {
        viewModel.workouts
            .filter { $0.isCompleted }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppDesign.background.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.workoutPlan == nil && viewModel.workouts.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            SkeletonCard(height: 86)
                            SkeletonCard(height: 148)
                            HStack(spacing: 12) {
                                SkeletonCard(height: 110)
                                SkeletonCard(height: 110)
                            }
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonCard(height: 82)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                Color.clear
                                    .frame(height: 1)
                                    .id("workoutsTopAnchor")
                                
                                headerSection
                                
                                Picker("Sekcija", selection: Binding(
                                    get: { selectedSection },
                                    set: { newValue in
                                        Haptics.light()
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedSection = newValue
                                        }
                                    }
                                )) {
                                    ForEach(TrainingSection.allCases, id: \.self) { section in
                                        Text(section.rawValue).tag(section)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(AppDesign.accent)
                                
                                Text(selectedSection.rawValue)
                                    .font(.title3.bold())
                                    .foregroundStyle(AppDesign.textPrimary)
                                
                                if viewModel.isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(AppDesign.accent)
                                        Text("Učitavanje treninga...")
                                            .font(.subheadline)
                                            .foregroundStyle(AppDesign.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .appCard()
                                }
                                
                                Group {
                                    if selectedSection == .completed {
                                        if completedWorkoutsSorted.isEmpty {
                                            completedEmptyState
                                        } else {
                                            ForEach(Array(completedWorkoutsSorted.enumerated()), id: \.offset) { index, workout in
                                                completedWorkoutCard(for: workout)
                                                    .opacity(hasAnimatedIn ? 1 : 0)
                                                    .offset(y: hasAnimatedIn ? 0 : 14)
                                                    .animation(
                                                        .spring(response: 0.35, dampingFraction: 0.86)
                                                            .delay(Double(index) * 0.035),
                                                        value: hasAnimatedIn
                                                    )
                                            }
                                        }
                                    } else {
                                        if suggestedPlanWorkouts.isEmpty {
                                            planGenerationState
                                        } else {
                                            ForEach(Array(suggestedPlanWorkouts.enumerated()), id: \.element.id) { index, workoutItem in
                                                planWorkoutCard(for: workoutItem)
                                                    .opacity(hasAnimatedIn ? 1 : 0)
                                                    .offset(y: hasAnimatedIn ? 0 : 14)
                                                    .animation(
                                                        .spring(response: 0.35, dampingFraction: 0.86)
                                                            .delay(Double(index) * 0.035),
                                                        value: hasAnimatedIn
                                                    )
                                            }
                                        }
                                    }
                                }
                                .id(selectedSection.rawValue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 100)
                        }
                        .onAppear {
                            if !hasAnimatedIn {
                                selectedSection = .plan
                            }
                            guard !hasAnimatedIn else { return }
                            hasAnimatedIn = true
                        }
                        .onChange(of: selectedSectionRaw) { _, _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                proxy.scrollTo("workoutsTopAnchor", anchor: .top)
                            }
                        }
                    }
                }
                
            }
            .navigationTitle("Treninzi")
            .foregroundStyle(AppDesign.textPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptics.medium()
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.medium()
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCalendar) {
                WorkoutCalendarView(workouts: viewModel.workouts.filter { $0.isCompleted })
            }
            .alert("Greška", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: completedWorkoutsSorted.count + suggestedPlanWorkouts.count)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dobrodošao nazad")
                .font(.subheadline)
                .foregroundStyle(AppDesign.textSecondary)
            Text(viewModel.workoutPlan?.name ?? "Tvoj Trening Plan")
                .font(.largeTitle.bold())
                .foregroundStyle(AppDesign.textPrimary)
        }
    }
    
    private var completedEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 46))
                .foregroundStyle(AppDesign.textSecondary)
            Text("Nema treninga")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            Text("Dodaj trening klikom na + dugme.")
                .font(.subheadline)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
    
    private var planGenerationState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(AppDesign.accent)
            
            Text("Nema kreiranog plana")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            Text("Klikni dugme i učitaćemo sledeća 4 postojeća treninga (od dana 100 naviše).")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppDesign.textSecondary)
            
            Button {
                Haptics.medium()
                Task { await viewModel.generateSuggestedPlanWorkouts() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGeneratingPlan {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(viewModel.isGeneratingPlan ? "Učitavanje plana..." : "Učitaj sledeća 4 treninga")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppDesign.accent)
            .disabled(viewModel.isGeneratingPlan)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
    
    private func completedWorkoutCard(for workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(
                destination: WorkoutDetailView(
                    workout: workout,
                    viewModel: viewModel
                )
            ) {
                WorkoutCardView(
                    title: workout.name,
                    subtitle: formattedDate(workout.date),
                    detail: "\(workout.exercises.count) vežbi",
                    isPlanItem: false
                )
            }
            .buttonStyle(PressableCardButtonStyle())
            
            HStack {
                Spacer()
                Button(role: .destructive) {
                    Haptics.medium()
                    deletingWorkoutId = workout.id
                    Task {
                        await viewModel.deleteWorkout(workout)
                        await MainActor.run {
                            if deletingWorkoutId == workout.id {
                                deletingWorkoutId = nil
                            }
                        }
                    }
                } label: {
                    if deletingWorkoutId == workout.id {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.red)
                            Text("Brisanje...")
                                .font(.caption.weight(.semibold))
                        }
                    } else {
                        Label("Obriši", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(deletingWorkoutId == workout.id)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func planWorkoutCard(for workoutItem: WorkoutViewModel.SuggestedWorkout) -> some View {
        NavigationLink(
            destination: SuggestedWorkoutDetailView(
                suggestedWorkout: workoutItem,
                viewModel: viewModel
            )
        ) {
            WorkoutCardView(
                title: workoutItem.name,
                subtitle: "Plan treninga",
                detail: "\(workoutItem.exercises.count) vežbi",
                isPlanItem: true
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }
    
    @ViewBuilder
    private func workoutCard(for item: CombinedWorkoutItem) -> some View {
        if item.isFromPlan, let planItem = item.planItem, let planId = item.planId {
            NavigationLink(
                destination: WorkoutPlanDetailView(
                    workoutItem: planItem,
                    planId: planId,
                    transitionID: "workout-card-\(planItem.id)",
                    cardNamespace: cardTransition
                )
            ) {
                WorkoutCardView(
                    title: planItem.name,
                    subtitle: formattedDate(item.date),
                    detail: "Dan \(planItem.day)",
                    isPlanItem: true,
                    transitionID: "workout-card-\(planItem.id)",
                    cardNamespace: cardTransition
                )
            }
            .buttonStyle(PressableCardButtonStyle())
        } else if let workout = item.workout {
            NavigationLink(
                destination: WorkoutDetailView(
                    workout: workout,
                    viewModel: viewModel,
                    transitionID: "workout-card-\(workout.id)",
                    cardNamespace: cardTransition
                )
            ) {
                WorkoutCardView(
                    title: workout.name,
                    subtitle: formattedDate(workout.date),
                    detail: "\(workout.exercises.count) vežbi",
                    isPlanItem: false,
                    transitionID: "workout-card-\(workout.id)",
                    cardNamespace: cardTransition
                )
            }
            .buttonStyle(PressableCardButtonStyle())
            .contextMenu {
                Button(role: .destructive) {
                    Task { await viewModel.deleteWorkout(workout) }
                } label: {
                    Label("Obriši trening", systemImage: "trash")
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMM yyyy"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: date)
    }
}

struct WorkoutCardView: View {
    let title: String
    let subtitle: String
    let detail: String
    let isPlanItem: Bool
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil

    var body: some View {
        HStack(spacing: 12) {
            iconBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppDesign.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppDesign.textSecondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppDesign.accent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
        }
        .padding(12)
        .background(
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppDesign.card)
                Image(systemName: isPlanItem ? "figure.strengthtraining.functional" : "bolt.heart.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.06))
                    .padding(.trailing, 12)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var iconBadge: some View {
        let badge = ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isPlanItem ? [AppDesign.accent2, AppDesign.accent] : [AppDesign.cardSecondary, AppDesign.accent2.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
            Image(systemName: isPlanItem ? "calendar" : "checkmark.circle.fill")
                .foregroundStyle(.white)
        }
        
        if let transitionID, let cardNamespace {
            badge.matchedGeometryEffect(id: transitionID, in: cardNamespace)
        } else {
            badge
        }
    }
}


// Helper struct za kombinovanje treninga iz plana i user-ovih treninga
struct CombinedWorkoutItem: Identifiable {
    let id = UUID()
    let date: Date
    let planItem: WorkoutPlan.WorkoutPlanItem?
    let planId: String?
    let workout: Workout?
    
    var isFromPlan: Bool {
        planItem != nil
    }
}
