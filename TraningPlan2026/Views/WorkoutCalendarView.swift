import SwiftUI

struct WorkoutCalendarView: View {
    let workouts: [Workout]
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    init(workouts: [Workout]) {
        self.workouts = workouts
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        _selectedDate = State(initialValue: today)
        _displayedMonth = State(initialValue: WorkoutCalendarView.startOfMonth(for: today))
    }
    
    private var workoutsByDay: [Date: [Workout]] {
        Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }
    
    private var daysInGrid: [Date?] {
        let start = Self.startOfMonth(for: displayedMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: start) ?? 1..<2
        let weekday = calendar.component(.weekday, from: start)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7
        
        var result: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                result.append(date)
            }
        }
        
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
    
    private var selectedDayWorkouts: [Workout] {
        let day = calendar.startOfDay(for: selectedDate)
        return (workoutsByDay[day] ?? []).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        monthHeader
                        
                        HStack {
                            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                                Text(day)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppDesign.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                            ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    CalendarDayCell(
                                        date: date,
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                        workoutCount: workoutsByDay[calendar.startOfDay(for: date)]?.count ?? 0
                                    ) {
                                        Haptics.light()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                            selectedDate = date
                                        }
                                    }
                                } else {
                                    Color.clear.frame(height: 58)
                                }
                            }
                        }
                        .appCard()
                        
                        selectedDaySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var monthHeader: some View {
        HStack {
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppDesign.textPrimary)
            }
            
            Spacer()
            Text(monthTitle)
                .font(.title2.bold())
                .foregroundStyle(AppDesign.textPrimary)
            Spacer()
            
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppDesign.textPrimary)
            }
        }
        .appCard()
    }
    
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workouts • \(formattedSelectedDate)")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            if selectedDayWorkouts.isEmpty {
                Text("No workouts on this day.")
                    .font(.subheadline)
                    .foregroundStyle(AppDesign.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                ForEach(selectedDayWorkouts) { workout in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(AppDesign.accent)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            Text("\(workout.exercises.count) exercises\(workout.duration != nil ? " • \(workout.duration ?? 0) min" : "")")
                                .font(.caption)
                                .foregroundStyle(AppDesign.textSecondary)
                        }
                        Spacer()
                    }
                    .appCard()
                }
            }
        }
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private static func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let workoutCount: Int
    let onTap: () -> Void
    
    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(AppDesign.accent) : AnyShapeStyle(AppDesign.cardSecondary))
                        .frame(width: 34, height: 34)
                    Text(dayNumber)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.black : AppDesign.textPrimary)
                }
                
                if workoutCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(3, workoutCount), id: \.self) { _ in
                            Circle()
                                .fill(AppDesign.accent)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }
}
