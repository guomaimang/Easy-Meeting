import Foundation

enum AppStorage {
    static let appFolderName = "Easy Meeting"

    static func applicationSupportURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appURL = baseURL.appendingPathComponent(appFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        return appURL
    }

    static func meetingsURL() throws -> URL {
        let url = try applicationSupportURL().appendingPathComponent("meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func databaseURL() throws -> URL {
        try applicationSupportURL().appendingPathComponent("easy_meeting.sqlite")
    }
}
