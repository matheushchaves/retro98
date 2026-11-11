import CoreServices
import Foundation

public struct RecentDocument: Equatable, Sendable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public protocol RecentDocumentsProvider: Sendable {
    func recent(limit: Int) -> [RecentDocument]
}

/// Documents in the home folder opened in the last 30 days, most recent first (Spotlight).
public struct SpotlightRecentDocuments: RecentDocumentsProvider {
    static let query = """
        kMDItemLastUsedDate >= $time.today(-30) && kMDItemContentTypeTree == "public.content" \
        && kMDItemContentType != "com.apple.application-bundle"
        """

    public init() {}

    public func recent(limit: Int) -> [RecentDocument] {
        guard limit > 0, let query = MDQueryCreate(kCFAllocatorDefault, Self.query as CFString, nil, nil) else { return [] }
        MDQuerySetSearchScope(query, [NSHomeDirectory()] as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return [] }

        let found = (0..<MDQueryGetResultCount(query)).compactMap { index -> (Date, RecentDocument)? in
            guard let raw = MDQueryGetResultAtIndex(query, index) else { return nil }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String,
                  let date = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
            else { return nil }
            return (date, RecentDocument(name: FileManager.default.displayName(atPath: path), url: URL(filePath: path)))
        }
        return found.sorted { $0.0 > $1.0 }.prefix(limit).map(\.1)
    }
}
