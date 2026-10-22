import AppKit
import PDFKit

@main struct PDFEditorTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let bytes = NSMutableData()
        let consumer = CGDataConsumer(data: bytes as CFMutableData)!
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        for index in 1...3 {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            ("Super Docs PDF page \(index)" as NSString).draw(at: NSPoint(x: 72, y: 700), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()
        let data = bytes as Data
        try data.write(to: URL(fileURLWithPath: ".build/native-tests/viewer-sample.pdf"))
        let viewer = PDFEditor()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = viewer.view
        let detail = try await viewer.load(data, name: "sample.pdf")
        precondition(detail == "3페이지")
        precondition(viewer.saveFormats.first?.fileExtension == "pdf")
        precondition(viewer.pdfView.document?.pageCount == 3)
        viewer.pdfView.goToNextPage(nil)
        precondition(viewer.pdfView.document!.index(for: viewer.pdfView.currentPage!) == 1)
        viewer.pdfView.goToPreviousPage(nil)
        precondition(viewer.pdfView.document!.index(for: viewer.pdfView.currentPage!) == 0)
        let match = viewer.pdfView.document!.findString("page 3", fromSelection: nil, withOptions: .caseInsensitive)
        precondition(match != nil)
        try await viewer.command("edit:select-all")
        precondition(viewer.pdfView.currentSelection?.string?.contains("Super Docs") == true)
        let mark = PDFAnnotation(bounds: NSRect(x: 72, y: 650, width: 200, height: 40), forType: .freeText, withProperties: nil)
        mark.contents = "PDF 저장 검증"
        viewer.pdfView.document!.page(at: 0)!.addAnnotation(mark)
        viewer.pdfView.document!.page(at: 1)!.rotation = 90
        let exported = try await viewer.export(format: "pdf")
        let reopened = PDFDocument(data: exported)!
        precondition(reopened.page(at: 0)!.annotations.contains { $0.contents == "PDF 저장 검증" })
        precondition(reopened.page(at: 1)!.rotation == 90)
        do { _ = try await viewer.load(Data("invalid".utf8), name: "invalid.pdf"); fatalError("Invalid PDF accepted") } catch {}
        let locked = PDFDocument(data: data)!
        let lockedURL = URL(fileURLWithPath: ".build/native-tests/locked.pdf")
        precondition(locked.write(to: lockedURL, withOptions: [.userPasswordOption: "test", .ownerPasswordOption: "owner"]))
        do { _ = try await viewer.load(Data(contentsOf: lockedURL), name: "locked.pdf"); fatalError("Locked PDF accepted") } catch {}
        viewer.close()
        precondition(viewer.pdfView.document == nil)
        print("PDF viewer: page rendering, navigation, search, selection, annotation and rotation persistence, invalid and locked files passed")
    }
}
