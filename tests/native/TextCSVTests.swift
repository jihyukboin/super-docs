import AppKit

@main struct TextCSVTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        for bytes in [Data("한글\r\nEnglish\n".utf8), Data([0xef, 0xbb, 0xbf]) + Data("한글".utf8), Data([0xff, 0xfe]) + "한글\r\n".data(using: .utf16LittleEndian)!, Data()] {
            let file = try TextFile(bytes)
            let encoded = try file.data()
            precondition(encoded == bytes)
        }
        do { _ = try TextFile(Data([0xff])); fatalError("Invalid UTF-8 accepted") } catch {}
        let csv = "이름,내용,빈 값\r\n사과,\"쉼표,와 \"\"따옴표\"\"\",\r\n배,\"여러\r\n줄\",끝\r\n"
        let parsed = try CSVFile(csv)
        precondition(parsed.rows.count == 3)
        precondition(parsed.rows[1][1] == "쉼표,와 \"따옴표\"")
        precondition(parsed.rows[1][2] == "")
        precondition(parsed.rows[2][1] == "여러\r\n줄")
        let reopened = try CSVFile(parsed.text())
        precondition(reopened.rows == parsed.rows)
        for invalid in ["\"unterminated", "abc\"def", "\"quoted\"x"] {
            do { _ = try CSVFile(invalid); fatalError("Malformed CSV accepted") } catch {}
        }
        let editor = TextEditor(format: TextEditor.markdown)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor.view
        _ = try await editor.load(Data("# 제목\n\n**굵게**\n".utf8), name: "sample.md")
        editor.textView.insertText("수정 ", replacementRange: NSRange(location: 2, length: 0))
        let edited = try await editor.export(format: "md")
        precondition(String(data: edited, encoding: .utf8)!.contains("수정"))
        try await editor.command("edit:undo")
        let undone = try await editor.export(format: "md")
        precondition(!String(data: undone, encoding: .utf8)!.contains("수정"))
        editor.textView.string = ""
        let empty = try await editor.export(format: "txt")
        precondition(empty.isEmpty)
        let table = CSVEditor()
        _ = try await table.load(Data(csv.utf8), name: "sample.csv")
        table.tableView(table.table, setObjectValue: "변경,값", for: table.table.tableColumns[1], row: 1)
        let saved = try await table.export(format: "csv")
        let savedRows = try CSVFile(String(data: saved, encoding: .utf8)!).rows
        precondition(savedRows[1][1] == "변경,값")
        try await table.command("edit:undo")
        let reverted = try await table.export(format: "csv")
        let revertedRows = try CSVFile(String(data: reverted, encoding: .utf8)!).rows
        precondition(revertedRows == parsed.rows)
        print("PASS: text encoding/BOM, Markdown edit/undo, empty text, CSV quoting/multiline, table edit/save/undo")
    }
}
