import AppKit
import WebKit
import CryptoKit

final class EditorWindow: NSWindowController, NSWindowDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
    unowned let app: SuperDocsApp
    let webView: WKWebView
    var fileURL: URL?
    private var initialBytes: Data
    private var diskHash: Data?
    private(set) var dirty = false
    private var ready = false
    private var saving = false
    private var allowClose = false
    private var closePending = false
    private weak var activeSavePanel: NSSavePanel?
    private let status = NSTextField(labelWithString: "편집기 준비 중…")
    private var formatName: String { fileURL?.pathExtension.lowercased() ?? "hwpx" }

    init(app: SuperDocsApp, bytes: Data, url: URL?) throws {
        self.app = app; self.initialBytes = bytes; self.fileURL = url
        if url != nil { diskHash = Data(SHA256.hash(data: bytes)) }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = ProcessInfo.processInfo.environment["SUPERDOCS_INSPECT"] == "1"
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 860), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self; window.minSize = NSSize(width: 820, height: 560)
        window.title = url?.lastPathComponent ?? "제목 없음"
        window.representedURL = url; window.center(); window.setFrameAutosaveName("SuperDocsEditor")
        webView.navigationDelegate = self; webView.uiDelegate = self
        config.userContentController.add(self, name: "superDocs")
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "superDocsClipboard")
        let view = NSView(); view.translatesAutoresizingMaskIntoConstraints = false
        let bar = NSStackView(); bar.orientation = .horizontal; bar.spacing = 10
        bar.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        let open = NSButton(title: "열기", target: app, action: #selector(SuperDocsApp.openPanel(_:)))
        let save = NSButton(title: "저장", target: app, action: #selector(SuperDocsApp.saveDocument(_:)))
        open.bezelStyle = .rounded; save.bezelStyle = .rounded
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        bar.addArrangedSubview(open); bar.addArrangedSubview(save); bar.addArrangedSubview(status)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); bar.addArrangedSubview(spacer)
        let brand = NSTextField(labelWithString: "SUPER DOCS"); brand.font = .systemFont(ofSize: 11, weight: .semibold); brand.textColor = .secondaryLabelColor; bar.addArrangedSubview(brand)
        let stack = NSStackView(views: [bar, webView]); stack.orientation = .vertical; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = view; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor), stack.topAnchor.constraint(equalTo: view.topAnchor), stack.bottomAnchor.constraint(equalTo: view.bottomAnchor), bar.widthAnchor.constraint(equalTo: stack.widthAnchor), webView.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        var parts = URLComponents(url: app.server.baseURL, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "chrome", value: "embed"), URLQueryItem(name: "lang", value: "ko"), URLQueryItem(name: "renderer", value: "canvas2d")]
        webView.load(URLRequest(url: parts.url!))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.absoluteString.hasPrefix(app.server.baseURL.absoluteString) == true,
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            Task { @MainActor in
                do {
                    let result = try await js("return await window.superDocs.load(bytes, name)", ["bytes": initialBytes.base64EncodedString(), "name": fileURL?.lastPathComponent ?? "제목 없음.hwpx"])
                    let pages = (result as? [String: Any])?["pages"] as? Int ?? 1
                    ready = true; initialBytes = Data()
                    status.stringValue = "\(formatName.uppercased()) · \(pages)쪽 · 저장됨"
                    webView.window?.makeFirstResponder(webView)
                } catch { status.stringValue = "문서를 열지 못했습니다"; app.showError(error) }
            }
        case "changed":
            if ready { dirty = true; window?.isDocumentEdited = true; status.stringValue = "\(formatName.uppercased()) · 변경 사항 있음" }
        case "error": app.showError(AppError.message(body["message"] as? String ?? "편집기를 시작하지 못했습니다."))
        default: break
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.absoluteString.hasPrefix(app.server.baseURL.absoluteString) == true,
              let request = message.body as? [String: Any] else { replyHandler(nil, "잘못된 클립보드 요청입니다."); return }
        let pasteboard = NSPasteboard.general
        let types: [String: NSPasteboard.PasteboardType] = ["text/plain": .string, "text/html": .html, "text/rtf": .rtf, "image/png": .png, "image/tiff": .tiff]
        if request["action"] as? String == "read" {
            var values: [String: String] = [:]
            for (mime, type) in types {
                if let data = pasteboard.data(forType: type) { values[mime] = data.base64EncodedString() }
            }
            replyHandler(values, nil)
        } else if request["action"] as? String == "write", let values = request["values"] as? [String: String] {
            let item = NSPasteboardItem()
            for (mime, encoded) in values {
                if let type = types[mime], let bytes = Data(base64Encoded: encoded) { item.setData(bytes, forType: type) }
            }
            pasteboard.clearContents(); pasteboard.writeObjects([item]); replyHandler(true, nil)
        } else { replyHandler(nil, "지원하지 않는 클립보드 요청입니다.") }
    }
    @MainActor func js(_ source: String, _ arguments: [String: Any] = [:]) async throws -> Any {
        (try await webView.callAsyncJavaScript(source, arguments: arguments, in: nil, contentWorld: .page)) ?? NSNull()
    }
    func command(_ id: String) {
        guard ready, !saving else { return }
        Task { @MainActor in
            do { _ = try await js("return await window.superDocs.command(id)", ["id": id]) }
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
            panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "제목 없음.hwpx"
            let popup = NSPopUpButton(frame: NSRect(x: 90, y: 8, width: 180, height: 26))
            popup.addItems(withTitles: ["HWPX 문서 (.hwpx)", "HWP 문서 (.hwp)"])
            popup.selectItem(at: formatName == "hwp" ? 1 : 0)
            popup.target = self; popup.action = #selector(saveFormatChanged(_:))
            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 42))
            let label = NSTextField(labelWithString: "파일 형식:"); label.frame = NSRect(x: 8, y: 12, width: 80, height: 20)
            accessory.addSubview(label); accessory.addSubview(popup); panel.accessoryView = accessory
            panel.allowedContentTypes = [formatName == "hwp" ? hwpType : hwpxType]
            panel.canCreateDirectories = true; panel.isExtensionHidden = false
            activeSavePanel = panel
            let response = await withCheckedContinuation { continuation in panel.beginSheetModal(for: window!) { continuation.resume(returning: $0) } }
            activeSavePanel = nil
            guard response == .OK, let url = panel.url else { return false }
            destination = url
        }
        guard let target = destination else { return false }
        let format = target.pathExtension.lowercased()
        guard ["hwp", "hwpx"].contains(format) else { app.showError(AppError.message("확장자는 .hwp 또는 .hwpx여야 합니다.")); return false }
        status.stringValue = "저장 중…"
        do {
            if target == fileURL, let diskHash {
                let current = try Data(contentsOf: target, options: .mappedIfSafe)
                guard Data(SHA256.hash(data: current)) == diskHash else {
                    throw AppError.message("다른 앱에서 원본을 변경했습니다. ‘다른 이름으로 저장’으로 편집본을 보관해 주세요.")
                }
            }
            let encoded = try await js("document.documentElement.inert = true; return await window.superDocs.export(format)", ["format": format])
            guard let string = encoded as? String, let bytes = Data(base64Encoded: string), !bytes.isEmpty else { throw AppError.message("저장 데이터를 만들지 못했습니다.") }
            try bytes.write(to: target, options: .atomic)
            // Only successful persistence clears native and engine dirty state.
            fileURL = target; diskHash = Data(SHA256.hash(data: bytes))
            _ = try await js("return await window.superDocs.saved(name)", ["name": target.lastPathComponent])
            dirty = false; window?.isDocumentEdited = false; window?.title = target.lastPathComponent; window?.representedURL = target
            status.stringValue = "\(format.uppercased()) · 저장됨"
            NSDocumentController.shared.noteNewRecentDocumentURL(target)
            _ = try? await js("document.documentElement.inert = false; return true")
            return true
        } catch {
            _ = try? await js("document.documentElement.inert = false; return true")
            status.stringValue = "저장하지 못함 · 변경 사항 유지됨"; app.showError(error); return false
        }
    }
    @objc func saveFormatChanged(_ sender: NSPopUpButton) {
        guard let panel = activeSavePanel else { return }
        let ext = sender.indexOfSelectedItem == 0 ? "hwpx" : "hwp"
        panel.allowedContentTypes = [ext == "hwp" ? hwpType : hwpxType]
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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "superDocs")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "superDocsClipboard", contentWorld: .page)
        webView.stopLoading(); app.documents.removeAll { $0 === self }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString.hasPrefix(app.server.baseURL.absoluteString) { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { status.stringValue = "편집기를 불러오지 못했습니다"; app.showError(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { ready = false; status.stringValue = "편집 엔진이 종료되었습니다 · 문서를 다시 열어 주세요" }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.beginSheetModal(for: window!) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "확인"); alert.addButton(withTitle: "취소"); alert.beginSheetModal(for: window!) { completionHandler($0 == .alertFirstButtonReturn) }
    }
}
