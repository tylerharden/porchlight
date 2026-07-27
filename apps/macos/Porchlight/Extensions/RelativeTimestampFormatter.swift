import Foundation

enum RelativeTimestampFormatter {
    static func date(from timestamp: String?) -> Date? {
        guard let timestamp else { return nil }
        return iso8601.date(from: timestamp)
            ?? iso8601WithFractionalSeconds.date(from: timestamp)
    }

    static func localizedString(for timestamp: String?) -> String? {
        guard let timestamp else { return nil }
        guard let date = date(from: timestamp) else { return timestamp }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
