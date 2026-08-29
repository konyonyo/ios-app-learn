import Foundation

struct ProfileData {
    var soul = ""
    var user = ""
    var memory = ""

    static func load() -> ProfileData {
        let directory = profileDirectory
        return ProfileData(
            soul: readFile(directory.appendingPathComponent("SOUL.md")),
            user: readFile(directory.appendingPathComponent("USER.md")),
            memory: readFile(directory.appendingPathComponent("MEMORY.md"))
        )
    }

    func save() throws {
        let directory = Self.profileDirectory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try soul.write(
            to: directory.appendingPathComponent("SOUL.md"),
            atomically: true,
            encoding: .utf8
        )
        try user.write(
            to: directory.appendingPathComponent("USER.md"),
            atomically: true,
            encoding: .utf8
        )
        try memory.write(
            to: directory.appendingPathComponent("MEMORY.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static var profileDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport.appendingPathComponent("FamilyAI/Profile")
    }

    private static func readFile(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
