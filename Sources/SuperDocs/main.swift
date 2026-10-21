import AppKit
import WebKit
import UniformTypeIdentifiers

let hwpType = UTType(importedAs: "tech.superdocs.hwp", conformingTo: .data)
let hwpxType = UTType(importedAs: "tech.superdocs.hwpx", conformingTo: .data)

final class SuperDocsApp: NSObject, NSApplicationDelegate {
    var server: AssetServer!
    var documents: [EditorWindow] = []
    var terminating = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        do { server = try AssetServer(root: Bundle.main.resourceURL!.appendingPathComponent("Web")) }
        catch { showError(error); NSApp.terminate(nil) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
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
            let blank = try Data(contentsOf: Bundle.main.url(forResource: "Blank", withExtension: "hwpx")!)
            let doc = try EditorWindow(app: self, bytes: blank, url: nil)
            documents.append(doc); doc.showWindow(nil)
        } catch { showError(error) }
    }
    @objc func openPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [hwpType, hwpxType]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach(open) }
    }
    func open(_ url: URL) {
        if let doc = documents.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) { doc.showWindow(nil); return }
        guard ["hwp", "hwpx"].contains(url.pathExtension.lowercased()) else {
            showError(AppError.message("HWP 또는 HWPX 문서를 선택해 주세요.")); return
        }
        do {
            let doc = try EditorWindow(app: self, bytes: Data(contentsOf: url), url: url)
            documents.append(doc); doc.showWindow(nil)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch { showError(error) }
    }
    var current: EditorWindow? {
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
    @objc func about(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Super Docs", .applicationVersion: "0.1.0", .credits: NSAttributedString(string: "HWP · HWPX 문서 편집기\nRHWP 0.8.7 (MIT)\n본 제품은 한글 문서 파일 공개 문서를 참고한 독립적인 앱입니다.")])
    }
    @objc func licenses(_ sender: Any?) {
        if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
    func showError(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "작업을 완료하지 못했습니다"; alert.informativeText = (error as NSError).userInfo["WKJavaScriptExceptionMessage"] as? String ?? error.localizedDescription; alert.runModal()
    }
    private func buildMenu() {
        let menu = NSMenu(); NSApp.mainMenu = menu
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(); let sub = NSMenu(title: title); item.submenu = sub; menu.addItem(item); return sub
        }
        func item(_ m: NSMenu, _ title: String, _ selector: Selector, _ key: String = "", shift: Bool = false) {
            let i = NSMenuItem(title: title, action: selector, keyEquivalent: key); i.target = self
            i.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]; m.addItem(i)
        }
        let app = submenu("Super Docs")
        item(app, "Super Docs 정보", #selector(about)); item(app, "오픈소스 라이선스", #selector(licenses))
        app.addItem(.separator()); app.addItem(withTitle: "Super Docs 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator()); app.addItem(withTitle: "Super Docs 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let file = submenu("파일")
        item(file, "새 문서", #selector(newDocument), "n"); item(file, "열기…", #selector(openPanel), "o")
        file.addItem(.separator()); item(file, "저장", #selector(saveDocument), "s"); item(file, "다른 이름으로 저장…", #selector(saveAsDocument), "s", shift: true)
        file.addItem(.separator()); file.addItem(withTitle: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = submenu("편집")
        for (title, id, key, shift) in [("실행 취소", "edit:undo", "z", false), ("다시 실행", "edit:redo", "z", true), ("오려두기", "edit:cut", "x", false), ("복사", "edit:copy", "c", false), ("붙여넣기", "edit:paste", "v", false), ("모두 선택", "edit:select-all", "a", false), ("찾기…", "edit:find", "f", false)] {
            let nativeActions = ["edit:cut": "cut:", "edit:copy": "copy:", "edit:paste": "paste:"]
            let i = NSMenuItem(title: title, action: nativeActions[id].map { Selector($0) } ?? #selector(runEditorCommand), keyEquivalent: key); i.target = nativeActions[id] == nil ? self : nil; i.representedObject = id; i.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]; edit.addItem(i)
        }
        let window = submenu("윈도우"); NSApp.windowsMenu = window
        window.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "확대/축소", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

let application = NSApplication.shared
let delegate = SuperDocsApp()
application.delegate = delegate
application.run()
