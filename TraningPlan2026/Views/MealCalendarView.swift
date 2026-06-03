import SwiftUI

struct MealCalendarView: View {
    let meals: [Meal]
    @Binding var selectedDate: Date
    
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    init(meals: [Meal], selectedDate: Binding<Date>) {
        self.meals = meals
        _selectedDate = selectedDate
        let start = MealCalendarView.startOfMonth(for: selectedDate.wrappedValue)
        _displayedMonth = State(initialValue: start)
    }
    
    private var mealsByDay: [Date: [Meal]] {
        Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.date ?? Date.distantPast)
        }
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "LLLL yyyy"
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        monthHeader
                        
                        HStack {
                            ForEach(["P", "U", "S", "Č", "P", "S", "N"], id: \.self) { day in
                                Text(day)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppDesign.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                            ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    MealCalendarDayCell(
                                        date: date,
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                        entryCount: mealsByDay[calendar.startOfDay(for: date)]?.count ?? 0
                                    ) {
                                        Haptics.light()
                                        selectedDate = date
                                        dismiss()
                                    }
                                } else {
                                    Color.clear.frame(height: 58)
                                }
                            }
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Kalendar ishrane")
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
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
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
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppDesign.textPrimary)
            }
        }
        .appCard()
    }
    
    private static func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct MealCalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let entryCount: Int
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
                
                if entryCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(3, entryCount), id: \.self) { _ in
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
