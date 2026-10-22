import AppKit
import WebKit
import UniformTypeIdentifiers

// Preserve the source encoding and BOM instead of silently replacing undecodable text.
struct TextFile {
    var text: String
    let encoding: String.Encoding
    let prefix: Data

    init(_ bytes: Data) throws {
        let signatures: [(Data, String.Encoding)] = [
            (Data([0xef, 0xbb, 0xbf]), .utf8),
            (Data([0xff, 0xfe]), .utf16LittleEndian),
            (Data([0xfe, 0xff]), .utf16BigEndian)
        ]
        let match = signatures.first { bytes.starts(with: $0.0) }
        prefix = match?.0 ?? Data()
        encoding = match?.1 ?? .utf8
        guard let decoded = String(data: bytes.dropFirst(prefix.count), encoding: encoding) else {
            throw AppError.message("텍스트 인코딩을 읽을 수 없습니다. UTF-8 또는 UTF-16으로 저장한 파일을 열어 주세요.")
        }
        text = decoded
    }
    func data() throws -> Data {
        guard let bytes = text.data(using: encoding, allowLossyConversion: false) else {
            throw AppError.message("원본 인코딩으로 저장할 수 없는 문자가 있습니다.")
        }
        return prefix + bytes
    }
}

final class TextEditor: NSObject, DocumentEditor, NSTextViewDelegate, WKNavigationDelegate {
    static let txt = DocumentFormat(fileExtension: "txt", contentType: .plainText, displayName: "텍스트 (.txt)")
    static let markdown = DocumentFormat(fileExtension: "md", contentType: UTType(filenameExtension: "md") ?? .plainText, displayName: "Markdown (.md)")
    static let markdownLong = DocumentFormat(fileExtension: "markdown", contentType: UTType(filenameExtension: "markdown") ?? .plainText, displayName: "Markdown (.markdown)")
    static let formats = [txt, markdown, markdownLong]
    let defaultFormat: DocumentFormat
    var saveFormats: [DocumentFormat] { Self.formats }
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
    let textView = NSTextView()
    private let preview = WKWebView()
    private let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
    private var source = try! TextFile(Data())
    private var isMarkdown: Bool
    var onReady: (() -> Void)?
    var onChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onTermination: (() -> Void)?

    init(format: DocumentFormat, previewURL: URL? = nil) {
        defaultFormat = format
        isMarkdown = ["md", "markdown"].contains(format.fileExtension)
        super.init()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.delegate = self
        textView.usesFindBar = true
        textView.setAccessibilityLabel("문서 본문")
        preview.navigationDelegate = self
        preview.setAccessibilityLabel("Markdown 미리보기")
        if let previewURL { preview.load(URLRequest(url: previewURL)) }
        split.isVertical = true
        split.dividerStyle = .thin
        let editorScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 800))
        textView.frame = editorScroll.bounds
        preview.frame = NSRect(x: 500, y: 0, width: 500, height: 800)
        for (scroll, text) in [(editorScroll, textView)] {
            scroll.hasVerticalScroller = true
            scroll.documentView = text
            text.isVerticallyResizable = true
            text.isHorizontallyResizable = false
            text.autoresizingMask = [.width]
            text.textContainer?.widthTracksTextView = true
            text.minSize = .zero
            text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            split.addArrangedSubview(scroll)
        }
        split.addArrangedSubview(preview)
        preview.isHidden = !isMarkdown
        split.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(split)
        NSLayoutConstraint.activate([split.leadingAnchor.constraint(equalTo: view.leadingAnchor), split.trailingAnchor.constraint(equalTo: view.trailingAnchor), split.topAnchor.constraint(equalTo: view.topAnchor), split.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
    }
    func start() { onReady?() }
    @MainActor func load(_ bytes: Data, name: String) async throws -> String {
        source = try TextFile(bytes)
        textView.string = source.text
        textView.undoManager?.removeAllActions()
        view.layoutSubtreeIfNeeded()
        split.adjustSubviews()
        if isMarkdown { split.setPosition(split.bounds.width / 2, ofDividerAt: 0) }
        renderPreview()
        return "\(source.text.count)자"
    }
    func textDidChange(_ notification: Notification) { renderPreview(); onChange?() }
    private func renderPreview() {
        guard isMarkdown else { return }
        preview.callAsyncJavaScript("window.renderMarkdown?.(text)", arguments: ["text": textView.string], in: nil, in: .page, completionHandler: nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { renderPreview() }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
    }
    @MainActor func export(format: String) async throws -> Data {
        guard saveFormats.contains(where: { $0.fileExtension == format }) else { throw AppError.message("지원하지 않는 텍스트 형식입니다.") }
        source.text = textView.string
        return try source.data()
    }
    @MainActor func didSave(name: String) async throws {
        isMarkdown = ["md", "markdown"].contains((name as NSString).pathExtension.lowercased())
        preview.isHidden = !isMarkdown
        renderPreview()
    }
    @MainActor func command(_ id: String) async throws {
        switch id {
        case "edit:undo": textView.undoManager?.undo()
        case "edit:redo": textView.undoManager?.redo()
        case "edit:select-all": textView.selectAll(nil)
        case "edit:find":
            view.window?.makeFirstResponder(textView)
            let item = NSMenuItem(); item.tag = NSTextFinder.Action.showFindInterface.rawValue
            textView.performTextFinderAction(item)
        default: break
        }
    }
    func setStatus(_ text: String) {}
    @MainActor func setInteractionEnabled(_ enabled: Bool) async throws { textView.isEditable = enabled }
    func close() { textView.delegate = nil }
}
