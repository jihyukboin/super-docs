import AppKit
import PDFKit
import UniformTypeIdentifiers

final class PDFViewer: NSObject, DocumentEditor, NSSearchFieldDelegate {
    static let format = DocumentFormat(fileExtension: "pdf", contentType: .pdf, displayName: "PDF 문서 (.pdf)")
    let view = NSView()
    let pdfView = PDFView()
    let saveFormats: [DocumentFormat] = []
    let defaultFormat = PDFViewer.format
    var onReady: (() -> Void)?
    var onChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onTermination: (() -> Void)?
    private let pageLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private var previousButton: NSButton!
    private var nextButton: NSButton!

    override init() {
        super.init()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .underPageBackgroundColor
        func button(_ title: String, _ symbol: String, _ action: Selector) -> NSButton {
            let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title)!, target: self, action: action)
            button.bezelStyle = .texturedRounded
            button.toolTip = title
            button.setAccessibilityLabel(title)
            return button
        }
        previousButton = button("이전 페이지", "chevron.up", #selector(previousPage))
        nextButton = button("다음 페이지", "chevron.down", #selector(nextPage))
        searchField.placeholderString = "PDF에서 찾기"
        searchField.setAccessibilityLabel("PDF에서 찾기")
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(findNext)
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = true
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [previousButton, nextButton, pageLabel, spacer,
            button("축소", "minus.magnifyingglass", #selector(zoomOut)),
            button("확대", "plus.magnifyingglass", #selector(zoomIn)),
            button("페이지 맞춤", "arrow.up.left.and.arrow.down.right", #selector(fitPage)), searchField])
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        for child in [toolbar, pdfView] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor), toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor), searchField.widthAnchor.constraint(equalToConstant: 220),
            pdfView.topAnchor.constraint(equalTo: toolbar.bottomAnchor), pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor), pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(updatePage), name: .PDFViewPageChanged, object: pdfView)
    }

    func start() { onReady?() }
    @MainActor func load(_ bytes: Data, name: String) async throws -> String {
        guard let document = PDFDocument(data: bytes) else { throw AppError.message("올바른 PDF 문서가 아닙니다.") }
        guard !document.isLocked else { throw AppError.message("암호로 잠긴 PDF는 지원하지 않습니다. 잠금을 해제한 후 다시 열어 주세요.") }
        guard document.pageCount > 0 else { throw AppError.message("PDF에 표시할 페이지가 없습니다.") }
        pdfView.document = document
        // A viewer must not allow interactive forms to modify the document.
        for index in 0..<document.pageCount {
            document.page(at: index)?.annotations.filter { $0.type == "Widget" }.forEach { $0.isReadOnly = true }
        }
        updatePage()
        return "\(document.pageCount)페이지"
    }
    @objc private func updatePage() {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return }
        pageLabel.stringValue = "\(document.index(for: page) + 1) / \(document.pageCount)"
        previousButton.isEnabled = pdfView.canGoToPreviousPage
        nextButton.isEnabled = pdfView.canGoToNextPage
    }
    @objc private func previousPage() { pdfView.goToPreviousPage(nil) }
    @objc private func nextPage() { pdfView.goToNextPage(nil) }
    @objc private func zoomIn() { pdfView.autoScales = false; pdfView.zoomIn(nil) }
    @objc private func zoomOut() { pdfView.autoScales = false; pdfView.zoomOut(nil) }
    @objc private func fitPage() { pdfView.autoScales = true }
    @objc private func findNext() {
        guard let document = pdfView.document else { return }
        let query = searchField.stringValue
        guard !query.isEmpty else { pdfView.clearSelection(); return }
        let match = document.findString(query, fromSelection: pdfView.currentSelection, withOptions: .caseInsensitive)
            ?? document.findString(query, fromSelection: nil, withOptions: .caseInsensitive)
        guard let match else { NSSound.beep(); return }
        pdfView.setCurrentSelection(match, animate: true)
        pdfView.scrollSelectionToVisible(nil)
    }
    @MainActor func command(_ id: String) async throws {
        switch id {
        case "edit:find": view.window?.makeFirstResponder(searchField)
        case "edit:select-all": pdfView.selectAll(nil)
        case "edit:copy": pdfView.copy(nil)
        default: break
        }
    }
    func export(format: String) async throws -> Data { throw AppError.message("PDF는 읽기 전용입니다.") }
    func didSave(name: String) async throws {}
    func setStatus(_ text: String) {}
    func setInteractionEnabled(_ enabled: Bool) async throws {}
    func close() { NotificationCenter.default.removeObserver(self); pdfView.document = nil }
}
