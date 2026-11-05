import Foundation
import Testing
@testable import Enso

@MainActor
struct FolderIconTests {
    @Test func displayIconIsStableForTheSameID() {
        let id = UUID()
        let a = TerminalFolder(id: id, title: "a")
        let b = TerminalFolder(id: id, title: "b")
        #expect(a.displayIcon == b.displayIcon)
    }

    @Test func displayIconIsNeverTheDot() {
        for _ in 0..<200 {
            #expect(TerminalFolder(title: "x").displayIcon != .dot)
        }
    }

    @Test func pickedIconWinsOverTheFallback() {
        let folder = TerminalFolder(title: "x", icon: .symbol("star.fill"))
        #expect(folder.displayIcon == .symbol("star.fill"))
    }

    @Test func folderWithoutIconKeyDecodes() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"Old","items":[]}
        """
        let folder = try JSONDecoder().decode(TerminalFolder.self, from: Data(json.utf8))
        #expect(folder.icon == nil)
    }

    @Test func iconRoundTrips() throws {
        let folder = TerminalFolder(title: "x", icon: .emoji("🌳"))
        let data = try JSONEncoder().encode(folder)
        #expect(try JSONDecoder().decode(TerminalFolder.self, from: data).icon == .emoji("🌳"))
    }
}
