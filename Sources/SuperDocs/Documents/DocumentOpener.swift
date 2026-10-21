import AppKit
import UniformTypeIdentifiers

enum DocumentOpener {
    static var contentTypes: [UTType] { HWPFormat.formats.map(\.contentType) }

    static func newDocument(app: SuperDocsApp) throws -> DocumentWindowController {
        try makeWindow(app: app, bytes: HWPFormat.blankDocument(), url: nil)
    }

    static func open(_ url: URL, app: SuperDocsApp) throws -> DocumentWindowController {
        guard HWPFormat.formats.contains(where: { $0.fileExtension == url.pathExtension.lowercased() }) else {
            throw AppError.message("HWP 또는 HWPX 문서를 선택해 주세요.")
        }
        return try makeWindow(app: app, bytes: Data(contentsOf: url), url: url)
    }

    private static func makeWindow(app: SuperDocsApp, bytes: Data, url: URL?) throws -> DocumentWindowController {
        let editor = try HWPEditor(baseURL: app.server.baseURL)
        return DocumentWindowController(app: app, session: DocumentSession(bytes: bytes, url: url), editor: editor)
    }
}
