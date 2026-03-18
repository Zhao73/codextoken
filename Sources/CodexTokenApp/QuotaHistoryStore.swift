import Foundation

public struct ProviderQuotaHistoryRecord: Codable, Sendable {
    public let providerID: String
    public let accountKey: String?
    public let timestamp: Date
    public let primaryUsedPercent: Int
    public let secondaryUsedPercent: Int?

    public init(
        providerID: String,
        accountKey: String?,
        timestamp: Date,
        primaryUsedPercent: Int,
        secondaryUsedPercent: Int?
    ) {
        self.providerID = providerID
        self.accountKey = accountKey
        self.timestamp = timestamp
        self.primaryUsedPercent = primaryUsedPercent
        self.secondaryUsedPercent = secondaryUsedPercent
    }
}

@MainActor
public final class QuotaHistoryStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cache: [ProviderQuotaHistoryRecord]? = nil

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public convenience init(fileManager: FileManager = .default) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        let folder = caches.appendingPathComponent("CodexToken", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("quota-history.json")
        self.init(fileURL: fileURL)
    }

    public func loadAll() -> [ProviderQuotaHistoryRecord] {
        if let cached = cache {
            return cached
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            cache = []
            return []
        }
        if let decoded = try? decoder.decode([ProviderQuotaHistoryRecord].self, from: data) {
            cache = decoded
            return decoded
        }
        cache = []
        return []
    }

    public func append(_ record: ProviderQuotaHistoryRecord, dedupe window: TimeInterval = 65) {
        var history = loadAll()
        if let last = history.last,
           last.providerID == record.providerID,
           last.accountKey == record.accountKey,
           abs(last.timestamp.timeIntervalSince(record.timestamp)) < window,
           last.primaryUsedPercent == record.primaryUsedPercent,
           last.secondaryUsedPercent == record.secondaryUsedPercent
        {
            history[history.count - 1] = record
        } else {
            history.append(record)
        }

        if history.count > 500 {
            history.removeFirst(history.count - 500)
        }

        cache = history
        persist(history)
    }

    private func persist(_ history: [ProviderQuotaHistoryRecord]) {
        do {
            let data = try encoder.encode(history)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence; ignore errors to avoid disrupting UI.
        }
    }
}
