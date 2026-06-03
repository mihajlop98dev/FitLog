//
//  AddWorkoutView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI

struct AddWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var date = Date()
    @State private var isCompleted = false
    @State private var duration = ""
    @State private var notes = ""
    @State private var exercises: [Workout.Exercise] = []
    @State private var showingAddExercise = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Lista dostupnih vežbi iz kataloga (samo imena)
    private var allAvailableExercises: [String] {
        viewModel.availableExercises
    }
    
    // Automatski generiši ime treninga na osnovu najvećeg dana u planu
    private func generateWorkoutName() -> String {
        // Pronađi najveći dan u planu i dodaj 1
        if let plan = viewModel.workoutPlan, !plan.workouts.isEmpty {
            let maxDay = plan.workouts.map { $0.day }.max() ?? 0
            return "Dan \(maxDay + 1)"
        }
        // Ako nema plana, koristi broj postojećih treninga + 1
        let nextDay = viewModel.workouts.count + 1
        return "Dan \(nextDay)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Novi Trening")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Osnovne Informacije")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            WorkoutInputField(title: "Naziv treninga", text: $name)
                                .onAppear {
                                    if name.isEmpty {
                                        name = generateWorkoutName()
                                    }
                                }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Datum")
                                    .font(.caption)
                                    .foregroundStyle(AppDesign.textSecondary)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(AppDesign.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppDesign.cardSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            
                            Toggle(isOn: $isCompleted) {
                                Text("Završen")
                                    .foregroundStyle(AppDesign.textPrimary)
                            }
                            .tint(AppDesign.accent)
                            
                            WorkoutInputField(title: "Trajanje (minute)", text: $duration, keyboard: .numberPad)
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Vežbe")
                                    .font(.headline)
                                    .foregroundStyle(AppDesign.textPrimary)
                                Spacer()
                                Button {
                                    Haptics.light()
                                    showingAddExercise = true
                                } label: {
                                    Label("Dodaj", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppDesign.accent)
                                }
                            }
                            
                            if exercises.isEmpty {
                                Text("Nema dodatih vežbi.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppDesign.textSecondary)
                            } else {
                                ForEach(exercises) { exercise in
                                    HStack(alignment: .top, spacing: 8) {
                                        ExerciseRowView(exercise: exercise)
                                        Spacer()
                                        Button {
                                            Haptics.light()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                exercises.removeAll { $0.id == exercise.id }
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red.opacity(0.85))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Napomene")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(AppDesign.cardSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Dodaj Trening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Sačuvaj") {
                            Haptics.medium()
                            saveWorkout()
                        }
                        .disabled(name.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView(
                    viewModel: viewModel,
                    availableExercises: allAvailableExercises,
                    exercisesByCategory: viewModel.exercisesByCategory,
                    onSave: { exercise in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            exercises.append(exercise)
                        }
                    }
                )
            }
            .alert("Greška", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
            .animation(.easeInOut(duration: 0.2), value: exercises.count)
        }
    }
    
    private func saveWorkout() {
        guard !name.isEmpty else {
            errorMessage = "Ime treninga ne može biti prazno"
            showError = true
            return
        }
        
        isSaving = true
        errorMessage = ""
        
        let workout = Workout(
            name: name,
            date: date,
            exercises: exercises,
            isCompleted: isCompleted,
            notes: notes.isEmpty ? nil : notes,
            duration: Int(duration)
        )
        
        print("💾 Čuvanje treninga: \(workout.name) sa \(workout.exercises.count) vežbi")
        
        Task {
            await viewModel.addWorkout(workout)
            
            await MainActor.run {
                isSaving = false
                
                // Proveri da li je bilo greške
                if let error = viewModel.errorMessage {
                    Haptics.error()
                    errorMessage = error
                    showError = true
                    print("❌ Greška pri čuvanju: \(error)")
                } else {
                    // Uspešno sačuvano
                    Haptics.success()
                    print("✅ Trening uspešno sačuvan")
                    dismiss()
                }
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Workout.Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack {
                if let sets = exercise.sets, let reps = exercise.reps {
                    Text("\(sets)x\(reps)")
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
                
                if let weight = exercise.weight {
                    Text("\(String(format: "%.1f", weight)) kg")
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
                
                if let duration = exercise.duration {
                    Text("\(duration)s")
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
            }
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    let availableExercises: [String]
    let exercisesByCategory: [String: [String]]
    let onSave: (Workout.Exercise) -> Void
    
    @State private var selectedExerciseName: String?
    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var duration = ""
    @State private var notes = ""
    @State private var showingExercisePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Izaberi Vežbu")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            if !availableExercises.isEmpty {
                                Button {
                                    showingExercisePicker = true
                                } label: {
                                    HStack {
                                        Text(selectedExerciseName ?? "Izaberi vežbu iz kataloga")
                                            .foregroundStyle(selectedExerciseName == nil ? AppDesign.accent : AppDesign.textPrimary)
                                        Spacer()
                                        Image(systemName: selectedExerciseName != nil ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundStyle(selectedExerciseName != nil ? .green : AppDesign.textSecondary)
                                    }
                                    .padding(12)
                                    .background(AppDesign.cardSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                            
                            WorkoutInputField(title: "Ili unesi naziv vežbe ručno", text: $name)
                                .onChange(of: name) { _, newValue in
                                    if !newValue.isEmpty && selectedExerciseName != newValue {
                                        selectedExerciseName = nil
                                    }
                                }
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Detalji")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            WorkoutInputField(title: "Serije", text: $sets, keyboard: .numberPad)
                            WorkoutInputField(title: "Ponavljanja", text: $reps, keyboard: .numberPad)
                            WorkoutInputField(title: "Težina (kg)", text: $weight, keyboard: .decimalPad)
                            WorkoutInputField(title: "Trajanje (sekunde)", text: $duration, keyboard: .numberPad)
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Napomene")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(AppDesign.cardSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Nova Vežba")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dodaj") {
                        Haptics.medium()
                        saveExercise()
                    }
                    .disabled(exerciseName.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    exerciseNames: availableExercises,
                    exercisesByCategory: exercisesByCategory,
                    onSelect: { exerciseName in
                        selectedExerciseName = exerciseName
                        name = exerciseName
                        showingExercisePicker = false
                    }
                )
            }
        }
    }
    
    private var exerciseName: String {
        selectedExerciseName ?? name
    }
    
    private func saveExercise() {
        let exerciseName = self.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !exerciseName.isEmpty else { return }
        
        // Ako vežba nije u katalogu, dodaj je
        if !availableExercises.contains(exerciseName) {
            Task {
                await viewModel.addExerciseToCatalog(name: exerciseName)
            }
        }
        
        let exercise = Workout.Exercise(
            name: exerciseName,
            sets: Int(sets),
            reps: Int(reps),
            weight: Double(weight),
            duration: Int(duration),
            notes: notes.isEmpty ? nil : notes
        )
        Haptics.success()
        onSave(exercise)
        dismiss()
    }
}

struct ExercisePickerView: View {
    let exerciseNames: [String]
    let exercisesByCategory: [String: [String]]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showByCategory = true
    
    private var filteredExercises: [String] {
        if searchText.isEmpty {
            return exerciseNames
        }
        return exerciseNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredByCategory: [String: [String]] {
        if searchText.isEmpty {
            return exercisesByCategory
        }
        var filtered: [String: [String]] = [:]
        for (category, exercises) in exercisesByCategory {
            let filteredExercises = exercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
            if !filteredExercises.isEmpty {
                filtered[category] = filteredExercises
            }
        }
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            List {
                if showByCategory && !exercisesByCategory.isEmpty {
                    // Prikaži po kategorijama
                    ForEach(sortedCategories, id: \.self) { category in
                        if let exercises = filteredByCategory[category], !exercises.isEmpty {
                            Section(category) {
                                ForEach(exercises, id: \.self) { exerciseName in
                                    Button {
                                        onSelect(exerciseName)
                                    } label: {
                                        Text(exerciseName)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Prikaži sve (bez kategorija)
                    ForEach(filteredExercises, id: \.self) { exerciseName in
                        Button {
                            onSelect(exerciseName)
                        } label: {
                            Text(exerciseName)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Pretraži vežbe")
            .navigationTitle("Izaberi Vežbu")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppDesign.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showByCategory.toggle()
                    } label: {
                        Image(systemName: showByCategory ? "list.bullet" : "square.grid.2x2")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Otkaži") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var sortedCategories: [String] {
        let categories = Array(filteredByCategory.keys).sorted()
        // Sortiraj: prvo glavne kategorije, pa "Ostalo" na kraju
        let mainCategories = ["Noge", "Grudi", "Leđa", "Ramena", "Biceps", "Triceps", "Ruke", "Trbuh", "Kardio", "Celotelo"]
        var sorted: [String] = []
        for cat in mainCategories {
            if categories.contains(cat) {
                sorted.append(cat)
            }
        }
        for cat in categories {
            if !mainCategories.contains(cat) {
                sorted.append(cat)
            }
        }
        return sorted
    }
}

private struct WorkoutInputField: View {
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
    }
}
