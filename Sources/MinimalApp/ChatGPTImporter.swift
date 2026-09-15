import Foundation
import SQLite3
import ZIPFoundation

struct ChatGPTImporter {
    private let store = ChatGPTSQLiteStore()

    func importFile(at url: URL) throws -> ImportResult {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        let conversations: [[String: Any]]
        if url.pathExtension.lowercased() == "zip" {
            conversations = try readConversationsFromZIP(url)
        } else if url.pathExtension.lowercased() == "json" {
            conversations = try parseArray(try Data(contentsOf: url))
        } else {
            throw ChatGPTImportError.unsupportedFile
        }
        return try store.replaceDatabase(with: conversations)
    }

    private func readConversationsFromZIP(_ url: URL) throws -> [[String: Any]] {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw ChatGPTImportError.invalidArchive
        }
        let entries = archive.filter { entry in
            let name = (entry.path as NSString).lastPathComponent
            return name == "conversations.json" ||
                name.range(of: #"^conversations-\d+\.json$"#, options: .regularExpression) != nil
        }.sorted { lhs, rhs in
            fileOrder(lhs.path) < fileOrder(rhs.path)
        }
        guard !entries.isEmpty else { throw ChatGPTImportError.missingConversationJSON }

        var result: [[String: Any]] = []
        for entry in entries {
            var data = Data()
            try archive.extract(entry) { data.append($0) }
            result.append(contentsOf: try parseArray(data))
        }
        return result
    }

    private func parseArray(_ data: Data) throws -> [[String: Any]] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ChatGPTImportError.invalidJSON
        }
        return object
    }

    private func fileOrder(_ path: String) -> Int {
        let name = (path as NSString).lastPathComponent
        if name == "conversations.json" { return -1 }
        let digits = name.dropFirst("conversations-".count).dropLast(".json".count)
        return Int(digits) ?? Int.max
    }
}

struct ImportResult {
    let sourceConversationCount: Int
    let importedConversationCount: Int
    let skippedConversationCount: Int
    let messageCount: Int
    let userMessageCount: Int
    let assistantMessageCount: Int
}

enum ChatGPTImportError: LocalizedError {
    case unsupportedFile
    case invalidArchive
    case missingConversationJSON
    case invalidJSON
    case database(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: return "対応しているのはChatGPTエクスポートのZIPまたはJSONです。"
        case .invalidArchive: return "ZIPファイルを開けませんでした。"
        case .missingConversationJSON: return "ZIP内にconversations.jsonまたは分割ファイルが見つかりません。"
        case .invalidJSON: return "conversations.jsonの形式を読み込めませんでした。"
        case .database(let message): return "検索データベースの作成に失敗しました: \(message)"
        }
    }
}

struct KnowledgeSearchResult: Identifiable {
    let id: Int64
    let conversationID: String
    let title: String
    let role: String
    let content: String
    let timestamp: Date?
}

final class ChatGPTSQLiteStore {
    private let databaseURL: URL

