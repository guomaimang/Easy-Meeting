import Foundation
import SQLite3

final class SQLiteDatabase {
    private let connection: OpaquePointer?

    init(url: URL) throws {
        var database: OpaquePointer?
        let result = sqlite3_open(url.path, &database)

        guard result == SQLITE_OK, let database else {
            throw SQLiteDatabaseError.openFailed(Self.errorMessage(database))
        }

        connection = database
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
        try migrate()
    }

    deinit {
        sqlite3_close(connection)
    }

    func upsertMeeting(_ meeting: MeetingRecord) throws {
        let sql = """
        INSERT INTO meetings (
            id, title, started_at, ended_at, audio_path, directory_path, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            ended_at = excluded.ended_at,
            audio_path = excluded.audio_path,
            directory_path = excluded.directory_path,
            updated_at = excluded.updated_at
        """

        let now = ISO8601DateFormatter().string(from: Date())
        try withStatement(sql) { statement in
            bind(meeting.id.uuidString, to: 1, in: statement)
            bind(meeting.title, to: 2, in: statement)
            bind(Self.format(meeting.startedAt), to: 3, in: statement)
            bind(meeting.endedAt.map(Self.format), to: 4, in: statement)
            bind(meeting.audioURL.path, to: 5, in: statement)
            bind(meeting.directoryURL.path, to: 6, in: statement)
            bind(now, to: 7, in: statement)
            bind(now, to: 8, in: statement)
            try step(statement)
        }
    }

    func insertTranscriptSegment(_ segment: TranscriptSegment) throws {
        let sql = """
        INSERT INTO transcript_segments (
            id, meeting_id, start_ms, end_ms, source_text, translated_text,
            source_language, target_language, is_final, vendor_payload, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try withStatement(sql) { statement in
            bind(segment.id.uuidString, to: 1, in: statement)
            bind(segment.meetingID.uuidString, to: 2, in: statement)
            sqlite3_bind_int64(statement, 3, sqlite3_int64(segment.startMilliseconds))
            bindInt(segment.endMilliseconds, to: 4, in: statement)
            bind(segment.sourceText, to: 5, in: statement)
            bind(segment.translatedText, to: 6, in: statement)
            bind(segment.sourceLanguage, to: 7, in: statement)
            bind(segment.targetLanguage, to: 8, in: statement)
            sqlite3_bind_int(statement, 9, segment.isFinal ? 1 : 0)
            bind(segment.vendorPayload, to: 10, in: statement)
            bind(Self.format(segment.createdAt), to: 11, in: statement)
            try step(statement)
        }
    }

    func fetchRecentMeetings(limit: Int = 8) throws -> [StoredMeetingSummary] {
        let sql = """
        SELECT id, title, started_at, ended_at, directory_path, audio_path
        FROM meetings
        ORDER BY started_at DESC
        LIMIT ?
        """

        var meetings: [StoredMeetingSummary] = []
        try withStatement(sql) { statement in
            sqlite3_bind_int(statement, 1, Int32(limit))

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idText = columnText(statement, 0),
                      let id = UUID(uuidString: idText),
                      let title = columnText(statement, 1),
                      let startedAt = columnText(statement, 2),
                      let directoryPath = columnText(statement, 4),
                      let audioPath = columnText(statement, 5) else {
                    continue
                }

                meetings.append(StoredMeetingSummary(
                    id: id,
                    title: title,
                    startedAt: startedAt,
                    endedAt: columnText(statement, 3),
                    directoryPath: directoryPath,
                    audioPath: audioPath
                ))
            }
        }

        return meetings
    }

    func fetchTranscriptSegments(meetingID: UUID) throws -> [StoredTranscriptSegment] {
        let sql = """
        SELECT start_ms, end_ms, source_text, translated_text,
               source_language, target_language, is_final
        FROM transcript_segments
        WHERE meeting_id = ?
        ORDER BY start_ms ASC
        """

        var segments: [StoredTranscriptSegment] = []
        try withStatement(sql) { statement in
            bind(meetingID.uuidString, to: 1, in: statement)

            while sqlite3_step(statement) == SQLITE_ROW {
                segments.append(StoredTranscriptSegment(
                    startMilliseconds: Int(sqlite3_column_int64(statement, 0)),
                    endMilliseconds: columnInt(statement, 1),
                    sourceText: columnText(statement, 2) ?? "",
                    translatedText: columnText(statement, 3),
                    sourceLanguage: columnText(statement, 4),
                    targetLanguage: columnText(statement, 5),
                    isFinal: sqlite3_column_int(statement, 6) == 1
                ))
            }
        }

        return segments
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS meetings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            mode TEXT,
            source_language TEXT,
            target_language TEXT,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            audio_path TEXT NOT NULL,
            directory_path TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS transcript_segments (
            id TEXT PRIMARY KEY,
            meeting_id TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER,
            source_text TEXT NOT NULL,
            translated_text TEXT,
            source_language TEXT,
            target_language TEXT,
            is_final INTEGER NOT NULL DEFAULT 0,
            vendor_payload TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
        )
        """)

        try execute("CREATE INDEX IF NOT EXISTS idx_meetings_started_at ON meetings(started_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_meetings_updated_at ON meetings(updated_at)")
        try execute("""
        CREATE INDEX IF NOT EXISTS idx_segments_meeting_start
        ON transcript_segments(meeting_id, start_ms)
        """)
        try execute("""
        CREATE INDEX IF NOT EXISTS idx_segments_meeting_final
        ON transcript_segments(meeting_id, is_final)
        """)
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(connection, sql, nil, nil, &error)

        guard result == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? Self.errorMessage(connection)
            sqlite3_free(error)
            throw SQLiteDatabaseError.executeFailed(message)
        }
    }

    private func withStatement(_ sql: String, body: (OpaquePointer?) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteDatabaseError.prepareFailed(Self.errorMessage(connection))
        }

        defer {
            sqlite3_finalize(statement)
        }

        try body(statement)
    }

    private func step(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.executeFailed(Self.errorMessage(connection))
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func bindInt(_ value: Int?, to index: Int32, in statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_int64(statement, index, sqlite3_int64(value))
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: value)
    }

    private func columnInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL {
            return nil
        }

        return Int(sqlite3_column_int64(statement, index))
    }

    private static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func errorMessage(_ database: OpaquePointer?) -> String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "未知 SQLite 错误"
        }

        return String(cString: message)
    }
}

enum SQLiteDatabaseError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)

    var errorDescription: String? {
        switch self {
        case let .openFailed(message):
            "数据库打开失败：\(message)"
        case let .prepareFailed(message):
            "数据库语句准备失败：\(message)"
        case let .executeFailed(message):
            "数据库执行失败：\(message)"
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
