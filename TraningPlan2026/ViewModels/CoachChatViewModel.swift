import Foundation
import Combine

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published var messages: [CoachChatMessage] = []
    @Published var isSending = false
    
    private let messagesKey = "coach.chat.messages"
    private let lastInactivityPromptKey = "coach.chat.lastInactivityPromptDate"
    
    init() {
        loadMessages()
    }
    
    func sendUserMessage(
        _ text: String,
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(.init(sender: .user, text: trimmed))
        saveMessages()
        
        isSending = true
        let context = buildContext(workouts: workouts, meals: meals, progressEntries: progressEntries)
        
        let ai = await CoachAIService.generateReply(
            userMessage: trimmed,
            workoutsThisWeek: context.workoutsThisWeek,
            mealsToday: context.mealsToday,
            inactiveDays: context.inactiveDays,
            recentMessages: messages
        )
        
        let response = ai ?? CoachAIService.fallbackReply(for: trimmed, inactiveDays: context.inactiveDays)
        messages.append(.init(sender: .coach, text: response))
        saveMessages()
        isSending = false
    }
    
    func evaluateInactivityAndPromptIfNeeded(
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) {
        let context = buildContext(workouts: workouts, meals: meals, progressEntries: progressEntries)
        guard let inactiveDays = context.inactiveDays, inactiveDays >= 2 else { return }
        
        let dayKey = dayString(for: Date())
        let alreadySentForDay = UserDefaults.standard.string(forKey: lastInactivityPromptKey) == dayKey
        guard !alreadySentForDay else { return }
        
        let text = "Hej, primećujem da nema unosa već \(inactiveDays) dana. Šta te je zakočilo? Tu sam da složimo lak plan i vratimo ritam."
        messages.append(.init(sender: .coach, text: text))
        saveMessages()
        UserDefaults.standard.set(dayKey, forKey: lastInactivityPromptKey)
    }
    
    private func buildContext(
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) -> (workoutsThisWeek: Int, mealsToday: Int, inactiveDays: Int?) {
        let calendar = Calendar.current
        let now = Date()
        
        let workoutsThisWeek = workouts.filter {
            $0.isCompleted && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }.count
        
        let mealsToday = meals.filter { meal in
            guard let date = meal.date else { return false }
            return calendar.isDate(date, inSameDayAs: now)
        }.count
        
        let latestWorkout = workouts.filter(\.isCompleted).map(\.date).max()
        let latestMeal = meals.compactMap(\.date).max()
        let latestProgress = progressEntries.map(\.date).max()
        let latestActivityDate = [latestWorkout, latestMeal, latestProgress].compactMap { $0 }.max()
        
        let inactiveDays: Int?
        if let latestActivityDate {
            inactiveDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: latestActivityDate), to: calendar.startOfDay(for: now)).day
        } else {
            inactiveDays = 99
        }
        
        return (workoutsThisWeek, mealsToday, inactiveDays)
    }
    
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: messagesKey),
              let decoded = try? JSONDecoder().decode([CoachChatMessage].self, from: data) else {
            messages = [.init(sender: .coach, text: "Ćao! Ja sam tvoj virtualni trener. Piši mi kako ide i gde zapinje.")]
            saveMessages()
            return
        }
        messages = decoded
    }
    
    private func saveMessages() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: messagesKey)
    }
    
    private func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
