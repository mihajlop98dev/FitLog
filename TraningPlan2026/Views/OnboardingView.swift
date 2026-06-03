import SwiftUI

struct OnboardingView: View {
    let userId: String
    let featureGate: FeatureGateService
    @State private var step = 0
    @State private var name = ""
    @State private var age = ""
    @State private var gender = "Muški"
    @State private var weight = ""
    @State private var height = ""
    @State private var goal = ""
    @State private var level = "srednji"
    @State private var daysPerWeek = 4
    @State private var equipment: Set<String> = []
    @State private var injuries: Set<String> = []
    @State private var wantsNutrition = false
    @State private var mealsPerDay = 4
    @State private var allergies = ""
    @State private var motivation = ""
    @State private var isGenerating = false
    @State private var isComplete = false
    @State private var generatedWorkouts: [GeneratedWorkout] = []
    
    private let allEquipment = ["Teretana", "Kućni trening", "Bodyweight"]
    private let allInjuries = ["Donji deo leđa", "Kolena", "Ramena", "Vrat", "Zglobovi"]
    
    var body: some View {
        ZStack {
            AppDesign.background.ignoresSafeArea()
            
            if isComplete {
                planReadyView
            } else if isGenerating {
                generatingView
            } else {
                VStack(spacing: 0) {
                    progressBar
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            currentStepView
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }
                    
                    bottomButtons
                        .padding(24)
                }
            }
        }
    }
    
    private var progressBar: some View {
        let totalSteps = wantsNutrition ? 8 : 7
        return VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppDesign.accent)
                    }
                }
                Spacer()
                Text("Korak \(step + 1)/\(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(AppDesign.accent)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case 0: welcomeView
        case 1: basicInfoView
        case 2: goalView
        case 3: levelEquipmentView
        case 4: injuriesView
        case 5: nutritionView
        case 6: motivationView
        case 7: reviewView
        default: welcomeView
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            Image(systemName: "figure.run")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Dobrodošao u FitLog!")
                .font(.largeTitle.bold())
                .foregroundStyle(AppDesign.textPrimary)
                .multilineTextAlignment(.center)
            Text("Kreiraj svoj personalizovani plan treninga za 2 minuta.")
                .font(.body)
                .foregroundStyle(AppDesign.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var basicInfoView: some View {
        VStack(spacing: 16) {
            Text("Osnovni podaci")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            customField("Ime", text: $name)
            customField("Godine", text: $age, keyboard: .numberPad)
            
            Picker("Pol", selection: $gender) {
                Text("Muški").tag("Muški")
                Text("Ženski").tag("Ženski")
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: 12) {
                customField("Težina (kg)", text: $weight, keyboard: .decimalPad)
                customField("Visina (cm)", text: $height, keyboard: .numberPad)
            }
        }
    }
    
    private var goalView: some View {
        VStack(spacing: 16) {
            Text("Šta želiš da postigneš?")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            ForEach(["Dobijanje mase", "Mršavljenje", "Održavanje", "Definicija"], id: \.self) { g in
                Button {
                    goal = g
                } label: {
                    HStack {
                        Image(systemName: goal == g ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(goal == g ? AppDesign.accent : AppDesign.textSecondary)
                        Text(g)
                            .foregroundStyle(AppDesign.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(AppDesign.card.opacity(goal == g ? 0.5 : 0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var levelEquipmentView: some View {
        VStack(spacing: 16) {
            Text("Nivo iskustva")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            Picker("Nivo", selection: $level) {
                Text("Početnik").tag("pocetnik")
                Text("Srednji").tag("srednji")
                Text("Napredan").tag("napredan")
            }
            .pickerStyle(.segmented)
            
            Text("Dana nedeljno: \(daysPerWeek)")
                .foregroundStyle(AppDesign.textPrimary)
            Stepper("", value: $daysPerWeek, in: 2...6)
                .labelsHidden()
            
            Text("Gde treniraš?")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            ForEach(allEquipment, id: \.self) { item in
                Button {
                    if equipment.contains(item) { equipment.remove(item) }
                    else { equipment.insert(item) }
                } label: {
                    HStack {
                        Image(systemName: equipment.contains(item) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(equipment.contains(item) ? AppDesign.accent : AppDesign.textSecondary)
                        Text(item)
                            .foregroundStyle(AppDesign.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(AppDesign.card.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var injuriesView: some View {
        VStack(spacing: 16) {
            Text("Povrede ili ograničenja?")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            ForEach(allInjuries, id: \.self) { item in
                Button {
                    if injuries.contains(item) { injuries.remove(item) }
                    else { injuries.insert(item) }
                } label: {
                    HStack {
                        Image(systemName: injuries.contains(item) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(injuries.contains(item) ? AppDesign.accent : AppDesign.textSecondary)
                        Text(item)
                            .foregroundStyle(AppDesign.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(AppDesign.card.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                injuries = []
            } label: {
                Text("Nemam povreda")
                    .font(.subheadline)
                    .foregroundStyle(injuries.isEmpty ? AppDesign.accent : AppDesign.textSecondary)
            }
        }
    }
    
    private var nutritionView: some View {
        VStack(spacing: 16) {
            Text("Plan ishrane")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            Toggle("Želim plan ishrane", isOn: $wantsNutrition)
                .tint(AppDesign.accent)
            
            if wantsNutrition {
                Text("Obroka dnevno: \(mealsPerDay)")
                    .foregroundStyle(AppDesign.textPrimary)
                Stepper("", value: $mealsPerDay, in: 3...6)
                    .labelsHidden()
                
                customField("Alergije (opciono)", text: $allergies)
            }
        }
    }
    
    private var motivationView: some View {
        VStack(spacing: 16) {
            Text("Tvoj najveći motiv je...")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            TextEditor(text: $motivation)
                .frame(height: 120)
                .padding(8)
                .background(AppDesign.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(AppDesign.textPrimary)
            
            Text("Opciono - pomoći će ti da ostaneš dosledan")
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
        }
    }
    
    private var reviewView: some View {
        VStack(spacing: 16) {
            Text("Pregled profila")
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            
            reviewRow("Ime", value: name)
            reviewRow("Cilj", value: goal)
            reviewRow("Nivo", value: level)
            reviewRow("Treninga", value: "\(daysPerWeek)x nedeljno")
            reviewRow("Oprema", value: equipment.isEmpty ? "Nije izabrano" : equipment.joined(separator: ", "))
            reviewRow("Povrede", value: injuries.isEmpty ? "Nema" : injuries.joined(separator: ", "))
            if wantsNutrition {
                reviewRow("Ishrana", value: "Da (\(mealsPerDay) obroka)")
            }
        }
    }
    
    private var planReadyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Plan je spreman!")
                .font(.largeTitle.bold())
                .foregroundStyle(AppDesign.textPrimary)
            Text("7 dana besplatno • \(generatedWorkouts.count) treninga")
                .foregroundStyle(AppDesign.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(generatedWorkouts, id: \.day) { w in
                    HStack {
                        Image(systemName: "calendar.day.timeline.left")
                            .foregroundStyle(AppDesign.accent)
                        Text("Dan \(w.day): \(w.name)")
                            .foregroundStyle(AppDesign.textPrimary)
                        Spacer()
                        Text("\(w.exercises.count) vežbi")
                            .font(.caption)
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                    .padding(10)
                    .background(AppDesign.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            Button {
                
            } label: {
                Text("➤ Započni trening")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppDesign.accent)
            Text("Kreiram tvoj plan...")
                .foregroundStyle(AppDesign.textPrimary)
            Text("AI analizira tvoje podatke i bira najbolje vežbe")
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            Spacer()
        }
    }
    
    private var bottomButtons: some View {
        let totalSteps = wantsNutrition ? 8 : 7
        let isLastStep = step == totalSteps - 1
        let canProceed: Bool = {
            switch step {
            case 0: return true
            case 1: return !name.isEmpty && !age.isEmpty && !weight.isEmpty && !height.isEmpty
            case 2: return !goal.isEmpty
            case 3: return !equipment.isEmpty
            case 4: return true
            case 5: return true
            case 6: return true
            case 7: return true
            default: return false
            }
        }()
        
        return Button {
            if isLastStep {
                Task { await completeOnboarding() }
            } else {
                withAnimation { step += 1 }
            }
        } label: {
            Text(isLastStep ? "✓ Kreiraj plan" : "Nastavi ➤")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canProceed ? AnyShapeStyle(LinearGradient(colors: [AppDesign.accent, AppDesign.accent2], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.gray.opacity(0.3)))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(canProceed ? .black : AppDesign.textSecondary)
        }
        .disabled(!canProceed)
    }
    
    private func customField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppDesign.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(AppDesign.textPrimary)
    }
    
    private func reviewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppDesign.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundStyle(AppDesign.textPrimary)
            Spacer()
        }
        .padding(10)
        .background(AppDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func completeOnboarding() async {
        isGenerating = true
        
        let profile = UserProfileData(
            id: nil,
            user_id: userId,
            name: name,
            age: Int(age),
            gender: gender,
            weight_kg: Double(weight),
            height_cm: Double(height),
            goal: goal,
            level: level,
            days_per_week: daysPerWeek,
            equipment: Array(equipment),
            injuries: injuries.isEmpty ? nil : Array(injuries),
            has_nutrition: wantsNutrition,
            meals_per_day: wantsNutrition ? mealsPerDay : nil,
            allergies: allergies.isEmpty ? nil : allergies,
            motivation: motivation.isEmpty ? nil : motivation,
            trial_end_date: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7*24*3600)),
            feature_tier: "free",
            streak_count: nil,
            last_activity_date: nil
        )
        
        await featureGate.saveProfile(profile)
        
        let templateExercises = try? await SupabaseService(userId: userId).exerciseCatalog.fetchAllExercisesFromCatalog()
        let workouts = await PlanGeneratorService.generatePlan(
            profile: profile,
            templateExercises: templateExercises ?? []
        )
        
        for w in workouts {
            let workout = Workout(
                name: w.name,
                date: Calendar.current.date(byAdding: .day, value: w.day - 1, to: Date()) ?? Date(),
                exercises: w.exercises.map { Workout.Exercise(name: $0.name, sets: $0.sets, reps: $0.reps, weight: nil) },
                isCompleted: false,
                notes: nil,
                duration: nil
            )
            try? await SupabaseService(userId: userId).userWorkouts.saveWorkout(workout)
        }
        
        generatedWorkouts = workouts
        isGenerating = false
        isComplete = true
    }
}
