import Foundation

public enum NoticeAutoDismissTone {
    case info
    case success
    case error
}

public enum NoticeAutoDismissPolicy {
    public static let defaultDelay: TimeInterval = 5

    public static func delay(
        for tone: NoticeAutoDismissTone,
        hasAction: Bool
    ) -> TimeInterval? {
        guard !hasAction else {
            return nil
        }

        switch tone {
        case .info, .success:
            return defaultDelay
        case .error:
            return nil
        }
    }
}
