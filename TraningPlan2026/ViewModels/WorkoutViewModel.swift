//
//  WorkoutViewModel.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import Combine

@MainActor
class WorkoutViewModel: ObservableObject {
    struct SuggestedWorkout: Identifiable {
        let id: String
        let sourceWorkoutId: String
        let name: String
        let exercises: [Workout.Exercise]
    }

    @Published var workouts: [Workout] = []
    @Published var completedWorkouts: [Workout] = []
    @Published var workoutPlan: WorkoutPlan?
    @Published var suggestedPlanWorkouts: [SuggestedWorkout] = []
    @Published var isGeneratingPlan = false
    @Published var availableExercises: [String] = [] // Sve vežbe iz kataloga
    @Published var exercisesByCategory: [String: [String]] = [:] // Vežbe po kategorijama
    @Published var exerciseGuidesByName: [String: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var didLoadWorkouts = false
    @Published private(set) var didLoadWorkoutPlan = false
    @Published private(set) var didLoadExerciseCatalog = false
    
    var isInitialDataReady: Bool {
        didLoadWorkouts && didLoadWorkoutPlan && didLoadExerciseCatalog
    }
    
    private let supabaseService = SupabaseService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private let nextBatchStartIndexKey = "workouts.nextBatchStartIndex"
    
    deinit { loadTask?.cancel() }
    
    init() {
        loadWorkouts()
        loadWorkoutPlan()
        loadAvailableExercises()
        loadTask = Task { await loadPersistedPlanQueue() }
    }
    
    func loadWorkoutPlan() {
        didLoadWorkoutPlan = false
        // Prvo učitaj iz cache-a (brzo, odmah)
        if let cachedPlan = cacheService.getWorkoutPlan() {
            print("📦 Učitano iz cache-a")
            workoutPlan = cachedPlan
            isLoading = false
            didLoadWorkoutPlan = true
        } else {
            isLoading = true
        }
        
        // Zatim učitaj iz Supabase u background-u (ažuriraj cache)
        loadTask = Task { [weak self] in
            guard let self else { return }
            errorMessage = nil
            
            do {
                print("📥 Učitavanje workout plana iz Supabase...")
                let plans = try await supabaseService.fetchWorkoutPlans()
                
                guard !Task.isCancelled else { return }
                
                print("✅ Učitano \(plans.count) planova iz Supabase")
                
                if let plan = plans.first {
                    // Plan je već sortiran u SupabaseService po datumu (najnoviji prvo)
                    // Ne treba dodatno sortiranje, ali proverimo da li je ispravno
                    var sortedPlan = plan
                    sortedPlan.workouts.sort { workout1, workout2 in
                        guard let date1 = workout1.workoutDate, let date2 = workout2.workoutDate else {
                            // Ako nema datuma, sortiraj po danu (najveći dan prvo)
                            return workout1.day > workout2.day
                        }
                        // Sortiraj po datumu: najnoviji prvo (poslednji dan)
                        return date1 > date2
                    }
                    
                    workoutPlan = sortedPlan
                    // Sačuvaj u cache za brže učitavanje sledeći put
                    cacheService.saveWorkoutPlan(sortedPlan)
                    print("✅ Plan '\(sortedPlan.name)' sa \(sortedPlan.workouts.count) treninga (sortirano)")
                } else {
                    print("⚠️ Nema planova u Supabase")
                }
                guard !Task.isCancelled else { return }
                isLoading = false
                didLoadWorkoutPlan = true
            } catch {
                guard !Task.isCancelled else { return }
                let errorDetails: String
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        errorDetails = "Missing field '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    case .typeMismatch(let type, let context):
                        errorDetails = "Type mismatch for '\(type)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    case .valueNotFound(let type, let context):
                        errorDetails = "Missing value for '\(type)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    case .dataCorrupted(let context):
                        errorDetails = "Data corrupted: \(context.debugDescription)"
                    @unknown default:
                        errorDetails = "Decoding error: \(decodingError.localizedDescription)"
                    }
                } else {
                    errorDetails = error.localizedDescription
                }
                
                errorMessage = "Failed to load workout plan: \(errorDetails)"
                isLoading = false
                didLoadWorkoutPlan = true
                print("❌ Workout plan loading error: \(error)")
            }
        }
    }
    
    func loadWorkouts() {
        didLoadWorkouts = false
        errorMessage = nil
        
        if let cachedWorkouts = cacheService.getWorkouts() {
            print("📦 Učitani treninzi iz cache-a (\(cachedWorkouts.count))")
            workouts = cachedWorkouts
            completedWorkouts = cachedWorkouts.filter { $0.isCompleted }
            didLoadWorkouts = true
            isLoading = false
        } else {
            isLoading = true
        }
        
        print("📥 Učitavanje treninga...")
        supabaseService.listenToWorkouts { [weak self] workouts in
            Task { @MainActor in
                print("✅ Učitano \(workouts.count) treninga iz workouts tabele")
                // Svi treningi iz workouts tabele su završeni
                self?.workouts = workouts
                self?.completedWorkouts = workouts // Svi su završeni
                self?.cacheService.saveWorkouts(workouts)
                if let self {
                    await self.syncQueuedWorkoutNamesWithCompletedCount()
                }
                print("✅ \(self?.completedWorkouts.count ?? 0) završenih treninga")
                self?.isLoading = false
                self?.didLoadWorkouts = true
            }
        }
    }
    
    func addWorkout(_ workout: Workout) async {
        isLoading = true
        errorMessage = nil
        
        print("💾 ViewModel: Čuvanje treninga '\(workout.name)' sa \(workout.exercises.count) vežbi")
        
        do {
            try await supabaseService.saveWorkout(workout)
            print("✅ ViewModel: Trening uspešno sačuvan u Supabase")
            
            // Osveži listu treninga nakon dodavanja
            loadWorkouts()
            isLoading = false
            print("✅ ViewModel: Lista treninga osvežena")
        } catch {
            let errorMsg = "Failed to save workout: \(error.localizedDescription)"
            errorMessage = errorMsg
            isLoading = false
            print("❌ ViewModel: Greška pri čuvanju: \(errorMsg)")
            print("❌ ViewModel: Error details: \(error)")
        }
    }
    
    func updateWorkout(_ workout: Workout) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.saveWorkout(workout)
            // Osveži listu treninga nakon ažuriranja
            loadWorkouts()
            isLoading = false
        } catch {
            errorMessage = "Failed to update workout: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func deleteWorkout(_ workout: Workout) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteWorkout(workout)
            // Osveži listu treninga nakon brisanja
            loadWorkouts()
            isLoading = false
        } catch {
            errorMessage = "Failed to delete workout: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func toggleWorkoutCompletion(_ workout: Workout) async {
        var updatedWorkout = workout
        updatedWorkout.isCompleted.toggle()
        await updateWorkout(updatedWorkout)
    }
    
    // Učitaj sve vežbe iz kataloga
    func loadAvailableExercises() {
        didLoadExerciseCatalog = false
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                print("📥 Učitavanje vežbi iz kataloga...")
                availableExercises = try await supabaseService.fetchAllExercisesFromCatalog()
                guard !Task.isCancelled else { return }
                exercisesByCategory = try await supabaseService.fetchExercisesByCategory()
                guard !Task.isCancelled else { return }
                let rawGuides = try await supabaseService.fetchExerciseGuidesFromCatalog()
                exerciseGuidesByName = Dictionary(uniqueKeysWithValues: rawGuides.map { key, value in
                    (normalizedExerciseName(key), value)
                })
                print("✅ Učitano \(availableExercises.count) vežbi iz kataloga")
                print("✅ Učitano \(exercisesByCategory.count) kategorija")
                didLoadExerciseCatalog = true
            } catch {
                guard !Task.isCancelled else { return }
                print("⚠️ Greška pri učitavanju vežbi iz kataloga: \(error)")
                availableExercises = []
                exercisesByCategory = [:]
                exerciseGuidesByName = [:]
                didLoadExerciseCatalog = true
            }
        }
    }
    
    // Dodaj novu vežbu u katalog
    func addExerciseToCatalog(name: String) async {
        do {
            try await supabaseService.addExerciseToCatalog(name: name)
            // Osveži listu vežbi
            loadAvailableExercises()
        } catch {
            print("⚠️ Greška pri dodavanju vežbe u katalog: \(error)")
        }
    }
    
    func completeSuggestedWorkout(
        _ suggestedWorkout: SuggestedWorkout,
        weightsByExerciseId: [String: Double],
        notes: String?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        var finalizedExercises = suggestedWorkout.exercises
        for index in finalizedExercises.indices {
            let id = finalizedExercises[index].id
            if let customWeight = weightsByExerciseId[id] {
                finalizedExercises[index].weight = customWeight
            }
        }
        
        let completedWorkout = Workout(
            name: suggestedWorkout.name,
            date: Date(),
            exercises: finalizedExercises,
            isCompleted: true,
            notes: notes,
            duration: nil
        )
        
        do {
            try await supabaseService.saveWorkout(completedWorkout)
            try await supabaseService.deleteTrainingPlanQueueWorkout(id: suggestedWorkout.id)
            suggestedPlanWorkouts.removeAll { $0.id == suggestedWorkout.id }
            workouts.insert(completedWorkout, at: 0)
            completedWorkouts = workouts.filter { $0.isCompleted }
            loadWorkouts()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func generateSuggestedPlanWorkouts() async {
        guard suggestedPlanWorkouts.isEmpty else { return }
        
        isGeneratingPlan = true
        errorMessage = nil
        
        // Kratak loading da korisnik vidi da se plan pravi.
        try? await Task.sleep(nanoseconds: 550_000_000)
        
        suggestedPlanWorkouts = await generateNextBatchWorkouts()
        if suggestedPlanWorkouts.isEmpty {
            errorMessage = "Nema dostupnih treninga za prikaz."
        }
        
        isGeneratingPlan = false
    }
    
    func refreshAllData() {
        loadWorkouts()
        loadWorkoutPlan()
        loadAvailableExercises()
        Task { await loadPersistedPlanQueue() }
    }
    
    private func generateNextBatchWorkouts() async -> [SuggestedWorkout] {
        let batchSize = 4
        let sourceWorkouts = orderedSourceWorkoutsStartingFromDay100()
        guard !sourceWorkouts.isEmpty else { return [] }
        
        let remoteStartIndex = (try? await supabaseService.fetchTrainingPlanProgressIndex())
        let startIndex = (remoteStartIndex ?? nextBatchStartIndex()) % sourceWorkouts.count
        let selected = (0..<batchSize).map { offset in
            sourceWorkouts[(startIndex + offset) % sourceWorkouts.count]
        }
        
        let nextIndex = (startIndex + batchSize) % sourceWorkouts.count
        saveNextBatchStartIndex(nextIndex)
        
        let startingNumber = completedWorkouts.count
        let queueBatch = selected.enumerated().map { offset, workout in
            SuggestedWorkout(
                id: "queue-\(UUID().uuidString)",
                sourceWorkoutId: workout.id,
                name: "\(startingNumber + offset + 1)",
                exercises: attachGuides(to: workout.exercises)
            )
        }
        
        do {
            let rows = queueBatch.enumerated().map { offset, workout in
                TrainingQueueWorkout(
                    id: workout.id,
                    sourceWorkoutId: workout.sourceWorkoutId,
                    name: workout.name,
                    position: offset + 1,
                    exercises: workout.exercises
                )
            }
            try await supabaseService.replaceTrainingPlanQueue(with: rows)
            try await supabaseService.saveTrainingPlanProgressIndex(nextIndex)
        } catch {
            errorMessage = "Greška pri čuvanju plana treninga: \(error.localizedDescription)"
        }
        
        return queueBatch
    }
    
    private func orderedSourceWorkoutsStartingFromDay100() -> [Workout] {
        guard let planWorkouts = workoutPlan?.workouts, !planWorkouts.isEmpty else {
            // Fallback ako plan metadata nije dostupan.
            let sortedByDate = workouts.sorted { $0.date < $1.date }
            return Array(sortedByDate.dropFirst(min(99, max(0, sortedByDate.count - 1))))
        }
        
        let byId = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        let filteredPlanItems = planWorkouts
            .filter { $0.day >= 100 }
            .sorted { $0.day < $1.day }
        
        return filteredPlanItems.compactMap { item in
            if let fullWorkout = byId[item.id] {
                return fullWorkout
            }
            // Ako iz nekog razloga nema učitanog workout-a, vrati laganu fallback verziju.
            return Workout(
                id: item.id,
                name: item.name,
                date: item.workoutDate ?? Date(),
                exercises: item.exercises,
                isCompleted: false,
                notes: item.notes,
                duration: nil
            )
        }
    }
    
    private func attachGuides(to exercises: [Workout.Exercise]) -> [Workout.Exercise] {
        var usedNames = Set<String>()
        return exercises.compactMap { exercise in
            let key = normalizedExerciseName(exercise.name)
            if usedNames.contains(key) {
                return nil
            }
            usedNames.insert(key)
            
            var updated = exercise
            if updated.notes == nil || updated.notes?.isEmpty == true {
                updated.notes = guideForExercise(named: updated.name)
            }
            return updated
        }
    }
    
    private func nextBatchStartIndex() -> Int {
        UserDefaults.standard.integer(forKey: nextBatchStartIndexKey)
    }
    
    private func saveNextBatchStartIndex(_ value: Int) {
        UserDefaults.standard.set(max(0, value), forKey: nextBatchStartIndexKey)
    }
    
    private func loadPersistedPlanQueue() async {
        do {
            let queueRows = try await supabaseService.fetchTrainingPlanQueue()
            suggestedPlanWorkouts = queueRows
                .sorted { $0.position < $1.position }
                .map { row in
                    SuggestedWorkout(
                        id: row.id,
                        sourceWorkoutId: row.sourceWorkoutId,
                        name: row.name,
                        exercises: attachGuides(to: row.exercises)
                    )
                }
            await syncQueuedWorkoutNamesWithCompletedCount()
        } catch {
            // Queue nije kritičan za učitavanje aplikacije, samo evidentiraj.
            print("⚠️ Greška pri učitavanju queue plana: \(error)")
        }
    }
    
    private func syncQueuedWorkoutNamesWithCompletedCount() async {
        guard !suggestedPlanWorkouts.isEmpty else { return }
        
        let renamedQueue = suggestedPlanWorkouts.enumerated().map { index, workout in
            SuggestedWorkout(
                id: workout.id,
                sourceWorkoutId: workout.sourceWorkoutId,
                name: "\(completedWorkouts.count + index + 1)",
                exercises: workout.exercises
            )
        }
        
        let namesChanged = zip(suggestedPlanWorkouts, renamedQueue).contains { old, new in
            old.name != new.name
        }
        guard namesChanged else { return }
        
        suggestedPlanWorkouts = renamedQueue
        
        let rows = renamedQueue.enumerated().map { offset, workout in
            TrainingQueueWorkout(
                id: workout.id,
                sourceWorkoutId: workout.sourceWorkoutId,
                name: workout.name,
                position: offset + 1,
                exercises: workout.exercises
            )
        }
        
        do {
            try await supabaseService.replaceTrainingPlanQueue(with: rows)
        } catch {
            print("⚠️ Greška pri ažuriranju imena queue treninga: \(error)")
        }
    }
    
    private func normalizedExerciseName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
    
    private func guideForExercise(named exerciseName: String) -> String? {
        exerciseGuidesByName[normalizedExerciseName(exerciseName)]
    }
    
}
