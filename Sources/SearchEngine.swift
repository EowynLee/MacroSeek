import Foundation

enum MSLogger {
    static func log(_ items: Any...) {
        let text = items.map { String(describing: $0) }.joined(separator: " ")
        let line = "[MacroSeek] \(text)\n"
        FileHandle.standardError.write(Data(line.utf8))
        NSLog("%@", line)
    }
}

struct MSFileResult: Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let matchedSnippet: String?
    /// 内容修改时间，用于把近期改过的文件排在前面。
    let modificationDate: Date?

    init(url: URL, name: String, isDirectory: Bool, matchedSnippet: String?, modificationDate: Date? = nil) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.matchedSnippet = matchedSnippet
        self.modificationDate = modificationDate
    }

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (a: MSFileResult, b: MSFileResult) -> Bool { a.url == b.url }
}

private final class MSResultBox: NSObject {
    let items: [MSFileResult]
    let date = Date()
    init(items: [MSFileResult]) { self.items = items }
}

/// 线程安全的结果容器：后面的来源只补足信息（例如正文摘要），不覆盖已有结果。
private final class MSResultStore {
    private(set) var items: [URL: MSFileResult] = [:]

    @discardableResult
    func merge(_ newItems: [MSFileResult]) -> Bool {
        var changed = false
        for item in newItems {
            if let existing = items[item.url] {
                let needsSnippet = existing.matchedSnippet == nil && item.matchedSnippet != nil
                let needsDate = existing.modificationDate == nil && item.modificationDate != nil
                if needsSnippet || needsDate {
                    items[item.url] = MSFileResult(
                        url: item.url,
                        name: item.name,
                        isDirectory: item.isDirectory,
                        matchedSnippet: item.matchedSnippet ?? existing.matchedSnippet,
                        modificationDate: item.modificationDate ?? existing.modificationDate
                    )
                    changed = true
                }
            } else {
                items[item.url] = item
                changed = true
            }
        }
        return changed
    }

