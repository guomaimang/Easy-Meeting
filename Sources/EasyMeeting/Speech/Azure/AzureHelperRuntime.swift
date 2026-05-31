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
        if settings.azureSpeechRegion.isEmpty {
            return "缺少 Azure 区域"
        }
        guard nodeURL() != nil else {
            return "未找到 node，请先安装 Node.js"
        }
        guard let script = scriptURL() else {
            return "未找到 \(helperDirectoryName)/\(scriptName)，请先安装依赖或打包应用"
        }
        return "配置可用：\(settings.azureSpeechRegion)，\(script.path)"
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
        }

        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Helpers")
            .appendingPathComponent(helperDirectoryName)
            .appendingPathComponent(scriptName))

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
