//
//  WorkoutDetailView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @ObservedObject var viewModel: WorkoutViewModel
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeader
                    
                    HStack(spacing: 12) {
                        DetailMetricCard(icon: "clock.fill", title: "Trajanje", value: "\(workout.duration ?? 0) min")
                        DetailMetricCard(icon: "dumbbell.fill", title: "Vežbe", value: "\(workout.exercises.count)")
                        DetailMetricCard(icon: "calendar", title: "Datum", value: shortDate(workout.date))
                    }
                    
                    if !workout.exercises.isEmpty {
                        Text("Vežbe")
                            .font(.title3.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        ForEach(workout.exercises) { exercise in
                            ExerciseDetailCard(exercise: exercise)
                        }
                    }
                    
                    if let notes = workout.notes, !notes.isEmpty {
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
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Trening")
        .navigationBarTitleDisplayMode(.inline)
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
                .frame(height: 152)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    transitionBadge
                    Text(shortDate(workout.date).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Button {
                        Task { await viewModel.toggleWorkoutCompletion(workout) }
                    } label: {
                        Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                
                Text(workout.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.white)
                
                Text(workout.isCompleted ? "Završen trening" : "Aktivan trening")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.9))
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
            Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(.white)
        }
        
        if let transitionID, let cardNamespace {
            badge.matchedGeometryEffect(id: transitionID, in: cardNamespace)
        } else {
            badge
        }
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMM yyyy"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: date)
    }
}

struct ExerciseDetailCard: View {
    let exercise: Workout.Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack(spacing: 8) {
                if let sets = exercise.sets, let reps = exercise.reps {
                    ExercisePill(icon: "repeat", text: "\(sets)x\(reps)")
                }
                if let weight = exercise.weight {
                    ExercisePill(icon: "scalemass.fill", text: "\(String(format: "%.1f", weight)) kg")
                }
                if let duration = exercise.duration {
                    ExercisePill(icon: "clock.fill", text: "\(duration)s")
                }
            }
            
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct ExercisePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppDesign.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppDesign.cardSecondary)
        .clipShape(Capsule())
    }
}

private struct DetailMetricCard: View {
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
