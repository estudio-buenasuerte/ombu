import AppKit
import Testing
@testable import Enso

@MainActor
struct PasteboardImagePasteTests {
    @Test func stringOnlyIsNotAnImagePaste() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.setString("text\nwith\ttabs", forType: .string))

        #expect(!GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
    }

    @Test func stringTakesPriorityOverImage() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        let png = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))
        #expect(pasteboard.setData(png, forType: .png))
        #expect(pasteboard.setString("text", forType: .string))

        #expect(!GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
    }

    @Test func imageDataOnlyIsAnImagePaste() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let png = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))
        let bitmap = try #require(NSBitmapImageRep(data: png))
        let tiff = try #require(bitmap.tiffRepresentation)
        for (type, data) in [(NSPasteboard.PasteboardType.png, png), (.tiff, tiff)] {
            pasteboard.clearContents()
            #expect(pasteboard.setData(data, forType: type))

            #expect(GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
        }
    }

    @Test func imageFileURLOnlyIsAnImagePaste() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/clipboard-image.png") as NSURL]))

        #expect(GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
    }

    @Test func textFileURLOnlyIsNotAnImagePaste() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/clipboard-text.txt") as NSURL]))

        #expect(!GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
    }

    @Test func emptyPasteboardIsNotAnImagePaste() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteboardImagePasteTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        #expect(!GhosttySurfaceView.pasteboardHoldsImageOnly(pasteboard))
    }
}