    init(databaseURL: URL? = nil) {
        if let databaseURL { self.databaseURL = databaseURL }
        else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.databaseURL = base.appendingPathComponent("FamilyAI/chatgpt-history.sqlite3")
        }
    }

    var exists: Bool { FileManager.default.fileExists(atPath: databaseURL.path) }

    func replaceDatabase(with rawConversations: [[String: Any]]) throws -> ImportResult {
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")

        var db: OpaquePointer?
        try check(sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil), db: db)
        defer { sqlite3_close(db) }
        do {
            try exec(db, "PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;")
            try exec(db, """
                CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, create_time REAL, update_time REAL, source_json TEXT NOT NULL);
                CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id TEXT NOT NULL REFERENCES conversations(id), source_id TEXT, ordinal INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, timestamp REAL);
                CREATE INDEX messages_conversation_ordinal ON messages(conversation_id, ordinal);
                CREATE VIRTUAL TABLE messages_fts USING fts5(content, conversation_id UNINDEXED, role UNINDEXED, content='messages', content_rowid='id', tokenize='trigram');
                """)

            var imported = 0, skipped = 0, messageCount = 0, userCount = 0, assistantCount = 0
            for (index, conversation) in rawConversations.enumerated() {
                let rows = messageRows(from: conversation)
                guard !rows.isEmpty else { skipped += 1; continue }
                let conversationID = (conversation["conversation_id"] as? String) ?? (conversation["id"] as? String) ?? "conversation-\(index)"
                let title = ((conversation["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "無題"
                let sourceData = try JSONSerialization.data(withJSONObject: conversation)
                let sourceJSON = String(data: sourceData, encoding: .utf8) ?? "{}"
                try insertConversation(db, id: conversationID, title: title, create: number(conversation["create_time"]), update: number(conversation["update_time"]), source: sourceJSON)
                for (ordinal, row) in rows.enumerated() {
                    try insertMessage(db, conversationID: conversationID, sourceID: row.id, ordinal: ordinal, role: row.role, content: row.text, timestamp: row.timestamp)
                    messageCount += 1
                    if row.role == "user" { userCount += 1 } else { assistantCount += 1 }
                }
                imported += 1
            }
            try exec(db, "INSERT INTO metadata(key, value) VALUES ('format', 'chatgpt-export-v1');")
            try exec(db, "PRAGMA wal_checkpoint(TRUNCATE);")
            return ImportResult(sourceConversationCount: rawConversations.count, importedConversationCount: imported, skippedConversationCount: skipped, messageCount: messageCount, userMessageCount: userCount, assistantMessageCount: assistantCount)
        } catch { throw error }
    }

    func search(_ query: String, limit: Int = 12) throws -> [KnowledgeSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, exists else { return [] }
        var db: OpaquePointer?
        try check(sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil), db: db)
        defer { sqlite3_close(db) }
        let sql = "SELECT m.id, m.conversation_id, c.title, m.role, m.content, m.timestamp FROM messages_fts f JOIN messages m ON m.id = f.rowid JOIN conversations c ON c.id = m.conversation_id WHERE messages_fts MATCH ? ORDER BY rank LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw ChatGPTImportError.database(errorMessage(db)) }
        defer { sqlite3_finalize(statement) }
        bindText(statement, index: 1, value: "\"\(query.replacingOccurrences(of: "\"", with: "\"\""))\"")
        sqlite3_bind_int(statement, 2, Int32(limit))
        var results: [KnowledgeSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(KnowledgeSearchResult(id: sqlite3_column_int64(statement, 0), conversationID: columnText(statement, 1), title: columnText(statement, 2), role: columnText(statement, 3), content: columnText(statement, 4), timestamp: sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))))
        }
        return results
    }

    private struct Row { let id: String; let role: String; let text: String; let timestamp: Double? }

    private func messageRows(from conversation: [String: Any]) -> [Row] {
        guard let mapping = conversation["mapping"] as? [String: Any] else { return [] }
        var nodeID = conversation["current_node"] as? String
        var nodes: [[String: Any]] = []
        var seen = Set<String>()
        while let id = nodeID, !seen.contains(id), let node = mapping[id] as? [String: Any] {
            seen.insert(id); nodes.append(node); nodeID = node["parent"] as? String
        }
        return nodes.reversed().compactMap { node in
            guard let message = node["message"] as? [String: Any], let author = message["author"] as? [String: Any], let role = author["role"] as? String, role == "user" || role == "assistant", let content = message["content"] as? [String: Any], let parts = content["parts"] as? [Any] else { return nil }
            let text = parts.compactMap { part -> String? in
                if let string = part as? String { return string }
                if let object = part as? [String: Any] { return object["text"] as? String ?? object["caption"] as? String }
                return nil
            }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Row(id: message["id"] as? String ?? UUID().uuidString, role: role, text: text, timestamp: number(message["create_time"]))
        }
    }

    private func insertConversation(_ db: OpaquePointer?, id: String, title: String, create: Double?, update: Double?, source: String) throws {
        try withStatement(db, "INSERT INTO conversations(id,title,create_time,update_time,source_json) VALUES (?,?,?,?,?)") { statement in
            bindText(statement, index: 1, value: id); bindText(statement, index: 2, value: title); bindNumber(statement, index: 3, value: create); bindNumber(statement, index: 4, value: update); bindText(statement, index: 5, value: source); try step(statement, db: db)
        }
    }

    private func insertMessage(_ db: OpaquePointer?, conversationID: String, sourceID: String, ordinal: Int, role: String, content: String, timestamp: Double?) throws {
        try withStatement(db, "INSERT INTO messages(conversation_id,source_id,ordinal,role,content,timestamp) VALUES (?,?,?,?,?,?)") { statement in
            bindText(statement, index: 1, value: conversationID); bindText(statement, index: 2, value: sourceID); sqlite3_bind_int(statement, 3, Int32(ordinal)); bindText(statement, index: 4, value: role); bindText(statement, index: 5, value: content); bindNumber(statement, index: 6, value: timestamp); try step(statement, db: db)
            let rowID = sqlite3_last_insert_rowid(db)
            try withStatement(db, "INSERT INTO messages_fts(rowid,content,conversation_id,role) VALUES (?,?,?,?)") { fts in
                sqlite3_bind_int64(fts, 1, rowID); bindText(fts, index: 2, value: content); bindText(fts, index: 3, value: conversationID); bindText(fts, index: 4, value: role); try step(fts, db: db)
            }
        }
    }

    private func withStatement(_ db: OpaquePointer?, _ sql: String, _ body: (OpaquePointer?) throws -> Void) throws { var statement: OpaquePointer?; guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw ChatGPTImportError.database(errorMessage(db)) }; defer { sqlite3_finalize(statement) }; try body(statement) }
    private func step(_ statement: OpaquePointer?, db: OpaquePointer?) throws { guard sqlite3_step(statement) == SQLITE_DONE else { throw ChatGPTImportError.database(errorMessage(db)) } }
    private func exec(_ db: OpaquePointer?, _ sql: String) throws { guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw ChatGPTImportError.database(errorMessage(db)) } }
    private func check(_ result: Int32, db: OpaquePointer?) throws { guard result == SQLITE_OK else { throw ChatGPTImportError.database(errorMessage(db)) } }
    private func errorMessage(_ db: OpaquePointer?) -> String { String(cString: sqlite3_errmsg(db)) }
    private func bindText(_ statement: OpaquePointer?, index: Int32, value: String) { sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    private func bindNumber(_ statement: OpaquePointer?, index: Int32, value: Double?) { if let value { sqlite3_bind_double(statement, index, value) } else { sqlite3_bind_null(statement, index) } }
    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String { String(cString: sqlite3_column_text(statement, index)) }
    private func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
}
