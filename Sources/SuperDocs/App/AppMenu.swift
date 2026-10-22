import AppKit
import Sparkle

extension SuperDocsApp {
    func buildMenu() {
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
        let checkForUpdates = NSMenuItem(title: "업데이트 확인…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        checkForUpdates.target = updaterController
        app.addItem(checkForUpdates)
        app.addItem(.separator()); app.addItem(withTitle: "Super Docs 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator()); app.addItem(withTitle: "Super Docs 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let file = submenu("파일")
        let newItem = NSMenuItem(title: "새 문서", action: nil, keyEquivalent: "")
        let newMenu = NSMenu(title: "새 문서"); newItem.submenu = newMenu; file.addItem(newItem)
        for format in DocumentOpener.formats where !["hwp", "markdown"].contains(format.fileExtension) {
            let entry = NSMenuItem(title: format.displayName, action: #selector(newDocument), keyEquivalent: format.fileExtension == "hwpx" ? "n" : "")
            entry.target = self; entry.representedObject = format.fileExtension; newMenu.addItem(entry)
        }
        item(file, "열기…", #selector(openPanel), "o")
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
