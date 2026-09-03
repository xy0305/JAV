import SwiftUI

// MARK: - Field types

enum ConfigFieldType {
    case bool
    case text
    case secure
    case int
    case double
    case stringList
    case intList
    case doubleList
    case null
}

struct ConfigField: Identifiable {
    let id: String            // full path
    let path: String
    let title: String
    let type: ConfigFieldType
    let original: String
}

struct ConfigSection: Identifiable {
    let id: String
    let name: String
    let fields: [ConfigField]
}

// MARK: - Store

final class ConfigStore: ObservableObject {
    @Published var sections: [ConfigSection] = []
    @Published var textValues: [String: String] = [:]
    @Published var boolValues: [String: Bool] = [:]
    @Published var loading = false
    @Published var error: String?
    @Published var savedMessage: String?
    @Published var saving = false

    private var original: [String: Any] = [:]
    private var fields: [ConfigField] = []

    private static let sectionOrder = [
        "server", "database", "log", "ui", "auth", "proxy", "subscription",
        "auto_sync", "javdb_api", "image_cache", "downloader", "mediaserver",
        "subtitle", "telegram", "ai", "mcp", "experimental", "external_magnet"
    ]

    func load() async {
        await MainActor.run {
            loading = true
            error = nil
            savedMessage = nil
        }
        do {
            let raw = try await APIClient.shared.get("/config", as: JSONObject.self).raw
            await MainActor.run { self.apply(raw) }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { loading = false }
    }

    private func apply(_ raw: [String: Any]) {
        original = raw
        var all: [ConfigField] = []
        var textVals: [String: String] = [:]
        var boolVals: [String: Bool] = [:]
        flatten(raw, prefix: "", into: &all)
        for f in all {
            switch f.type {
            case .bool:
                boolVals[f.path] = (f.original == "true")
            case .secure, .null:
                textVals[f.path] = ""   // never prefill secrets
            default:
                textVals[f.path] = f.original
            }
        }
        var grouped: [String: [ConfigField]] = [:]
        for f in all {
            let sec = f.path.split(separator: ".").first.map(String.init) ?? ""
            grouped[sec, default: []].append(f)
        }
        var secs: [ConfigSection] = []
        for name in Self.sectionOrder {
            if let fs = grouped[name] {
                secs.append(ConfigSection(id: name, name: name, fields: fs))
            }
        }
        for (name, fs) in grouped.sorted(by: { $0.key < $1.key }) {
            if !Self.sectionOrder.contains(name) {
                secs.append(ConfigSection(id: name, name: name, fields: fs))
            }
        }
        sections = secs
        textValues = textVals
        boolValues = boolVals
        fields = all
    }

    private func flatten(_ value: Any, prefix: String, into out: inout [ConfigField]) {
        if let d = value as? [String: Any] {
            for (k, v) in d.sorted(by: { $0.key < $1.key }) {
                flatten(v, prefix: prefix.isEmpty ? k : prefix + "." + k, into: &out)
            }
            return
        }
        let leaf = prefix.split(separator: ".").last.map(String.init) ?? prefix
        if leaf == "configured" || leaf.hasSuffix("_configured") || leaf == "webauthn_credentials" {
            return   // skip read-only computed fields
        }
        let (type, orig) = classify(value, leaf: leaf)
        out.append(ConfigField(id: prefix, path: prefix, title: displayTitle(prefix), type: type, original: orig))
    }

    private func classify(_ value: Any, leaf: String) -> (ConfigFieldType, String) {
        if let b = value as? Bool { return (.bool, b ? "true" : "false") }
        if let s = value as? String {
            return (isSensitive(leaf) ? .secure : .text, s)
        }
        if let i = value as? Int { return (.int, String(i)) }
        if let d = value as? Double { return (.double, String(d)) }
        if let arr = value as? [Any] {
            if arr.isEmpty { return (.stringList, "") }
            let allStr = arr.allSatisfy { $0 is String }
            let allInt = arr.allSatisfy { $0 is Int }
            if allStr {
                return (.stringList, arr.map { String(describing: $0) }.joined(separator: ", "))
            }
            if allInt {
                return (.intList, arr.map { String(describing: $0) }.joined(separator: ", "))
            }
            return (.doubleList, arr.map { numStr($0) }.joined(separator: ", "))
        }
        if value is NSNull { return (.null, "") }
        return (.text, "")
    }

    private func numStr(_ v: Any) -> String {
        if let i = v as? Int { return String(i) }
        if let d = v as? Double { return String(d) }
        return ""
    }

    private func isSensitive(_ leaf: String) -> Bool {
        let l = leaf.lowercased()
        return l.contains("password") || l.contains("secret") || l.contains("token")
            || l.contains("cookie") || l.contains("api_key") || l.contains("device_uuid")
            || l.contains("authorization")
    }

    private func displayTitle(_ path: String) -> String {
        let parts = path.split(separator: ".").map(String.init)
        if parts.count <= 1 { return path }
        return parts.dropFirst().joined(separator: ".")
    }

    // MARK: Save

    func save() async {
        await MainActor.run {
            saving = true
            savedMessage = nil
            error = nil
        }
        var payload: [String: Any] = [:]
        for f in fields {
            switch f.type {
            case .bool:
                let cur = boolValues[f.path] ?? false
                let orig = f.original == "true"
                if cur != orig { setNested(cur, at: f.path, in: &payload) }
            case .secure:
                let cur = (textValues[f.path] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !cur.isEmpty { setNested(cur, at: f.path, in: &payload) }
            case .null:
                let cur = (textValues[f.path] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !cur.isEmpty { setNested(cur, at: f.path, in: &payload) }
            default:
                let cur = textValues[f.path] ?? ""
                if cur != f.original { setNested(convert(cur, type: f.type), at: f.path, in: &payload) }
            }
        }
        do {
            if payload.isEmpty {
                await MainActor.run {
                    savedMessage = "没有改动"
                    saving = false
                }
                return
            }
            _ = try await APIClient.shared.putRawJSON("/config", body: payload, as: JSONObject.self)
            await MainActor.run { savedMessage = "已保存" }
            try? await Task.sleep(nanoseconds: 400_000_000)
            await load()
        } catch let err {
            await MainActor.run { self.error = err.localizedDescription }
        }
        await MainActor.run { saving = false }
    }

    private func convert(_ s: String, type: ConfigFieldType) -> Any {
        switch type {
        case .int: return Int(s.trimmingCharacters(in: .whitespaces)) ?? 0
        case .double: return Double(s.trimmingCharacters(in: .whitespaces)) ?? 0
        case .stringList:
            return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        case .intList:
            return s.split(separator: ",").compactMap { Int(String($0).trimmingCharacters(in: .whitespaces)) }
        case .doubleList:
            return s.split(separator: ",").compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
        default:
            return s
        }
    }

    private func setNested(_ value: Any, at path: String, in dict: inout [String: Any]) {
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first else { return }
        if parts.count == 1 {
            dict[first] = value
        } else {
            var child = dict[first] as? [String: Any] ?? [:]
            setNested(value, at: parts.dropFirst().joined(separator: "."), in: &child)
            dict[first] = child
        }
    }
}

// MARK: - Editor view

struct ConfigEditorView: View {
    @StateObject private var store = ConfigStore()
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Group {
            if store.loading && store.sections.isEmpty {
                LoadingView()
            } else if let e = store.error, store.sections.isEmpty {
                ErrorStateView(message: e) { Task { await store.load() } }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(store.sections) { section in
                            ConfigSectionView(section: section, store: store)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("服务器配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await store.save() } } label: {
                    if store.saving {
                        ProgressView()
                    } else {
                        Text("保存").bold()
                    }
                }
                .disabled(store.saving || store.sections.isEmpty)
            }
        }
        .task { await store.load() }
        .onChange(of: store.savedMessage) { _, msg in
            if let m = msg {
                alertMessage = m
                showAlert = true
            }
        }
        .onChange(of: store.error) { _, e in
            if let m = e {
                alertMessage = m
                showAlert = true
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        }
    }
}

struct ConfigSectionView: View {
    let section: ConfigSection
    @ObservedObject var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.name)
                .font(.headline)
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(section.fields.enumerated()), id: \.element.id) { idx, field in
                    ConfigFieldRow(field: field, store: store)
                    if idx < section.fields.count - 1 {
                        Divider().background(Theme.cardHighlight)
                    }
                }
            }
            .background(Theme.card)
            .cornerRadius(12)
        }
    }
}

struct ConfigFieldRow: View {
    let field: ConfigField
    @ObservedObject var store: ConfigStore

    var body: some View {
        HStack(spacing: 10) {
            Text(field.title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var control: some View {
        switch field.type {
        case .bool:
            Toggle("", isOn: boolBinding).labelsHidden()
        case .secure:
            SecureField("未修改", text: textBinding)
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
        case .int, .double:
            TextField("0", text: textBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
        case .stringList, .intList, .doubleList:
            TextField("（逗号分隔）", text: textBinding)
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
        case .text, .null:
            TextField("", text: textBinding)
                .multilineTextAlignment(.trailing)
                .frame(width: 150)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { store.textValues[field.path] ?? "" },
            set: { store.textValues[field.path] = $0 }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { store.boolValues[field.path] ?? false },
            set: { store.boolValues[field.path] = $0 }
        )
    }
}
