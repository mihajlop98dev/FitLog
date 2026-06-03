import SwiftUI

struct SuggestedWorkoutDetailView: View {
    struct ExerciseGuidePresentation: Identifiable {
        let id: String
        let title: String
        let howTo: String
        let commonMistakes: [String]
        let tips: [String]
    }
    
    let suggestedWorkout: WorkoutViewModel.SuggestedWorkout
    @ObservedObject var viewModel: WorkoutViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var weightInputs: [String: String]
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var localErrorMessage = ""
    @State private var activeGuide: ExerciseGuidePresentation?
    
    init(suggestedWorkout: WorkoutViewModel.SuggestedWorkout, viewModel: WorkoutViewModel) {
        self.suggestedWorkout = suggestedWorkout
        self.viewModel = viewModel
        
        var initialWeights: [String: String] = [:]
        for exercise in suggestedWorkout.exercises {
            if let weight = exercise.weight {
                initialWeights[exercise.id] = String(format: "%.1f", weight)
            } else {
                initialWeights[exercise.id] = ""
            }
        }
        _weightInputs = State(initialValue: initialWeights)
    }
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    
                    Text("Unesi kilaže")
                        .font(.title3.bold())
                        .foregroundStyle(AppDesign.textPrimary)
                    
                    ForEach(suggestedWorkout.exercises) { exercise in
                        exerciseWeightCard(exercise)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Napomene")
                            .font(.headline)
                            .foregroundStyle(AppDesign.textPrimary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 110)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(AppDesign.cardSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                    .appCard()
                    
                    Button {
                        saveCompletedWorkout()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSaving ? "Čuvanje..." : "Sačuvaj kao završen trening")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppDesign.accent)
                    .disabled(isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(suggestedWorkout.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Greška", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(localErrorMessage)
        }
        .sheet(item: $activeGuide) { guide in
            ExerciseGuideView(guide: guide)
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan treninga")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
            Text(suggestedWorkout.name)
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            Text("\(suggestedWorkout.exercises.count) vežbi • zasnovano na tvojoj istoriji")
                .font(.subheadline)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
    
    private func exerciseWeightCard(_ exercise: Workout.Exercise) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(AppDesign.textPrimary)
                    Button {
                        Haptics.light()
                        activeGuide = guideForExercise(exercise)
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(AppDesign.accent)
                    }
                    .buttonStyle(.plain)
                }
                if let sets = exercise.sets, let reps = exercise.reps {
                    Text("\(sets)x\(reps)")
                        .font(.caption)
                        .foregroundStyle(AppDesign.textSecondary)
                }
                if let explanation = exercise.notes, !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(explanation)
                        .font(.caption2)
                        .foregroundStyle(AppDesign.textSecondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            TextField("kg", text: bindingForExercise(id: exercise.id))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: 90)
                .background(AppDesign.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(AppDesign.textPrimary)
        }
        .appCard()
    }
    
    private func bindingForExercise(id: String) -> Binding<String> {
        Binding(
            get: { weightInputs[id, default: ""] },
            set: { weightInputs[id] = $0 }
        )
    }
    
    private func parsedWeights() -> [String: Double] {
        var parsed: [String: Double] = [:]
        for (id, rawValue) in weightInputs {
            let normalized = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            guard !normalized.isEmpty else { continue }
            if let value = Double(normalized) {
                parsed[id] = value
            }
        }
        return parsed
    }
    
    private func saveCompletedWorkout() {
        Haptics.medium()
        isSaving = true
        
        Task {
            let success = await viewModel.completeSuggestedWorkout(
                suggestedWorkout,
                weightsByExerciseId: parsedWeights(),
                notes: notes.isEmpty ? nil : notes
            )
            
            await MainActor.run {
                isSaving = false
                if success {
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.error()
                    localErrorMessage = viewModel.errorMessage ?? "Došlo je do greške pri čuvanju treninga."
                    showError = true
                }
            }
        }
    }
    
    private func guideForExercise(_ exercise: Workout.Exercise) -> ExerciseGuidePresentation {
        let howToText = {
            let raw = exercise.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                return "Za vežbu \"\(exercise.name)\" drži stabilan tempo, kontroliši pokret i fokusiraj se na pun opseg pokreta bez cimanja."
            }
            return raw
        }()
        
        return ExerciseGuidePresentation(
            id: exercise.id,
            title: exercise.name,
            howTo: howToText,
            commonMistakes: [
                "Prebrzo izvođenje bez kontrole pokreta.",
                "Prevelika težina koja narušava tehniku.",
                "Skraćen opseg pokreta i loše disanje."
            ],
            tips: [
                "Izdah na napor, udah pri vraćanju.",
                "Počni sa manjom težinom pa povećavaj postepeno.",
                "Drži trup stabilnim tokom cele serije."
            ]
        )
    }
}

private struct ExerciseGuideView: View {
    let guide: SuggestedWorkoutDetailView.ExerciseGuidePresentation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionCard(title: "Kako izvesti", content: guide.howTo)
                        bulletCard(title: "Najčešće greške", items: guide.commonMistakes)
                        bulletCard(title: "Saveti", items: guide.tips)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(guide.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zatvori") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sectionCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(AppDesign.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
    
    private func bulletCard(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundStyle(AppDesign.accent)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}