    func snapshot(query: String, limit: Int) -> [MSFileResult] {
        let sorted = items.values.sorted { a, b in
            // 主排序：修改时间降序，近期修改的排在前面。
            switch (a.modificationDate, b.modificationDate) {
            case let (ad?, bd?):
                if ad != bd { return ad > bd }
            case (.some, .none):
                return true   // 有修改时间的排在无时间的前面
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            // 次排序：时间相同或都缺失时按名称，保证结果稳定。
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return Array(sorted.prefix(limit))
    }
}

final class MSSearchEngine {
    static let shared = MSSearchEngine()

    private let fm = FileManager.default
    private let scanQueue = DispatchQueue(label: "com.macroseek.scan", qos: .userInitiated, attributes: .concurrent)
    private let spotlightQueue = DispatchQueue(label: "com.macroseek.spotlight", qos: .userInitiated)
    private let stateQueue = DispatchQueue(label: "com.macroseek.state")
    private let cache = NSCache<NSString, MSResultBox>()
    private var generation: UInt64 = 0

    init() { cache.countLimit = 80 }

    // MARK: - Roots

    /// 用户目录、外接卷、已挂载网络卷；过滤系统卷与常见缓存目录。
    func searchRoots() -> [URL] {
        var roots: [URL] = [URL(fileURLWithPath: NSHomeDirectory())]
        if let volumes = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for volume in volumes {
                let path = volume.path
                if path == "/Volumes/Macintosh HD" || path.hasPrefix("/Volumes/Time Machine") { continue }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                roots.append(volume)
            }
        }
        return Array(Set(roots))
    }

    /// 网络卷重连后清缓存，保证下一次搜索重新读取 /Volumes。
    /// 普通呼出面板只重扫卷列表，不清缓存。
    func refreshVolumes(clearCache: Bool = true) {
        if clearCache { cache.removeAllObjects() }
        MSLogger.log("重新扫描已挂载卷:", searchRoots().map { $0.lastPathComponent }.joined(separator: ", "))
    }

    private func isSkipped(path: String) -> Bool {
        let lower = path.lowercased()
        let skipComponents = ["/library/caches", "/.cache", "/node_modules", "/.git/", "/deriveddata", "/.trash", "/.npm/", "/.cocoapods/", "/private/tmp/", "/private/var/folders/", "/system/volumes/data/library/caches"]
        for component in skipComponents where lower.contains(component) { return true }
        let skipExtensions = [".app", ".framework", ".xcarchive", ".bundle", ".dsym"]
        for ext in skipExtensions where lower.hasSuffix(ext) { return true }
        return false
    }

    private func normalizedPath(_ path: String) -> String {
        let prefix = "/System/Volumes/Data"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    private func isUnderRoots(_ path: String, roots: [URL]) -> Bool {
        let normalized = normalizedPath(path)
        for root in roots {
            let rootPath = normalizedPath(root.path)
            if normalized == rootPath || normalized.hasPrefix(rootPath + "/") { return true }
        }
        return false
    }

    private func isHome(_ url: URL) -> Bool {
        normalizedPath(url.path) == normalizedPath(NSHomeDirectory())
    }

    // MARK: - Search (Spotlight 秒出 + 后台补全)

    func search(query: String, mode: MSSearchMode, limit: Int = 400,
                completion: @escaping ([MSFileResult], Bool) -> Void) {
        search(query: query, mode: mode, roots: searchRoots(), limit: limit, completion: completion)
    }

    func search(query: String, mode: MSSearchMode, roots: [URL], limit: Int = 400,
                completion: @escaping ([MSFileResult], Bool) -> Void) {
        generation &+= 1
        let token = generation
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async { completion([], true) }
            return
        }

        let key = "\(mode.rawValue):\(trimmed)" as NSString
        if let cached = cache.object(forKey: key), Date().timeIntervalSince(cached.date) < 300 {
            MSLogger.log("缓存命中:", key)
            DispatchQueue.main.async { completion(cached.items, true) }
            return
        }

        let started = Date()
        MSLogger.log("搜索:\(trimmed) 模式:\(mode.rawValue)")
        let store = MSResultStore()
        let allGroup = DispatchGroup()

        func publish(finished: Bool) {
            guard token == self.generation else { return }
            let items = stateQueue.sync { store.snapshot(query: trimmed, limit: limit) }
            DispatchQueue.main.async {
                completion(items, finished)
            }
            if finished {
                stateQueue.sync { self.cache.setObject(MSResultBox(items: items), forKey: key) }
                MSLogger.log("搜索完成 用时:", String(format: "%.2fs", Date().timeIntervalSince(started)), "结果数:", items.count)
            }
        }

        // 1) Spotlight：来自系统索引，首次搜索也能立即返回。
        allGroup.enter()
        spotlightQueue.async {
            let spotlight = self.spotlightResults(query: trimmed, mode: mode, roots: roots, limit: limit)
            guard token == self.generation else { allGroup.leave(); return }
            if !spotlight.isEmpty {
                let changed = self.stateQueue.sync { store.merge(spotlight) }
                if changed { publish(finished: false) }
                MSLogger.log("Spotlight 命中:", spotlight.count)
            } else if mode == .content {
                // Spotlight 没命中时，补一次主目录的正文遍历（较慢，但在后台）。
                if let home = roots.first(where: { self.isHome($0) }) {
                    allGroup.enter()
                    self.scanQueue.async {
                        self.manualScan(root: home, query: trimmed, mode: mode, contentEnabled: true,
                                        token: token, limit: limit, store: store, onUpdate: { publish(finished: false) })
                        allGroup.leave()
                    }
                }
            }
            allGroup.leave()
        }

        // 2) 后台遍历：网络卷/外接卷必须自己扫；主目录只做文件名快扫，正文交给 Spotlight。
        var manualTasks: [(root: URL, contentEnabled: Bool)] = []
        if mode == .name {
            manualTasks = roots.map { ($0, false) }
        } else {
            manualTasks = roots.filter { !self.isHome($0) }.map { ($0, true) }
            if let home = roots.first(where: { self.isHome($0) }) {
                manualTasks.append((home, false))
            }
        }

        for task in manualTasks {
            allGroup.enter()
            scanQueue.async {
                self.manualScan(root: task.root, query: trimmed, mode: mode, contentEnabled: task.contentEnabled,
                                token: token, limit: limit, store: store, onUpdate: { publish(finished: false) })
                allGroup.leave()
            }
        }

        allGroup.notify(queue: scanQueue) {
            publish(finished: true)
        }
    }

    // MARK: - Spotlight

    private func spotlightResults(query: String, mode: MSSearchMode, roots: [URL], limit: Int) -> [MSFileResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        if mode == .name {
            process.arguments = ["-name", query]
        } else {
            let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "'", with: "\\'")
            process.arguments = ["kMDItemTextContent == '*\(escaped)*'"]
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch {
            MSLogger.log("Spotlight 启动失败:", error.localizedDescription)
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return [] }

        var result: [MSFileResult] = []
        for line in output.split(separator: "\n").prefix(limit * 2) {
            let path = String(line)
            guard !path.isEmpty, isUnderRoots(path, roots: roots), !isSkipped(path: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else { continue }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            let isDir = values?.isDirectory ?? false
            result.append(MSFileResult(url: url, name: url.lastPathComponent, isDirectory: isDir,
                                       matchedSnippet: nil, modificationDate: values?.contentModificationDate))
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: - Manual walk

    private func manualScan(root: URL, query: String, mode: MSSearchMode, contentEnabled: Bool,
                            token: UInt64, limit: Int, store: MSResultStore, onUpdate: @escaping () -> Void) {
        guard token == generation else { return }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isReadableKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                             errorHandler: { _, _ in true }) else { return }

        var visited = 0
        var lastPublish = Date()
        for case let url as URL in enumerator {
            if token != generation { return }
            visited += 1
            if visited > 250_000 { break }
            let path = url.path
            if isSkipped(path: path) { continue }
            guard let values = try? url.resourceValues(forKeys: keys), values.isReadable == true else { continue }
            let isDir = values.isDirectory ?? false
            let name = url.lastPathComponent
            var snippet: String? = nil
            var matched = name.localizedCaseInsensitiveContains(query)

            if !matched, mode == .content, contentEnabled, !isDir, isTextSearchable(url) {
                let size = values.fileSize ?? 0
                if size <= 20_000_000 {
                    snippet = searchText(in: url, query: query)
                    matched = snippet != nil
                }
            }

            if matched {
                let item = MSFileResult(url: url, name: name, isDirectory: isDir, matchedSnippet: snippet,
                                        modificationDate: values.contentModificationDate)
                let changed = stateQueue.sync { store.merge([item]) }
                if changed, Date().timeIntervalSince(lastPublish) > 0.12 {
                    lastPublish = Date()
                    onUpdate()
                }
                let count = stateQueue.sync { store.items.count }
                if count >= limit { return }
            }
        }
    }

    private func isTextSearchable(_ url: URL) -> Bool {
        let supported = ["txt", "md", "markdown", "csv", "json", "xml", "html", "htm", "css", "js", "ts", "swift", "py", "java", "c", "cpp", "h", "m", "mm", "rtf", "log", "ini", "plist", "yaml", "yml", "sql", "docx"]
        return supported.contains(url.pathExtension.lowercased())
    }

    /// 纯文本匹配；.docx 从 word/document.xml 抽取正文。
    private func searchText(in url: URL, query: String) -> String? {
        let content: String?
        if url.pathExtension.lowercased() == "docx" {
            content = docxPlainText(at: url)
        } else {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
            let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            let encodings: [String.Encoding] = [.utf8, .utf16, gb18030]
            content = encodings.lazy.compactMap { String(data: data, encoding: $0) }.first
        }
        guard let content else { return nil }
        let lower = content.lowercased()
        let needle = query.lowercased()
        guard let range = lower.range(of: needle) else { return nil }
        let start = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 50, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[start..<end]).replacingOccurrences(of: "\n", with: " ")
    }

    /// 用系统自带的 unzip 读取 docx 正文，避免引入第三方解压库。
    private func docxPlainText(at url: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, "word/document.xml"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let xml = String(data: data, encoding: .utf8) else { return nil }
        var text = xml
            .replacingOccurrences(of: "</w:p>", with: "\n")
            .replacingOccurrences(of: "<w:tab/>", with: "\t")
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    func snippet(for url: URL, query: String) -> String? {
        guard isTextSearchable(url) else { return nil }
        return searchText(in: url, query: query)
    }
}

enum MSSearchMode: String {
    case name = "文件名"
    case content = "内容"
}
