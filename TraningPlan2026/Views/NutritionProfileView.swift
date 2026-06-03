import SwiftUI

struct NutritionProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MealViewModel
    
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Dnevni ciljevi")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        NutritionInputField(title: "Kalorije (kcal)", text: $calories, keyboard: .numberPad)
                        NutritionInputField(title: "Protein (g)", text: $protein, keyboard: .decimalPad)
                        NutritionInputField(title: "Ugljeni hidrati (g)", text: $carbs, keyboard: .decimalPad)
                        NutritionInputField(title: "Masti (g)", text: $fat, keyboard: .decimalPad)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Profil Ishrane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sačuvaj") { save() }
                }
            }
        }
        .onAppear {
            calories = "\(viewModel.nutritionTargets.calories)"
            protein = "\(Int(viewModel.nutritionTargets.protein))"
            carbs = "\(Int(viewModel.nutritionTargets.carbs))"
            fat = "\(Int(viewModel.nutritionTargets.fat))"
        }
        .preferredColorScheme(.dark)
    }
    
    private func save() {
        let targets = NutritionTargets(
            calories: Int(calories) ?? viewModel.nutritionTargets.calories,
            protein: Double(protein) ?? viewModel.nutritionTargets.protein,
            carbs: Double(carbs) ?? viewModel.nutritionTargets.carbs,
            fat: Double(fat) ?? viewModel.nutritionTargets.fat
        )
        viewModel.saveNutritionTargets(targets)
        Haptics.success()
        dismiss()
    }
}

private struct NutritionInputField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppDesign.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(AppDesign.textPrimary)
        }
        .appCard()
    }
}
