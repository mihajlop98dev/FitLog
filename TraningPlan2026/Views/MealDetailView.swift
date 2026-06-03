//
//  MealDetailView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct MealDetailView: View {
    let meal: Meal
    @ObservedObject var viewModel: MealViewModel
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    
                    HStack(spacing: 12) {
                        MealMetricCard(icon: "fork.knife", title: "Namirnice", value: "\(meal.foods.count)")
                        MealMetricCard(icon: "flame.fill", title: "Kalorije", value: "\(meal.calories ?? 0)")
                        MealMetricCard(icon: "clock.fill", title: "Vreme", value: meal.time)
                    }
                    
                    if !meal.foods.isEmpty {
                        Text("Namirnice")
                            .font(.title3.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        ForEach(meal.foods) { food in
                            FoodDetailCard(food: food)
                        }
                    }
                    
                    if let notes = meal.notes, !notes.isEmpty {
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
        .navigationTitle("Obrok")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppDesign.accent.opacity(0.92), AppDesign.accent2.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 148)
            
            VStack(alignment: .leading, spacing: 8) {
                transitionBadge
                if let date = meal.date {
                    Text(shortDate(date).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Text(meal.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.white)
                Text(meal.time)
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
            Image(systemName: "fork.knife")
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

struct FoodDetailCard: View {
    let food: Meal.FoodItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(food.name)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack(spacing: 8) {
                if let quantity = food.quantity {
                    FoodPill(icon: "scalemass.fill", text: quantity)
                }
                
                if let calories = food.calories {
                    FoodPill(icon: "flame.fill", text: "\(calories) kcal")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct FoodPill: View {
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

private struct MealMetricCard: View {
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
