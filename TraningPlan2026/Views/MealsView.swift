//
//  MealsView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct MealsView: View {
    @ObservedObject var viewModel: MealViewModel
    @State private var showingAddMeal = false
    @State private var showingNutritionProfile = false
    @State private var showingMealCalendar = false
    @State private var showingRecipes = false
    @State private var selectedTrackingDate = Date()
    @State private var hasAnimatedIn = false
    @Namespace private var cardTransition
    
    private var totalPlanMeals: Int {
        viewModel.mealPlan?.meals.count ?? 0
    }
    
    private var averageCalories: Int {
        let calories = viewModel.meals.compactMap { $0.calories }
        guard !calories.isEmpty else { return 0 }
        return calories.reduce(0, +) / calories.count
    }
    
    private var mealCountsByCategory: [Int] {
        let allMeals = viewModel.mealPlan?.meals ?? []
        let breakfast = allMeals.filter { $0.time == "Doručak" }.count
        let lunch = allMeals.filter { $0.time == "Ručak" }.count
        let dinner = allMeals.filter { $0.time == "Večera" }.count
        let other = allMeals.filter { !["Doručak", "Ručak", "Večera"].contains($0.time) }.count
        return [breakfast, lunch, dinner, other]
    }
    
    private var averageMacros: (protein: Double, carbs: Double, fat: Double) {
        guard let meals = viewModel.mealPlan?.meals, !meals.isEmpty else { return (0, 0, 0) }
        let protein = meals.compactMap(\.protein).reduce(0, +) / Double(max(1, meals.compactMap(\.protein).count))
        let carbs = meals.compactMap(\.carbs).reduce(0, +) / Double(max(1, meals.compactMap(\.carbs).count))
        let fat = meals.compactMap(\.fat).reduce(0, +) / Double(max(1, meals.compactMap(\.fat).count))
        return (protein, carbs, fat)
    }
    
    private var dayTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        viewModel.nutritionTotals(for: selectedTrackingDate)
    }
    
    private var dayRemaining: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        viewModel.nutritionRemaining(for: selectedTrackingDate)
    }
    
    private var dayMeals: [Meal] {
        viewModel.meals(for: selectedTrackingDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.meals.isEmpty && viewModel.mealPlan == nil {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            SkeletonCard(height: 86)
                            HStack(spacing: 12) {
                                SkeletonCard(height: 110)
                                SkeletonCard(height: 110)
                            }
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
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Plan Ishrane")
                                    .font(.subheadline)
                                    .foregroundStyle(AppDesign.textSecondary)
                                Text(viewModel.mealPlan?.name ?? "Dnevni obroci")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(AppDesign.textPrimary)
                            }
                            
                            nutritionTrackingSection
                            
                            if totalPlanMeals == 0 && viewModel.meals.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 42))
                                        .foregroundStyle(AppDesign.textSecondary)
                                    Text("Nema obroka")
                                        .font(.headline)
                                        .foregroundStyle(AppDesign.textPrimary)
                                    Text("Dodaj obrok klikom na + dugme.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppDesign.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .appCard()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                        .opacity(hasAnimatedIn ? 1 : 0)
                        .offset(y: hasAnimatedIn ? 0 : 12)
                    }
                    .onAppear {
                        guard !hasAnimatedIn else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            hasAnimatedIn = true
                        }
                    }
                }
                
            }
            .navigationTitle("Ishrana")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptics.medium()
                        showingAddMeal = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            Haptics.medium()
                            showingMealCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        Button {
                            Haptics.medium()
                            showingRecipes = true
                        } label: {
                            Image(systemName: "book.closed")
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        Button {
                            Haptics.medium()
                            showingNutritionProfile = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealView(viewModel: viewModel, initialDate: selectedTrackingDate)
            }
            .sheet(isPresented: $showingMealCalendar) {
                MealCalendarView(meals: viewModel.meals, selectedDate: $selectedTrackingDate)
            }
            .sheet(isPresented: $showingRecipes) {
                RecipesLibraryView(mealPlan: viewModel.mealPlan)
            }
            .sheet(isPresented: $showingNutritionProfile) {
                NutritionProfileView(viewModel: viewModel)
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
            .animation(.easeInOut(duration: 0.25), value: viewModel.meals.count)
        }
    }
    
    private var nutritionTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Praćenje Ishrane")
                .font(.title3.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack {
                Text(formattedTrackingDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.textPrimary)
                Spacer()
                Button("Otvori kalendar") {
                    Haptics.light()
                    showingMealCalendar = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppDesign.accent)
            }
            .appCard()
            
            HStack(spacing: 12) {
                DayMacroCard(title: "Preostalo kcal", value: "\(dayRemaining.calories)")
                DayMacroCard(title: "P/UH/M", value: "\(Int(dayRemaining.protein))/\(Int(dayRemaining.carbs))/\(Int(dayRemaining.fat))g")
            }
            
            if dayMeals.isEmpty {
                Text("Nema unosa za izabrani dan.")
                    .font(.subheadline)
                    .foregroundStyle(AppDesign.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                ForEach(dayMeals) { meal in
                    NavigationLink(
                        destination: MealDetailView(
                            meal: meal,
                            viewModel: viewModel,
                            transitionID: "meal-card-\(meal.id)",
                            cardNamespace: cardTransition
                        )
                    ) {
                        MealRowView(
                            meal: meal,
                            transitionID: "meal-card-\(meal.id)",
                            cardNamespace: cardTransition
                        )
                    }
                    .buttonStyle(PressableCardButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteMeal(meal) }
                        } label: {
                            Label("Obriši obrok", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
        
    private var formattedTrackingDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter.string(from: selectedTrackingDate)
    }
    
    @ViewBuilder
    private func mealCategorySection(title: String, icon: String, meals: [MealPlan.MealPlanItem]) -> some View {
        if meals.isEmpty {
            EmptyView()
        } else {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            ForEach(meals) { mealItem in
                NavigationLink(
                    destination: MealPlanDetailView(
                        mealItem: mealItem,
                        transitionID: "meal-plan-card-\(mealItem.id)",
                        cardNamespace: cardTransition
                    )
                ) {
                    MealPlanRowView(
                        mealItem: mealItem,
                        icon: icon,
                        transitionID: "meal-plan-card-\(mealItem.id)",
                        cardNamespace: cardTransition
                    )
                }
                .buttonStyle(PressableCardButtonStyle())
            }
        }
    }
}

struct MealRowView: View {
    let meal: Meal
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            iconBadge
            
            VStack(alignment: .leading, spacing: 6) {
                Text(meal.name)
                    .font(.headline)
                    .foregroundStyle(AppDesign.textPrimary)
                
                Text(meal.time)
                    .font(.subheadline)
                    .foregroundStyle(AppDesign.textSecondary)
                
                if !meal.foods.isEmpty {
                    Text("\(meal.foods.count) namirnica")
                        .font(.caption)
                        .foregroundStyle(AppDesign.accent)
                }
            }
            
            Spacer()
            
            HStack {
                if let calories = meal.calories {
                    Text("\(calories) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppDesign.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppDesign.cardSecondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppDesign.card)
                Image(systemName: "leaf.fill")
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
                        colors: [AppDesign.accent2, AppDesign.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
            Image(systemName: "fork.knife")
                .foregroundStyle(.white)
        }
        
        if let transitionID, let cardNamespace {
            badge.matchedGeometryEffect(id: transitionID, in: cardNamespace)
        } else {
            badge
        }
    }
}

struct MealPlanRowView: View {
    let mealItem: MealPlan.MealPlanItem
    var icon: String = "leaf.fill"
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            iconBadge
            
            VStack(alignment: .leading, spacing: 8) {
                Text(mealItem.name)
                    .font(.headline)
                    .foregroundStyle(AppDesign.textPrimary)
                
                HStack(spacing: 8) {
                    if let calories = mealItem.calories {
                        Text("\(calories) kcal")
                            .font(.caption)
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                    if let protein = mealItem.protein {
                        Text("P \(Int(protein))g")
                            .font(.caption)
                            .foregroundStyle(AppDesign.accent)
                    }
                    if let carbs = mealItem.carbs {
                        Text("UH \(Int(carbs))g")
                            .font(.caption)
                            .foregroundStyle(AppDesign.accent2)
                    }
                }
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
                Image(systemName: "fork.knife.circle.fill")
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
                        colors: [AppDesign.cardSecondary, AppDesign.accent2.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
            Image(systemName: icon)
                .foregroundStyle(.white)
        }
        
        if let transitionID, let cardNamespace {
            badge.matchedGeometryEffect(id: transitionID, in: cardNamespace)
        } else {
            badge
        }
    }
}

struct MealQuickCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppDesign.accent)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppDesign.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct DayMacroCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

struct MealCategoryBarsCard: View {
    let values: [Int]
    private let labels = ["Dor", "Ruč", "Več", "Ost"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Obroci po tipu")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack(alignment: .bottom, spacing: 8) {
                let maxValue = max(values.max() ?? 1, 1)
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(index == 0 ? AppDesign.accent : AppDesign.cardSecondary)
                            .frame(width: 16, height: max(8, CGFloat(value) / CGFloat(maxValue) * 56))
                        Text(labels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct MacroSplitCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var body: some View {
        let total = max(protein + carbs + fat, 1)
        let proteinRatio = protein / total
        let carbRatio = carbs / total
        let fatRatio = fat / total
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Makro odnos")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack(spacing: 5) {
                Capsule().fill(AppDesign.accent).frame(width: max(10, proteinRatio * 120), height: 10)
                Capsule().fill(AppDesign.accent2).frame(width: max(10, carbRatio * 120), height: 10)
                Capsule().fill(AppDesign.cardSecondary).frame(width: max(10, fatRatio * 120), height: 10)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                macroRow(color: AppDesign.accent, text: "P \(Int(protein))g")
                macroRow(color: AppDesign.accent2, text: "UH \(Int(carbs))g")
                macroRow(color: AppDesign.cardSecondary, text: "M \(Int(fat))g")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
    
    private func macroRow(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
        }
    }
}

struct MealPlanDetailView: View {
    let mealItem: MealPlan.MealPlanItem
    var transitionID: String? = nil
    var cardNamespace: Namespace.ID? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    transitionBadge
                    Text(mealItem.name)
                        .font(.largeTitle)
                        .bold()
                    
                    Text(mealItem.time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Divider()
                
                // Nutritivne vrednosti
                if mealItem.calories != nil || mealItem.protein != nil || mealItem.carbs != nil || mealItem.fat != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutritivne Vrednosti")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            if let calories = mealItem.calories {
                                HStack {
                                    Text("Kalorije:")
                                    Spacer()
                                    Text("\(calories) kcal")
                                        .bold()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            HStack(spacing: 12) {
                                if let protein = mealItem.protein {
                                    VStack {
                                        Text("\(Int(protein))g")
                                            .font(.title2)
                                            .bold()
                                        Text("Proteini")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                if let carbs = mealItem.carbs {
                                    VStack {
                                        Text("\(Int(carbs))g")
                                            .font(.title2)
                                            .bold()
                                        Text("Ugljeni Hidrati")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                if let fat = mealItem.fat {
                                    VStack {
                                        Text("\(Int(fat))g")
                                            .font(.title2)
                                            .bold()
                                        Text("Masti")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Sastojci
                if !mealItem.foods.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sastojci")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(mealItem.foods) { food in
                            HStack {
                                Text("• \(food.name)")
                                Spacer()
                                if let quantity = food.quantity {
                                    Text(quantity)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Recept
                if let recipe = mealItem.recipe {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recept")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(recipe)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(mealItem.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var transitionBadge: some View {
        let badge = ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppDesign.cardSecondary, AppDesign.accent2.opacity(0.85)],
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
}
