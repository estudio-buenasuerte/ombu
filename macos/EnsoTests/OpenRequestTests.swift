import Foundation
import Testing
@testable import Enso

struct OpenRequestTests {
    @Test func sshWithUserAndPort() throws {
        let url = try #require(URL(string: "ssh://lucas@example.com:2222"))
        #expect(OpenRequest.parse(url) == .command(
            directory: NSHomeDirectory(), input: "ssh -p 2222 lucas@example.com\n"
        ))
    }

    @Test func sshWithoutUser() throws {
        let url = try #require(URL(string: "ssh://example.com"))
        #expect(OpenRequest.parse(url) == .command(
            directory: NSHomeDirectory(), input: "ssh example.com\n"
        ))
    }

    @Test func sshWithoutHost() throws {
        let url = try #require(URL(string: "ssh:///"))
        #expect(OpenRequest.parse(url) == nil)
    }

    @Test func sshSchemeIsCaseInsensitive() throws {
        let url = try #require(URL(string: "SSH://example.com"))
        #expect(OpenRequest.parse(url) == .command(
            directory: NSHomeDirectory(), input: "ssh example.com\n"
        ))
    }

    @Test func sshDecodesAndEscapesUser() throws {
        let url = try #require(URL(string: "ssh://o%27brien@example.com"))
        #expect(OpenRequest.parse(url) == .command(
            directory: NSHomeDirectory(), input: "ssh 'o'\\''brien'@example.com\n"
        ))
    }

    @Test func directoryUsesStandardizedPath() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent(".", isDirectory: true)
        #expect(OpenRequest.parse(url) == .directory(root.standardizedFileURL.path))
    }

    @Test func executableFileUsesQuotedPath() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let script = root.appendingPathComponent("executable script")
        try "#!/bin/sh\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        #expect(OpenRequest.parse(script) == .command(
            directory: root.standardizedFileURL.path, input: "'\(script.standardizedFileURL.path)'\n"
        ))
    }

    @Test(arguments: ["command", "sh", "tool", "zsh", "bash"])
    func nonExecutableScriptUsesSh(extension scriptExtension: String) throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let script = root.appendingPathComponent("script.\(scriptExtension)")
        try "echo hello\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: script.path)
        #expect(OpenRequest.parse(script) == .command(
            directory: root.standardizedFileURL.path, input: "sh '\(script.standardizedFileURL.path)'\n"
        ))
    }

    @Test func plainFileUsesParentDirectory() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect(OpenRequest.parse(file) == .directory(root.standardizedFileURL.path))
    }

    @Test func singleQuoteInPathIsEscaped() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let script = root.appendingPathComponent("it's.command")
        try "#!/bin/sh\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        #expect(OpenRequest.parse(script) == .command(
            directory: root.standardizedFileURL.path,
            input: "'\(root.standardizedFileURL.path)/it'\\''s.command'\n"
        ))
    }

    @Test func unsupportedURLIsIgnored() throws {
        let url = try #require(URL(string: "https://example.com"))
        #expect(OpenRequest.parse(url) == nil)
    }

    @Test func missingFileIsIgnored() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(OpenRequest.parse(root.appendingPathComponent("missing.sh")) == nil)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenRequestTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
