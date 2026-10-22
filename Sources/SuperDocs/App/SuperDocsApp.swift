import AppKit
import Sparkle

final class SuperDocsApp: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var server: AssetServer!
    var documents: [DocumentWindowController] = []
    var terminating = false
    let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        do { server = try AssetServer(root: Bundle.main.resourceURL!.appendingPathComponent("Web")) }
        catch { showError(error); NSApp.terminate(nil) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController.startUpdater()
        if documents.isEmpty { newDocument(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { newDocument(nil) }; return true
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for path in filenames { open(URL(fileURLWithPath: path)) }
        sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        Task { @MainActor in
            for doc in documents where doc.dirty {
                if !(await doc.confirmDiscard()) { NSApp.reply(toApplicationShouldTerminate: false); return }
            }
            terminating = true
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    @objc func newDocument(_ sender: Any?) {
        do {
            let doc = try DocumentOpener.newDocument(app: self)
            documents.append(doc); doc.showWindow(nil)
        } catch { showError(error) }
    }
    @objc func openPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = DocumentOpener.contentTypes
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach(open) }
    }
    func open(_ url: URL) {
        if let doc = documents.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) { doc.showWindow(nil); return }
        do {
            let doc = try DocumentOpener.open(url, app: self)
            documents.append(doc); doc.showWindow(nil)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch { showError(error) }
    }
    var current: DocumentWindowController? {
        let active = NSApp.keyWindow?.sheetParent ?? NSApp.keyWindow ?? NSApp.mainWindow
        return documents.first { $0.window === active } ?? documents.last
    }
    @objc func saveDocument(_ sender: Any?) { Task { @MainActor in _ = await current?.save() } }
    @objc func saveAsDocument(_ sender: Any?) { Task { @MainActor in _ = await current?.save(asNew: true) } }
    @objc func runEditorCommand(_ sender: NSMenuItem) {
        let id = sender.representedObject as! String
        if NSApp.keyWindow?.firstResponder is NSTextView {
            let selectors = ["edit:undo": "undo:", "edit:redo": "redo:", "edit:select-all": "selectAll:"]
            if let selector = selectors[id] { NSApp.sendAction(Selector(selector), to: nil, from: sender); return }
        }
        current?.command(id)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(saveDocument) || menuItem.action == #selector(saveAsDocument) {
            return current?.canSave == true
        }
        if menuItem.action == #selector(runEditorCommand) {
            guard let current else { return false }
            if current.isReadOnly, let id = menuItem.representedObject as? String {
                return ["edit:find", "edit:select-all", "edit:copy"].contains(id)
            }
        }
        return true
    }
    @objc func about(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Super Docs", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", .credits: NSAttributedString(string: "HWP · HWPX · DOCX 문서 편집기 · PDF 뷰어\nRHWP 0.8.7 (MIT) · DOCX Editor 2.32.0 (Apache-2.0)\n본 제품은 한글 문서 파일 공개 문서를 참고한 독립적인 앱입니다.")])
    }
    @objc func licenses(_ sender: Any?) {
        if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
    func showError(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "작업을 완료하지 못했습니다"; alert.informativeText = (error as NSError).userInfo["WKJavaScriptExceptionMessage"] as? String ?? error.localizedDescription; alert.runModal()
    }
}
