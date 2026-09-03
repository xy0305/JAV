import SwiftUI

/// Generic renderer for endpoints whose exact shape is not strictly typed.
/// Finds arrays of objects in a decoded JSON dictionary and renders each
/// object using common display keys.
struct DynamicJSONView: View {
    let title: String
    let object: [String: Any]
    var emptyMessage: String = "暂无数据"

    var body: some View {
        let rows = Self.extractRows(from: object)
        if rows.isEmpty {
            EmptyStateView(icon: "tray", message: emptyMessage)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title).foregroundColor(Theme.textPrimary).lineLimit(2)
                            if !row.subtitle.isEmpty {
                                Text(row.subtitle).font(.caption).foregroundColor(Theme.textSecondary)
                            }
                            if let extra = row.extra, !extra.isEmpty {
                                Text(extra).font(.caption2).foregroundColor(Theme.textSecondary).lineLimit(1)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card)
                        .cornerRadius(10)
                    }
                }
                .padding(12)
            }
        }
    }

    struct Row {
        let title: String
        let subtitle: String
        let extra: String?
    }

    static func extractRows(from object: [String: Any]) -> [Row] {
        // Recursively locate the first array of dictionaries.
        guard let array = firstObjectArray(in: object) else { return [] }
        return array.compactMap { item in
            guard let dict = item as? [String: Any] else { return nil }
            let title = firstString(in: dict, keys: ["name", "title", "number", "code", "id", "hash", "key", "type", "label"])
            let subtitle = firstString(in: dict, keys: ["state", "status", "size", "progress", "speed", "count", "total", "language", "seller", "source", "downloader"])
            let extra = firstString(in: dict, keys: ["url", "magnet_link", "magnetLink", "path", "save_path", "category"])
            let t = title ?? "—"
            return Row(title: t, subtitle: subtitle ?? "", extra: extra)
        }
    }

    private static func firstObjectArray(in value: Any) -> [Any]? {
        if let arr = value as? [Any] {
            if arr.contains(where: { $0 is [String: Any] }) { return arr }
            for item in arr {
                if let nested = firstObjectArray(in: item) { return nested }
            }
            return nil
        }
        if let dict = value as? [String: Any] {
            for (_, v) in dict {
                if let nested = firstObjectArray(in: v) { return nested }
            }
        }
        return nil
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let s = dict[k] as? String, !s.isEmpty { return s }
            if let n = dict[k] as? NSNumber { return n.stringValue }
        }
        return nil
    }
}
