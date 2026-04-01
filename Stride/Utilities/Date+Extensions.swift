import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var dayOfWeek: DayOfWeek {
        DayOfWeek.from(date: self)
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self)!
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns the Monday of the week containing this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        let mondayOffset = (weekday == 1) ? -6 : (2 - weekday)
        return calendar.date(byAdding: .day, value: mondayOffset, to: self.startOfDay)!
    }
}
