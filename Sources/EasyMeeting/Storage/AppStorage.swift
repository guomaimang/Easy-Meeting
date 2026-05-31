import Foundation

enum AppStorage {
    static let appFolderName = "Easy Meeting"
    static let meetingsFolderName = "Meetings"

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
        let url = try userDocumentsURL()
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(meetingsFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func databaseURL() throws -> URL {
        try applicationSupportURL().appendingPathComponent("easy_meeting.sqlite")
    }

    private static func userDocumentsURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
