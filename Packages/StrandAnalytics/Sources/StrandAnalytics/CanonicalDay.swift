import Foundation

/// Locale-independent handling for day identifiers stored by NOOP.
///
/// Stored day keys are Gregorian `yyyy-MM-dd` identifiers. Never parse them using
/// `Calendar.current` because the user calendar may be Buddhist or another
/// non-Gregorian calendar.
public enum CanonicalDay {
    public static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    public static func key(for date: Date,
                           timeZone: TimeZone = .current) -> String {
        formatter(timeZone: timeZone).string(from: date)
    }

    public static func date(from key: String,
                            timeZone: TimeZone = .current) -> Date? {
        guard key.count == 10 else { return nil }
        let formatter = formatter(timeZone: timeZone)
        guard let parsed = formatter.date(from: key),
              formatter.string(from: parsed) == key
        else { return nil }
        return parsed
    }

    public static func startOfDay(for key: String,
                                  timeZone: TimeZone = .current) -> Date? {
        guard let parsed = date(from: key, timeZone: timeZone) else { return nil }
        return calendar(timeZone: timeZone).startOfDay(for: parsed)
    }

    public static func daysBetween(_ earlierKey: String,
                                   _ laterDate: Date,
                                   timeZone: TimeZone = .current) -> Int? {
        guard let earlier = startOfDay(for: earlierKey, timeZone: timeZone)
        else { return nil }
        let calendar = calendar(timeZone: timeZone)
        let later = calendar.startOfDay(for: laterDate)
        return calendar.dateComponents([.day], from: earlier, to: later).day
    }

    public static func isInWindow(key: String,
                                  from start: Date,
                                  through end: Date,
                                  timeZone: TimeZone = .current) -> Bool {
        guard let day = startOfDay(for: key, timeZone: timeZone) else { return false }
        let calendar = calendar(timeZone: timeZone)
        return day >= calendar.startOfDay(for: start)
            && day <= calendar.startOfDay(for: end)
    }

    public static func startOfWindow(daysIncludingToday days: Int,
                                     now: Date,
                                     timeZone: TimeZone = .current) -> Date? {
        guard days > 0 else { return nil }
        let calendar = calendar(timeZone: timeZone)
        return calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: now)
        )
    }

    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timeZone: timeZone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}
