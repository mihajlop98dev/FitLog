import SwiftUI

struct RecipesLibraryView: View {
    let mealPlan: MealPlan?
    @Environment(\.dismiss) private var dismiss
    
    private var recipeMeals: [MealPlan.MealPlanItem] {
        (mealPlan?.meals ?? []).filter { item in
            guard let recipe = item.recipe else { return false }
            return !recipe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if recipeMeals.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 42))
                                    .foregroundStyle(AppDesign.textSecondary)
                                Text("Nema recepata")
                                    .font(.headline)
                                    .foregroundStyle(AppDesign.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .appCard()
                        } else {
                            ForEach(recipeMeals) { mealItem in
                                NavigationLink(
                                    destination: MealPlanDetailView(mealItem: mealItem)
                                ) {
                                    MealPlanRowView(mealItem: mealItem, icon: "book")
                                }
                                .buttonStyle(PressableCardButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Recepti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zatvori") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
