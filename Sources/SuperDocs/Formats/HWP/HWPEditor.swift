import AppKit
import WebKit

final class HWPEditor: NSObject, DocumentEditor, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private let baseURL: URL
    private let webView: WKWebView
    private let clipboard: WebClipboardBridge
    var view: NSView { webView }
    var saveFormats: [DocumentFormat] { HWPFormat.formats }
    var defaultFormat: DocumentFormat { HWPFormat.hwpx }
    var onReady: (() -> Void)?
    var onChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onTermination: (() -> Void)?

    init(baseURL: URL) throws {
        self.baseURL = baseURL
        clipboard = WebClipboardBridge(baseURL: baseURL)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = ProcessInfo.processInfo.environment["SUPERDOCS_INSPECT"] == "1"
        super.init()
        let appearance = NSAppearance(named: .darkAqua)!
        var colors: [String: String] = [:]
        appearance.performAsCurrentDrawingAppearance {
            let palette: [(NSColor, [String])] = [
                (.windowBackgroundColor, ["ui-bg", "ui-bg-light", "ui-surface", "ui-toolbar-bg-start", "ui-toolbar-bg-end", "ruler-bg"]),
                (.controlColor, ["ui-surface-raised", "ruler-body"]),
                (.controlBackgroundColor, ["ui-surface-muted", "ui-note-bg", "doc-workspace"]),
                (.labelColor, ["ui-text"]),
                (.secondaryLabelColor, ["ui-text-secondary", "ui-text-muted", "ui-note-text", "ruler-tick", "ruler-text", "table-selection-marker-single", "accent-subtle"]),
                (.tertiaryLabelColor, ["ui-text-hint", "ui-text-placeholder", "ui-border-strong"]),
                (.disabledControlTextColor, ["ui-text-disabled"]),
                (.separatorColor, ["ui-border", "ui-border-light", "ui-border-subtle", "ui-note-border", "accent-hover"]),
                (.controlAccentColor, ["accent-primary", "accent-strong", "accent-light", "focus-ring", "resize-handle", "ruler-marker", "table-selection-stroke"]),
                (.selectedContentBackgroundColor, ["ui-selected"]),
                (.selectedTextColor, ["ui-text-on-accent"]),
                (.unemphasizedSelectedContentBackgroundColor, ["ui-active"]),
                (.linkColor, ["ui-link"]),
                (.systemRed, ["ui-danger", "ui-danger-strong"]),
                (.systemYellow, ["ui-warning-border", "ui-warning-text"]),
            ]
            for (color, tokens) in palette {
                guard let rgb = color.usingColorSpace(.sRGB) else { continue }
                let value = "rgba(\(rgb.redComponent * 255), \(rgb.greenComponent * 255), \(rgb.blueComponent * 255), \(rgb.alphaComponent))"
                for token in tokens { colors["--" + token] = value }
            }
        }
        let paletteJSON = String(data: try JSONSerialization.data(withJSONObject: colors), encoding: .utf8)!
        config.userContentController.addUserScript(WKUserScript(source: "Object.entries(\(paletteJSON)).forEach(([name, value]) => document.documentElement.style.setProperty(name, value));", injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        config.userContentController.add(self, name: "superDocs")
        config.userContentController.addScriptMessageHandler(clipboard, contentWorld: .page, name: "superDocsClipboard")
    }

    func start() {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "chrome", value: "embed"), URLQueryItem(name: "lang", value: "ko"), URLQueryItem(name: "renderer", value: "canvas2d")]
        webView.load(URLRequest(url: parts.url!))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.absoluteString.hasPrefix(baseURL.absoluteString) == true,
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready": onReady?()
        case "open": onOpen?()
        case "save": onSave?()
        case "changed": onChange?()
        case "error": onError?(AppError.message(body["message"] as? String ?? "편집기를 시작하지 못했습니다."))
        default: break
        }
    }

    @MainActor private func js(_ source: String, _ arguments: [String: Any] = [:]) async throws -> Any {
        (try await webView.callAsyncJavaScript(source, arguments: arguments, in: nil, contentWorld: .page)) ?? NSNull()
    }

    @MainActor func load(_ bytes: Data, name: String) async throws -> String {
        let result = try await js("return await window.superDocs.load(bytes, name)", ["bytes": bytes.base64EncodedString(), "name": name])
        let pages = (result as? [String: Any])?["pages"] as? Int ?? 1
        return "\(pages)쪽"
    }

    @MainActor func export(format: String) async throws -> Data {
        let encoded = try await js("return await window.superDocs.export(format)", ["format": format])
        guard let string = encoded as? String, let bytes = Data(base64Encoded: string), !bytes.isEmpty else {
            throw AppError.message("저장 데이터를 만들지 못했습니다.")
        }
        return bytes
    }

    @MainActor func didSave(name: String) async throws {
        _ = try await js("return await window.superDocs.saved(name)", ["name": name])
    }

    @MainActor func command(_ id: String) async throws {
        _ = try await js("return await window.superDocs.command(id)", ["id": id])
    }

    func setStatus(_ text: String) {
        webView.callAsyncJavaScript("document.getElementById('super-docs-status').textContent = text", arguments: ["text": text], in: nil, in: .page, completionHandler: nil)
    }

    @MainActor func setInteractionEnabled(_ enabled: Bool) async throws {
        _ = try await js("document.documentElement.inert = !enabled; return true", ["enabled": enabled])
    }

    func close() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "superDocs")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "superDocsClipboard", contentWorld: .page)
        webView.stopLoading()
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString.hasPrefix(baseURL.absoluteString) { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { setStatus("편집기를 불러오지 못했습니다"); onError?(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { onTermination?() }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.beginSheetModal(for: webView.window!) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "확인"); alert.addButton(withTitle: "취소"); alert.beginSheetModal(for: webView.window!) { completionHandler($0 == .alertFirstButtonReturn) }
    }
}
