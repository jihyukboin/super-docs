import AppKit
import PDFKit
import UniformTypeIdentifiers

final class PDFEditor: NSObject, DocumentEditor, NSSearchFieldDelegate {
    static let format = DocumentFormat(fileExtension: "pdf", contentType: .pdf, displayName: "PDF 문서 (.pdf)")
    let view = NSView()
    let pdfView = PDFView()
    let saveFormats: [DocumentFormat] = [PDFEditor.format]
    private let history = UndoManager()
    let defaultFormat = PDFEditor.format
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
        let editing = NSPopUpButton()
        editing.addItems(withTitles: ["PDF 편집", "선택한 텍스트 강조", "텍스트 메모 추가", "페이지 회전", "페이지 삭제"])
        editing.target = self; editing.action = #selector(editPDF(_:))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [previousButton, nextButton, pageLabel, editing, spacer,
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
        NotificationCenter.default.addObserver(self, selector: #selector(annotationWillEdit(_:)), name: .PDFViewAnnotationWillHit, object: pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePage), name: .PDFViewPageChanged, object: pdfView)
    }

    func start() { onReady?() }
    @MainActor func load(_ bytes: Data, name: String) async throws -> String {
        guard let document = PDFDocument(data: bytes) else { throw AppError.message("올바른 PDF 문서가 아닙니다.") }
        guard !document.isLocked else { throw AppError.message("암호로 잠긴 PDF는 지원하지 않습니다. 잠금을 해제한 후 다시 열어 주세요.") }
        guard document.pageCount > 0 else { throw AppError.message("PDF에 표시할 페이지가 없습니다.") }
        view.layoutSubtreeIfNeeded()
        pdfView.document = document
        pdfView.layoutDocumentView()
        if let first = document.page(at: 0) {
            let bounds = first.bounds(for: .cropBox)
            pdfView.go(to: PDFDestination(page: first, at: NSPoint(x: bounds.minX, y: bounds.maxY)))
        }
        history.removeAllActions()
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
        case "edit:undo": history.undo()
        case "edit:redo": history.redo()
        case "edit:find": view.window?.makeFirstResponder(searchField)
        case "edit:select-all": pdfView.selectAll(nil)
        case "edit:copy": pdfView.copy(nil)
        default: break
        }
    }
    @MainActor func export(format: String) async throws -> Data {
        view.window?.makeFirstResponder(pdfView)
        guard format == "pdf", let bytes = pdfView.document?.dataRepresentation() else { throw AppError.message("PDF 저장 데이터를 만들지 못했습니다.") }
        return bytes
    }
    @objc private func annotationWillEdit(_ notification: Notification) {
        let annotation = notification.userInfo?.values.compactMap { $0 as? PDFAnnotation }.first
        guard let annotation, ["FreeText", "Widget"].contains(annotation.type ?? ""), !annotation.isReadOnly,
              let document = pdfView.document, let bytes = document.dataRepresentation() else { return }
        let index = pdfView.currentPage.map { document.index(for: $0) } ?? 0
        history.registerUndo(withTarget: self) { $0.restore(bytes, page: index) }
        // PDFKit owns field editing; mark before it starts so closing an active field cannot lose edits.
        onChange?()
    }
    private func restore(_ bytes: Data, page index: Int) {
        guard let document = pdfView.document, let old = document.dataRepresentation(), let restored = PDFDocument(data: bytes) else { return }
        let oldIndex = pdfView.currentPage.map { document.index(for: $0) } ?? 0
        history.registerUndo(withTarget: self) { $0.restore(old, page: oldIndex) }
        pdfView.document = restored
        if let page = restored.page(at: min(index, restored.pageCount - 1)) { pdfView.go(to: page) }
        updatePage(); onChange?()
    }
    private func change(_ action: () -> Void) {
        guard let document = pdfView.document, let old = document.dataRepresentation() else { return }
        let index = pdfView.currentPage.map { document.index(for: $0) } ?? 0
        history.registerUndo(withTarget: self) { $0.restore(old, page: index) }
        action()
        pdfView.layoutDocumentView(); pdfView.needsDisplay = true
        updatePage(); onChange?()
    }
    @objc private func editPDF(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        sender.selectItem(at: 0)
        guard let document = pdfView.document, let page = pdfView.currentPage else { return }
        switch index {
        case 1:
            guard let selection = pdfView.currentSelection, !(selection.string ?? "").isEmpty else { NSSound.beep(); return }
            change {
                for line in selection.selectionsByLine() {
                    for selectedPage in line.pages {
                        let mark = PDFAnnotation(bounds: line.bounds(for: selectedPage), forType: .highlight, withProperties: nil)
                        mark.color = .systemYellow.withAlphaComponent(0.45)
                        selectedPage.addAnnotation(mark)
                    }
                }
            }
        case 2:
            let alert = NSAlert(); alert.messageText = "텍스트 메모 추가"
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 28))
            field.placeholderString = "메모 내용"; alert.accessoryView = field
            alert.addButton(withTitle: "추가"); alert.addButton(withTitle: "취소")
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return }
            change {
                let bounds = page.bounds(for: .cropBox)
                let annotation = PDFAnnotation(bounds: NSRect(x: bounds.minX + 24, y: bounds.maxY - 100, width: min(280, bounds.width - 48), height: 72), forType: .freeText, withProperties: nil)
                annotation.contents = field.stringValue
                annotation.font = .systemFont(ofSize: 14)
                annotation.fontColor = .black
                annotation.color = .systemYellow.withAlphaComponent(0.25)
                page.addAnnotation(annotation)
            }
        case 3: change { page.rotation = (page.rotation + 90) % 360 }
        case 4:
            guard document.pageCount > 1 else { NSSound.beep(); return }
            change { document.removePage(at: document.index(for: page)) }
        default: break
        }
    }
    func didSave(name: String) async throws {}
    func setStatus(_ text: String) {}
    func setInteractionEnabled(_ enabled: Bool) async throws {}
    func close() { NotificationCenter.default.removeObserver(self); pdfView.document = nil }
}
