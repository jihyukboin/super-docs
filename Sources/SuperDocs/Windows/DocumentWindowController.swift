import AppKit

final class DocumentWindowController: NSWindowController, NSWindowDelegate {
    unowned let app: SuperDocsApp
    private let session: DocumentSession
    private let editor: DocumentEditor
    var fileURL: URL? { session.fileURL }
    var dirty: Bool { session.dirty }
    private var ready = false
    private var saving = false
    private var allowClose = false
    private var closePending = false
    private weak var activeSavePanel: NSSavePanel?
    private var statusText = "편집기 준비 중…" {
        didSet { editor.setStatus(statusText) }
    }
    private var formatName: String { fileURL?.pathExtension.lowercased() ?? editor.defaultFormat.fileExtension }

    init(app: SuperDocsApp, session: DocumentSession, editor: DocumentEditor) {
        self.app = app
        self.session = session
        self.editor = editor
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 860), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self; window.minSize = NSSize(width: 820, height: 560)
        window.title = fileURL?.lastPathComponent ?? "제목 없음"
        window.representedURL = fileURL; window.center(); window.setFrameAutosaveName("SuperDocsEditor")
        window.contentView = editor.view
        editor.onReady = { [weak self] in self?.loadDocument() }
        editor.onOpen = { [weak self] in self?.app.openPanel(nil) }
        editor.onSave = { [weak self] in Task { @MainActor in _ = await self?.save() } }
        editor.onChange = { [weak self] in
            guard let self, self.ready else { return }
            self.session.markChanged()
            self.window?.isDocumentEdited = true
            self.statusText = "\(self.formatName.uppercased()) · 변경 사항 있음"
        }
        editor.onError = { [weak self] error in self?.app.showError(error) }
        editor.onTermination = { [weak self] in
            self?.ready = false
            self?.statusText = "편집 엔진이 종료되었습니다 · 문서를 다시 열어 주세요"
        }
        editor.start()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func loadDocument() {
        Task { @MainActor in
            do {
                let detail = try await editor.load(session.initialBytes, name: fileURL?.lastPathComponent ?? "제목 없음." + editor.defaultFormat.fileExtension)
                ready = true
                session.didLoad()
                statusText = "\(formatName.uppercased()) · \(detail) · 저장됨"
                window?.makeFirstResponder(editor.view)
            } catch { statusText = "문서를 열지 못했습니다"; app.showError(error) }
        }
    }

    func command(_ id: String) {
        guard ready, !saving else { return }
        Task { @MainActor in
            do { try await editor.command(id) }
            catch { app.showError(error) }
        }
    }

    @MainActor func save(asNew: Bool = false) async -> Bool {
        guard ready, !saving else { return false }
        saving = true
        defer { saving = false }
        var destination = fileURL
        if asNew || destination == nil {
            let panel = NSSavePanel(); panel.title = "문서 저장"
            panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "제목 없음." + editor.defaultFormat.fileExtension
            let popup = NSPopUpButton(frame: NSRect(x: 90, y: 8, width: 180, height: 26))
            popup.addItems(withTitles: editor.saveFormats.map(\.displayName))
            popup.selectItem(at: editor.saveFormats.firstIndex(where: { $0.fileExtension == formatName }) ?? 0)
            popup.target = self; popup.action = #selector(saveFormatChanged(_:))
            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 42))
            let label = NSTextField(labelWithString: "파일 형식:"); label.frame = NSRect(x: 8, y: 12, width: 80, height: 20)
            accessory.addSubview(label); accessory.addSubview(popup); panel.accessoryView = accessory
            panel.allowedContentTypes = [(editor.saveFormats.first { $0.fileExtension == formatName } ?? editor.defaultFormat).contentType]
            panel.canCreateDirectories = true; panel.isExtensionHidden = false
            activeSavePanel = panel
            let response = await withCheckedContinuation { continuation in panel.beginSheetModal(for: window!) { continuation.resume(returning: $0) } }
            activeSavePanel = nil
            guard response == .OK, let url = panel.url else { return false }
            destination = url
        }
        guard let target = destination else { return false }
        let format = target.pathExtension.lowercased()
        guard editor.saveFormats.contains(where: { $0.fileExtension == format }) else { app.showError(AppError.message("지원하지 않는 저장 형식입니다.")); return false }
        statusText = "저장 중…"
        do {
            try session.checkForExternalChanges(at: target)
            try await editor.setInteractionEnabled(false)
            let bytes = try await editor.export(format: format)
            try session.write(bytes, to: target)
            // Only successful persistence and engine acknowledgement clear dirty state.
            try await editor.didSave(name: target.lastPathComponent)
            session.markSaved()
            window?.isDocumentEdited = false; window?.title = target.lastPathComponent; window?.representedURL = target
            statusText = "\(format.uppercased()) · 저장됨"
            NSDocumentController.shared.noteNewRecentDocumentURL(target)
            try? await editor.setInteractionEnabled(true)
            return true
        } catch {
            try? await editor.setInteractionEnabled(true)
            statusText = "저장하지 못함 · 변경 사항 유지됨"; app.showError(error); return false
        }
    }
    @objc func saveFormatChanged(_ sender: NSPopUpButton) {
        guard let panel = activeSavePanel else { return }
        let format = editor.saveFormats[sender.indexOfSelectedItem]
        let ext = format.fileExtension
        panel.allowedContentTypes = [format.contentType]
        let name = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = name + "." + ext
    }
    @MainActor func confirmDiscard() async -> Bool {
        guard dirty else { return true }
        if saving { return false }
        let alert = NSAlert(); alert.messageText = "‘\(window?.title ?? "문서")’의 변경 사항을 저장할까요?"
        alert.informativeText = "저장하지 않고 닫으면 편집한 내용이 사라집니다."
        alert.addButton(withTitle: "저장"); alert.addButton(withTitle: "저장 안 함"); alert.addButton(withTitle: "취소")
        let response = await withCheckedContinuation { continuation in alert.beginSheetModal(for: window!) { continuation.resume(returning: $0) } }
        if response == .alertFirstButtonReturn { return await save() }
        return response == .alertSecondButtonReturn
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowClose || !dirty { return !saving }
        if !closePending {
            closePending = true
            Task { @MainActor in
                if await confirmDiscard() { allowClose = true; sender.close() }
                closePending = false
            }
        }
        return false
    }
    func windowWillClose(_ notification: Notification) {
        editor.close()
        app.documents.removeAll { $0 === self }
    }
}
