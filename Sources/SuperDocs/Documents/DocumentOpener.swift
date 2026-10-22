import AppKit
import PDFKit
import UniformTypeIdentifiers

enum DocumentOpener {
    static let formats = HWPFormat.formats + [DOCXFormat.docx] + OfficeFormat.formats + [PDFEditor.format] + TextEditor.formats + [CSVEditor.format]
    static var contentTypes: [UTType] { formats.map(\.contentType) }

    static func newDocument(app: SuperDocsApp, format: String = "hwpx") throws -> DocumentWindowController {
        let bytes: Data
        switch format {
        case "hwpx", "hwp": bytes = try HWPFormat.blankDocument()
        case "txt", "md", "markdown", "csv": bytes = Data()
        case "pdf":
            let document = PDFDocument(); let page = PDFPage()
            page.setBounds(NSRect(x: 0, y: 0, width: 595, height: 842), for: .mediaBox)
            document.insert(page, at: 0)
            guard let data = document.dataRepresentation() else { throw AppError.message("새 PDF를 만들지 못했습니다.") }
            bytes = data
        default:
            guard ["docx", "xlsx", "pptx"].contains(format), let url = Bundle.main.url(forResource: "Blank", withExtension: format, subdirectory: "Templates") else { throw AppError.message("새 문서 서식을 찾을 수 없습니다.") }
            bytes = try Data(contentsOf: url)
        }
        return try makeWindow(app: app, bytes: bytes, url: nil, format: format)
    }

    static func open(_ url: URL, app: SuperDocsApp) throws -> DocumentWindowController {
        guard formats.contains(where: { $0.fileExtension == url.pathExtension.lowercased() }) else {
            throw AppError.message("지원하는 문서 형식을 선택해 주세요.")
        }
        return try makeWindow(app: app, bytes: Data(contentsOf: url), url: url)
    }

    private static func makeWindow(app: SuperDocsApp, bytes: Data, url: URL?, format: String? = nil) throws -> DocumentWindowController {
        let editor: DocumentEditor
        switch format ?? url?.pathExtension.lowercased() {
        case "xlsx": editor = try WebDocumentEditor(baseURL: app.server.baseURL, entryPath: "office/index.html", formats: [OfficeFormat.xlsx])
        case "pptx": editor = try WebDocumentEditor(baseURL: app.server.baseURL, entryPath: "office/index.html", formats: [OfficeFormat.pptx])
        case "csv": editor = CSVEditor()
        case "txt": editor = TextEditor(format: TextEditor.txt, previewURL: app.server.baseURL.appendingPathComponent("markdown/index.html"))
        case "md", "markdown": editor = TextEditor(format: TextEditor.markdown, previewURL: app.server.baseURL.appendingPathComponent("markdown/index.html"))
        case "pdf": editor = PDFEditor()
        case "docx": editor = try WebDocumentEditor(baseURL: app.server.baseURL, entryPath: "docx/index.html", formats: [DOCXFormat.docx])
        default: editor = try WebDocumentEditor(baseURL: app.server.baseURL)
        }
        return DocumentWindowController(app: app, session: DocumentSession(bytes: bytes, url: url), editor: editor)
    }
}
