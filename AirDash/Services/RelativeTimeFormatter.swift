import Foundation

extension Date {
    /// Locale-safe "X ago" style formatting. Avoids RelativeDateTimeFormatter's
    /// numeric fallback, which renders as "-N unit" instead of "il y a N unité" in French
    /// for anything beyond its built-in "yesterday/today" idioms.
    var relativeShortString: String {
        let interval = Date().timeIntervalSince(self)
        guard interval >= 60 else {
            return String(localized: "relative.just_now")
        }
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if hours < 1 {
            return String(format: NSLocalizedString("relative.minutes_ago %lld", comment: ""), minutes)
        } else if days < 1 {
            return String(format: NSLocalizedString("relative.hours_ago %lld", comment: ""), hours)
        } else {
            return String(format: NSLocalizedString("relative.days_ago %lld", comment: ""), days)
        }
    }
}
