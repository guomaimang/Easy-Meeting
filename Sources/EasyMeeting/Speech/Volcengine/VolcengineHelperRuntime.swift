import Foundation

enum VolcengineHelperRuntime {
    static let executableName = "easy-meeting-ast-helper"

    static func helperURL() -> URL? {
        candidateURLs().first { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    }

    static func diagnostic(settings: AppSettings) -> String {
        if settings.volcengineAPIKey.isEmpty {
            return "缺少 API Key"
        }

        guard let helper = helperURL() else {
            return "未找到 \(executableName)，请先打包应用"
        }

        return "配置可用：\(AppSettings.volcengineResourceID)，\(helper.path)"
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        urls.append(Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent(executableName))

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(executableDirectory.appendingPathComponent(executableName))
        }

        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
            .appendingPathComponent("debug")
            .appendingPathComponent(executableName))

        return urls
    }
}
