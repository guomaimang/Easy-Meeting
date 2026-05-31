import Foundation

enum AzureHelperRuntime {
    static let scriptName = "index.js"
    static let helperDirectoryName = "AzureSpeechHelper"

    /// 定位 helper 的 index.js。
    static func scriptURL() -> URL? {
        candidateURLs().first { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    /// 定位系统 node 可执行文件。
    static func nodeURL() -> URL? {
        nodeCandidatePaths()
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func diagnostic(settings: AppSettings) -> String {
        if settings.azureSpeechKey.isEmpty {
            return "缺少 Azure 语音密钥"
        }
        guard nodeURL() != nil else {
            return "未找到 node，请先安装 Node.js"
        }
        guard let script = scriptURL() else {
            return "未找到 \(helperDirectoryName)/\(scriptName)，请先安装依赖或打包应用"
        }
        return "配置可用：\(settings.effectiveAzureSpeechRegion)，\(script.path)"
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        urls.append(Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent(helperDirectoryName)
            .appendingPathComponent(scriptName))

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(executableDirectory
                .appendingPathComponent(helperDirectoryName)
                .appendingPathComponent(scriptName))
            urls.append(contentsOf: helperCandidates(underAncestorsOf: executableDirectory))
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(contentsOf: helperCandidates(underAncestorsOf: currentDirectory))

        var seen: Set<String> = []
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard seen.contains(path) == false else { return false }
            seen.insert(path)
            return true
        }
    }

    private static func helperCandidates(underAncestorsOf startURL: URL) -> [URL] {
        var urls: [URL] = []
        var directory = startURL.standardizedFileURL

        // 逐级向上遍历父目录寻找 Helpers。用路径组件数量作为硬性终止条件：
        // 每轮 deletingLastPathComponent 必定减少一个组件，直到收敛为根目录。
        // 不依赖 parent.path == directory.path 字符串比较——某些路径形态下该比较
        // 无法收敛，会导致 while 循环卡死、主线程被占满，应用启动即无响应。
        while directory.pathComponents.count > 1 {
            urls.append(directory
                .appendingPathComponent("Helpers")
                .appendingPathComponent(helperDirectoryName)
                .appendingPathComponent(scriptName))

            directory = directory.deletingLastPathComponent().standardizedFileURL
        }

        return urls
    }

    private static func nodeCandidatePaths() -> [String] {
        var paths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]
        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            for dir in envPath.split(separator: ":") {
                paths.append("\(dir)/node")
            }
        }
        return paths
    }
}
