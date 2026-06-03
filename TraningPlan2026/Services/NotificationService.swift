import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    private enum Constants {
        static let dailyCheckInId = "daily-motivation-22h"
        static let weeklyRecapId = "weekly-recap-sunday-morning"
        static let weeklyMilestonePrefix = "weekly-milestone-4of4-"
        static let notifiedMilestoneWeekKey = "notifications.notifiedMilestoneWeekKey"
        static let weeklyGoal = 4
        
        // Temporary test schedule to quickly verify notification content.
        static let testMode = false
        static let testHour = 13
        static let testMinute = 55
    }
    
    private struct ChatCompletionRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
    }
    
    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        
        let choices: [Choice]
    }
    
    func configureDailyCheckInNotification() {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            await refreshNotifications(workouts: [], meals: [], progressEntries: [])
        }
    }
    
    func refreshNotifications(
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }
        
        let dailyBody = await makeDailyBody(workouts: workouts, meals: meals, progressEntries: progressEntries)
        let weeklyBody = await makeWeeklyRecapBody(workouts: workouts, meals: meals, progressEntries: progressEntries)
        
        scheduleDailyCheckIn(body: dailyBody)
        scheduleWeeklyRecap(body: weeklyBody)
        triggerWeeklyMilestoneIfNeeded(workouts: workouts)
    }
    
    private func requestAuthorizationIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func scheduleDailyCheckIn(body: String) {
        let center = UNUserNotificationCenter.current()
        
        center.removePendingNotificationRequests(withIdentifiers: [Constants.dailyCheckInId])
        
        let content = UNMutableNotificationContent()
        content.title = "Dnevni check-in"
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        if Constants.testMode {
            dateComponents.hour = Constants.testHour
            dateComponents.minute = Constants.testMinute
        } else {
            dateComponents.hour = 22
            dateComponents.minute = 0
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.dailyCheckInId,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    private func scheduleWeeklyRecap(body: String) {
        let center = UNUserNotificationCenter.current()
        
        center.removePendingNotificationRequests(withIdentifiers: [Constants.weeklyRecapId])
        
        let content = UNMutableNotificationContent()
        content.title = "Nedeljni rezime"
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        if Constants.testMode {
            // In test mode, run recap daily at a fixed time so it can be verified quickly.
            dateComponents.hour = Constants.testHour
            dateComponents.minute = Constants.testMinute
        } else {
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 9
            dateComponents.minute = 0
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.weeklyRecapId,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    private func triggerWeeklyMilestoneIfNeeded(workouts: [Workout]) {
        let calendar = Calendar.current
        let now = Date()
        let weekKey = currentWeekKey(for: now)
        let alreadyNotified = UserDefaults.standard.string(forKey: Constants.notifiedMilestoneWeekKey) == weekKey
        
        guard !alreadyNotified else { return }
        
        let weeklyCompleted = workouts.filter {
            $0.isCompleted && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }.count
        
        guard weeklyCompleted >= Constants.weeklyGoal else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Čestitamo!"
        content.body = "Uspešno ste odradili \(Constants.weeklyGoal)/\(Constants.weeklyGoal) treninga ove nedelje. Sjajan kontinuitet!"
        content.sound = .default
        
        let identifier = "\(Constants.weeklyMilestonePrefix)\(weekKey)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        UserDefaults.standard.set(weekKey, forKey: Constants.notifiedMilestoneWeekKey)
    }
    
    private func makeDailyBody(
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) async -> String {
        let calendar = Calendar.current
        let today = Date()
        let targets = loadNutritionTargets()
        let workoutsToday = workouts.filter { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }.count
        let mealsToday = meals.filter { meal in
            guard let date = meal.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }.count
        let progressToday = progressEntries.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        let totals = nutritionTotals(for: today, meals: meals)
        let nutritionWithinTarget =
            totals.calories <= targets.calories &&
            totals.protein <= targets.protein &&
            totals.carbs <= targets.carbs &&
            totals.fat <= targets.fat
        
        let fallback: String
        if workoutsToday == 0 && mealsToday == 0 && progressToday == 0 {
            fallback = "Danas nema unosa. Napravi makar jedan mali korak danas da ne prekineš ritam."
        } else {
            fallback = "Danas: trening \(workoutsToday), obroci \(mealsToday), napredak \(progressToday). Nastavi ovim tempom i sutra."
        }
        
        let prompt = """
        Korisnik fitness aplikacije ima dnevni rezime:
        - broj završenih treninga danas: \(workoutsToday)
        - broj unetih obroka danas: \(mealsToday)
        - broj unosa napretka (mere/fotografije) danas: \(progressToday)
        - kalorije danas: \(totals.calories)/\(targets.calories)
        - protein danas: \(Int(totals.protein))/\(Int(targets.protein)) g
        - ugljeni hidrati danas: \(Int(totals.carbs))/\(Int(targets.carbs)) g
        - masti danas: \(Int(totals.fat))/\(Int(targets.fat)) g
        - svi nutritivni ciljevi danas u granici 100%: \(nutritionWithinTarget ? "da" : "ne")
        
        Napiši jednu kratku motivacionu poruku na srpskom (maks 140 karaktera), prijateljski ton.
        Ako nema nijednog unosa danas, poruka treba da podstakne korisnika da krene odmah.
        Ako je nutritivni unos ispod ili do 100% ciljeva, tretiraj to kao dobro i ne koristi negativan ton zbog hrane.
        Vrati samo samu poruku, bez navodnika i bez liste.
        """
        
        return await aiMessage(for: prompt) ?? fallback
    }
    
    private func makeWeeklyRecapBody(
        workouts: [Workout],
        meals: [Meal],
        progressEntries: [BodyProgressEntry]
    ) async -> String {
        let calendar = Calendar.current
        let now = Date()
        let targets = loadNutritionTargets()
        
        let weeklyWorkouts = workouts.filter {
            $0.isCompleted && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }.count
        let weeklyMeals = meals.filter { meal in
            guard let date = meal.date else { return false }
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        }.count
        let weeklyProgressEntries = progressEntries.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
        }.count
        let weeklyDaysOverTarget = daysOverNutritionTargetsThisWeek(meals: meals, targets: targets, referenceDate: now)
        
        let remaining = max(0, Constants.weeklyGoal - weeklyWorkouts)
        let fallback: String
        if weeklyWorkouts >= Constants.weeklyGoal {
            fallback = "Odlično! Nedelja zatvorena sa \(weeklyWorkouts)/\(Constants.weeklyGoal) treninga. Samo nastavi isti ritam."
        } else if weeklyWorkouts > 0 {
            fallback = "Dobra nedelja: \(weeklyWorkouts)/\(Constants.weeklyGoal) treninga. Sledeće nedelje ciljaj još \(remaining) treninga više."
        } else {
            fallback = "Ovo je bila slaba nedelja bez treninga. Sledeće nedelje kreni sa prvim treningom već u ponedeljak."
        }
        
        let prompt = """
        Korisnik fitness aplikacije ima nedeljni rezime:
        - završeni treninzi: \(weeklyWorkouts) od cilja \(Constants.weeklyGoal)
        - uneti obroci: \(weeklyMeals)
        - unosi napretka (mere/fotografije): \(weeklyProgressEntries)
        - broj dana ove nedelje kad je nutritivni unos prešao 100% ciljeve: \(weeklyDaysOverTarget)
        
        Napiši jednu kratku poruku na srpskom (maks 180 karaktera) za nedeljni push.
        Ako je cilj ispunjen, čestitaj.
        Ako nije, daj konkretnu i motivacionu sugestiju bez osuđivanja.
        Važno: manji unos hrane (ispod 100% ciljeva) je okej i ne treba ga predstavljati kao neuspeh.
        Vrati samo poruku.
        """
        
        return await aiMessage(for: prompt) ?? fallback
    }
    
    private func aiMessage(for prompt: String) async -> String? {
        guard let apiKey = AppSecrets.openAIAPIKey,
              let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }
        
        let payload = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(role: "system", content: "You write concise motivational push notification copy in Serbian."),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.7
        )
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty else { return nil }
            return text.replacingOccurrences(of: "\"", with: "")
        } catch {
            return nil
        }
    }
    
    private func currentWeekKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(week)"
    }
    
    private func loadNutritionTargets() -> NutritionTargets {
        if let data = UserDefaults.standard.data(forKey: "nutritionTargets"),
           let decoded = try? JSONDecoder().decode(NutritionTargets.self, from: data) {
            return decoded
        }
        return .default
    }
    
    private func nutritionTotals(for day: Date, meals: [Meal]) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let calendar = Calendar.current
        let dayMeals = meals.filter { meal in
            guard let date = meal.date else { return false }
            return calendar.isDate(date, inSameDayAs: day)
        }
        
        return (
            dayMeals.compactMap(\.calories).reduce(0, +),
            dayMeals.compactMap(\.protein).reduce(0, +),
            dayMeals.compactMap(\.carbs).reduce(0, +),
            dayMeals.compactMap(\.fat).reduce(0, +)
        )
    }
    
    private func daysOverNutritionTargetsThisWeek(meals: [Meal], targets: NutritionTargets, referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let weekMeals = meals.filter { meal in
            guard let date = meal.date else { return false }
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear)
        }
        
        var totalsByDay: [Date: (calories: Int, protein: Double, carbs: Double, fat: Double)] = [:]
        for meal in weekMeals {
            guard let date = meal.date else { continue }
            let day = calendar.startOfDay(for: date)
            let current = totalsByDay[day] ?? (0, 0, 0, 0)
            totalsByDay[day] = (
                current.calories + (meal.calories ?? 0),
                current.protein + (meal.protein ?? 0),
                current.carbs + (meal.carbs ?? 0),
                current.fat + (meal.fat ?? 0)
            )
        }
        
        return totalsByDay.values.filter { total in
            total.calories > targets.calories ||
            total.protein > targets.protein ||
            total.carbs > targets.carbs ||
            total.fat > targets.fat
        }.count
    }
}
