import AppKit
import UniformTypeIdentifiers

struct CSVFile {
    var rows: [[String]]
    let newline: String
    let endsWithNewline: Bool

    init(_ text: String) throws {
        newline = text.contains("\r\n") ? "\r\n" : "\n"
        endsWithNewline = text.hasSuffix("\n") || text.hasSuffix("\r")
        rows = []
        var row: [String] = [], field = ""
        var quoted = false, closedQuote = false
        let characters = Array(text)
        var i = 0
        while i < characters.count {
            let c = characters[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < characters.count && characters[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closedQuote = true }
                } else { field.append(c) }
            } else if c == "," { row.append(field); field = ""; closedQuote = false }
            else if c == "\n" || c == "\r" || c == "\r\n" {
                row.append(field); rows.append(row); row = []; field = ""; closedQuote = false
            } else if c == "\"" && field.isEmpty && !closedQuote { quoted = true }
            else {
                guard !closedQuote, c != "\"" else { throw AppError.message("CSV 따옴표 형식이 올바르지 않습니다.") }
                field.append(c)
            }
            i += 1
        }
        guard !quoted else { throw AppError.message("CSV의 따옴표가 닫히지 않았습니다.") }
        if !field.isEmpty || !row.isEmpty || closedQuote { row.append(field); rows.append(row) }
    }
    func text() -> String {
        let body = rows.map { row in row.map { cell in
            if cell.contains(where: { ",\"\r\n".contains($0) }) { return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            return cell
        }.joined(separator: ",") }.joined(separator: newline)
        return body + (endsWithNewline && !rows.isEmpty ? newline : "")
    }
}

final class CSVEditor: NSObject, DocumentEditor, NSTableViewDataSource, NSTableViewDelegate {
    static let format = DocumentFormat(fileExtension: "csv", contentType: .commaSeparatedText, displayName: "CSV (.csv)")
    let defaultFormat = CSVEditor.format
    let saveFormats = [CSVEditor.format]
    let view = NSView()
    let table = NSTableView()
    private var file = try! CSVFile("")
    private var source = try! TextFile(Data())
    private let history = UndoManager()
    private let search = NSSearchField()
    private var lastMatch = -1
    var onReady: (() -> Void)?
    var onChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onTermination: (() -> Void)?

    override init() {
        super.init()
        table.dataSource = self; table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.rowHeight = 26
        table.setAccessibilityLabel("CSV 표")
        let scroll = NSScrollView(); scroll.documentView = table
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let addRow = NSButton(title: "행 추가", target: self, action: #selector(appendRow))
        let deleteRow = NSButton(title: "선택한 행 삭제", target: self, action: #selector(deleteRows))
        let addColumn = NSButton(title: "열 추가", target: self, action: #selector(appendColumn))
        search.placeholderString = "CSV에서 찾기"; search.setAccessibilityLabel("CSV에서 찾기")
        search.target = self; search.action = #selector(findNext)
        search.sendsWholeSearchString = true
        search.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let toolbar = NSStackView(views: [addRow, deleteRow, addColumn, search])
        toolbar.spacing = 8; toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        for child in [toolbar, scroll] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([toolbar.topAnchor.constraint(equalTo: view.topAnchor), toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor), toolbar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor), scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        NotificationCenter.default.addObserver(self, selector: #selector(fieldChanged(_:)), name: NSControl.textDidChangeNotification, object: table)
    }
    func start() { onReady?() }
    @MainActor func load(_ bytes: Data, name: String) async throws -> String {
        source = try TextFile(bytes); file = try CSVFile(source.text)
        history.removeAllActions(); reload()
        return "\(file.rows.count)행"
    }
    private func reload() {
        let count = max(1, file.rows.map(\.count).max() ?? 0)
        while table.tableColumns.count > count { table.removeTableColumn(table.tableColumns.last!) }
        while table.tableColumns.count < count {
            let index = table.tableColumns.count
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
            column.title = "\(index + 1)"; column.width = 180; column.isEditable = true
            table.addTableColumn(column)
        }
        table.reloadData()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { file.rows.count }
    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        guard let index = column.flatMap({ Int($0.identifier.rawValue) }) else { return nil }
        return index < file.rows[row].count ? file.rows[row][index] : ""
    }
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for column: NSTableColumn?, row: Int) {
        guard let index = column.flatMap({ Int($0.identifier.rawValue) }) else { return }
        var rows = file.rows
        while rows[row].count <= index { rows[row].append("") }
        rows[row][index] = object as? String ?? ""
        replace(rows)
    }
    @objc private func fieldChanged(_ notification: Notification) { onChange?() }
    private func replace(_ rows: [[String]]) {
        guard rows != file.rows else { return }
        let old = file.rows
        history.registerUndo(withTarget: self) { $0.replace(old) }
        file.rows = rows; reload(); onChange?()
    }
    @objc private func appendRow() {
        view.window?.makeFirstResponder(table)
        replace(file.rows + [Array(repeating: "", count: max(1, table.numberOfColumns))])
    }
    @objc private func appendColumn() {
        view.window?.makeFirstResponder(table)
        let width = table.numberOfColumns + 1
        let rows = file.rows.isEmpty ? [[]] : file.rows
        replace(rows.map { $0 + Array(repeating: "", count: width - $0.count) })
    }
    @objc private func deleteRows() {
        view.window?.makeFirstResponder(table)
        let selected = table.selectedRowIndexes
        replace(file.rows.enumerated().filter { !selected.contains($0.offset) }.map(\.element))
    }
    @MainActor func export(format: String) async throws -> Data {
        guard format == "csv" else { throw AppError.message("CSV 형식으로 저장해 주세요.") }
        view.window?.makeFirstResponder(table)
        source.text = file.text()
        return try source.data()
    }
    func didSave(name: String) async throws {}
    @MainActor func command(_ id: String) async throws {
        view.window?.makeFirstResponder(table)
        if id == "edit:find" { view.window?.makeFirstResponder(search); return }
        if id == "edit:undo" { history.undo() }
        if id == "edit:redo" { history.redo() }
        if id == "edit:select-all" { table.selectAll(nil) }
    }
    @objc private func findNext() {
        guard !search.stringValue.isEmpty, !file.rows.isEmpty else { return }
        let cells = file.rows.enumerated().flatMap { row, values in values.enumerated().map { (row, $0.offset, $0.element) } }
        guard !cells.isEmpty else { return }
        for offset in 1...cells.count {
            let index = (lastMatch + offset) % cells.count
            let (row, column, text) = cells[index]
            if text.localizedCaseInsensitiveContains(search.stringValue) {
                lastMatch = index
                table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                table.scrollRowToVisible(row); table.scrollColumnToVisible(column)
                return
            }
        }
        NSSound.beep()
    }
    func setStatus(_ text: String) {}
    @MainActor func setInteractionEnabled(_ enabled: Bool) async throws {
        view.window?.makeFirstResponder(table)
        table.isEnabled = enabled
    }
    func close() { NotificationCenter.default.removeObserver(self) }
}
