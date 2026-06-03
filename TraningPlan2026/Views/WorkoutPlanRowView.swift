//
//  WorkoutPlanRowView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI
import Combine

struct WorkoutPlanRowView: View {
    let workoutItem: WorkoutPlan.WorkoutPlanItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workoutItem.name)
                    .font(.headline)
                Spacer()
                if let date = workoutItem.workoutDate {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Dan \(workoutItem.day)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutPlanDetailView: View {
    let workoutItem: WorkoutPlan.WorkoutPlanItem
    let planId: String
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    @StateObject private var viewModel: WorkoutPlanDetailViewModel
    
    init(workoutItem: WorkoutPlan.WorkoutPlanItem, planId: String, transitionID: String? = nil, cardNamespace: Namespace.ID? = nil) {
        self.workoutItem = workoutItem
        self.planId = planId
        self.transitionID = transitionID
        self.cardNamespace = cardNamespace
        _viewModel = StateObject(wrappedValue: WorkoutPlanDetailViewModel(workoutItem: workoutItem, planId: planId))
    }
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeader
                    
                    HStack(spacing: 12) {
                        DetailMetricPlanCard(icon: "calendar", title: "Dan", value: "\(workoutItem.day)")
                        DetailMetricPlanCard(icon: "dumbbell.fill", title: "Vežbe", value: "\(viewModel.exercises.count)")
                        DetailMetricPlanCard(icon: "book.fill", title: "Plan", value: "Program")
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Učitavanje vežbi...")
                            .tint(AppDesign.accent)
                            .foregroundStyle(AppDesign.textPrimary)
                            .frame(maxWidth: .infinity)
                            .appCard()
                    } else if viewModel.exercises.isEmpty {
                        Text("Nema vežbi")
                            .foregroundStyle(AppDesign.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appCard()
                    } else {
                        Text("Vežbe")
                            .font(.title3.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        ForEach(viewModel.exercises) { exercise in
                            ExerciseDetailCard(exercise: exercise)
                        }
                    }
                    
                    if let notes = workoutItem.notes, !notes.isEmpty {
                        Text("Napomene")
                            .font(.title3.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        Text(notes)
                            .foregroundStyle(AppDesign.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(workoutItem.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadExercises()
        }
    }
    
    private var detailHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppDesign.accent2.opacity(0.9), AppDesign.accent.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 148)
            
            VStack(alignment: .leading, spacing: 8) {
                transitionBadge
                Text((workoutItem.date ?? "Dan \(workoutItem.day)").uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(workoutItem.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.white)
                Text("Plan trening")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(16)
        }
    }
    
    @ViewBuilder
    private var transitionBadge: some View {
        let badge = ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppDesign.accent2, AppDesign.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
            Image(systemName: "calendar")
                .foregroundStyle(.white)
        }
        
        if let transitionID, let cardNamespace {
            badge.matchedGeometryEffect(id: transitionID, in: cardNamespace)
        } else {
            badge
        }
    }
}

@MainActor
class WorkoutPlanDetailViewModel: ObservableObject {
    @Published var exercises: [Workout.Exercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let workoutItem: WorkoutPlan.WorkoutPlanItem
    private let planId: String
    private let supabaseService = SupabaseService()
    
    init(workoutItem: WorkoutPlan.WorkoutPlanItem, planId: String) {
        self.workoutItem = workoutItem
        self.planId = planId
        // Ako vežbe već postoje (npr. iz cache-a), koristi ih
        if !workoutItem.exercises.isEmpty {
            self.exercises = workoutItem.exercises
        }
    }
    
    func loadExercises() async {
        // Ako vežbe već postoje, ne učitavaj ponovo
        guard exercises.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("📥 Učitavanje vežbi za trening \(workoutItem.id)...")
                exercises = try await supabaseService.fetchExercisesForWorkout(
                planId: planId,
                workoutId: workoutItem.id
            )
            print("✅ Učitano \(exercises.count) vežbi")
            isLoading = false
        } catch {
            errorMessage = "Failed to load exercises: \(error.localizedDescription)"
            isLoading = false
            print("❌ Error loading exercises: \(error)")
        }
    }
}

private struct DetailMetricPlanCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppDesign.accent)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}
