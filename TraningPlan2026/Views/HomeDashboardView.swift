import SwiftUI

struct HomeDashboardView: View {
    enum DayPreset: String, CaseIterable {
        case today = "Danas"
        case yesterday = "Juče"
        case dayBefore = "Prekjuče"
    }
    
    @ObservedObject var workoutViewModel: WorkoutViewModel
    @ObservedObject var mealViewModel: MealViewModel
    @ObservedObject var progressViewModel: BodyProgressViewModel
    @ObservedObject var coachChatViewModel: CoachChatViewModel
    @State private var selectedPreset: DayPreset = .today
    @State private var selectedDate = Date()
    @State private var showingCoachChat = false
    
    private var completedThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return workoutViewModel.workouts
            .filter { $0.isCompleted }
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .count
    }
    
    private var weekGoal: Int { 4 }
    
    private var weeklyProgress: Double {
        min(Double(completedThisWeek) / Double(max(weekGoal, 1)), 1.0)
    }
    
    private var remainingNutrition: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        mealViewModel.nutritionRemaining(for: selectedDate)
    }
    
    private var dailyTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        mealViewModel.nutritionTotals(for: selectedDate)
    }
    
    private var targets: NutritionTargets {
        mealViewModel.nutritionTargets
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dobrodošao")
                                .font(.subheadline)
                                .foregroundStyle(AppDesign.textSecondary)
                            Text("Tvoj pregled")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        
                        WorkoutWeekHeroCard(
                            completed: completedThisWeek,
                            goal: weekGoal,
                            progress: weeklyProgress
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preostali unos za dan")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            HStack(spacing: 8) {
                                ForEach(DayPreset.allCases, id: \.self) { preset in
                                    Button {
                                        Haptics.light()
                                        selectedPreset = preset
                                        selectedDate = date(for: preset)
                                    } label: {
                                        Text(preset.rawValue)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(selectedPreset == preset ? Color.black : AppDesign.textPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(
                                                        selectedPreset == preset
                                                        ? AnyShapeStyle(
                                                            LinearGradient(
                                                                colors: [AppDesign.accent, AppDesign.accent2],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                        : AnyShapeStyle(AppDesign.cardSecondary)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack(spacing: 10) {
                                HomeMacroCell(title: "kcal", value: "\(remainingNutrition.calories)")
                                HomeMacroCell(title: "P", value: "\(Int(remainingNutrition.protein))g")
                                HomeMacroCell(title: "UH", value: "\(Int(remainingNutrition.carbs))g")
                                HomeMacroCell(title: "M", value: "\(Int(remainingNutrition.fat))g")
                            }
                            
                            let totalConsumed = dailyTotals.protein + dailyTotals.carbs + dailyTotals.fat
                            let totalTarget = max(targets.protein + targets.carbs + targets.fat, 1)
                            let dayPercent = Int((min(totalConsumed / totalTarget, 1) * 100).rounded())
                            
                            Text("Dnevni unos makroa: \(dayPercent)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppDesign.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppDesign.cardSecondary)
                                .clipShape(Capsule())
                            
                            VStack(spacing: 8) {
                                NutritionProgressRow(
                                    title: "Kalorije",
                                    consumed: Double(dailyTotals.calories),
                                    target: Double(max(targets.calories, 1))
                                )
                                NutritionProgressRow(
                                    title: "Protein",
                                    consumed: dailyTotals.protein,
                                    target: max(targets.protein, 1)
                                )
                                NutritionProgressRow(
                                    title: "Ugljeni hidrati",
                                    consumed: dailyTotals.carbs,
                                    target: max(targets.carbs, 1)
                                )
                                NutritionProgressRow(
                                    title: "Masti",
                                    consumed: dailyTotals.fat,
                                    target: max(targets.fat, 1)
                                )
                            }
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCoachChat = true
                    } label: {
                        Image(systemName: "message.fill")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                    .accessibilityLabel("Otvori chat sa trenerom")
                }
            }
            .sheet(isPresented: $showingCoachChat) {
                CoachChatView(
                    viewModel: coachChatViewModel,
                    workouts: workoutViewModel.workouts,
                    meals: mealViewModel.meals,
                    progressEntries: progressViewModel.entries
                )
            }
        }
    }
    
    private func date(for preset: DayPreset) -> Date {
        let calendar = Calendar.current
        switch preset {
        case .today:
            return Date()
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .dayBefore:
            return calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        }
    }
}

private struct WorkoutWeekHeroCard: View {
    let completed: Int
    let goal: Int
    let progress: Double
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(AppDesign.cardSecondary, lineWidth: 12)
                    .frame(width: 112, height: 112)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 112, height: 112)
                
                VStack(spacing: 2) {
                    Text("\(completed)/\(goal)")
                        .font(.title3.bold())
                        .foregroundStyle(AppDesign.textPrimary)
                    Text("treninga")
                        .font(.caption2)
                        .foregroundStyle(AppDesign.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Nedeljni trening cilj")
                    .font(.headline)
                    .foregroundStyle(AppDesign.textPrimary)
                Text("Odradio si \(completed) od \(goal) treninga ove nedelje.")
                    .font(.subheadline)
                    .foregroundStyle(AppDesign.textSecondary)
                let safeTotal = Double(max(goal, 1))
                let safeValue = min(max(Double(completed), 0), safeTotal)
                ProgressView(value: safeValue, total: safeTotal)
                    .tint(AppDesign.accent)
            }
        }
        .appCard()
    }
}

private struct NutritionProgressRow: View {
    let title: String
    let consumed: Double
    let target: Double
    
    private var progress: Double {
        min(max(consumed / max(target, 1), 0), 1)
    }
    
    private var percentage: Int {
        Int((progress * 100).rounded())
    }
    
    private var progressTint: Color {
        let ratio = consumed / max(target, 1)
        if ratio >= 1.0 { return .green }
        if ratio >= 0.8 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
                Spacer()
                Text("\(Int(consumed))/\(Int(target))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.textPrimary)
                Text("\(percentage)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(progressTint)
                    .clipShape(Capsule())
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppDesign.cardSecondary)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(progressTint)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct HomeMacroCell: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppDesign.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppDesign.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
