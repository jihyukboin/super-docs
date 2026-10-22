import Foundation

let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let original = Data("original".utf8)
let edited = Data("edited".utf8)
let target = root.appendingPathComponent("document.hwpx")
try original.write(to: target)
let session = DocumentSession(bytes: original, url: target)
session.didLoad()
precondition(session.initialBytes.isEmpty)
session.markChanged()
try session.checkForExternalChanges(at: target)
try session.write(edited, to: target)
// Persistence alone must not clear changes before the editor acknowledges the save.
precondition(session.dirty)
session.markSaved()
precondition(!session.dirty)
let saved = try Data(contentsOf: target)
precondition(saved == edited)
try session.checkForExternalChanges(at: target)

session.markChanged()
try original.write(to: target)
do {
    try session.checkForExternalChanges(at: target)
    fatalError("External changes must block overwriting the original")
} catch { precondition(session.dirty) }
let copy = root.appendingPathComponent("copy.hwpx")
try session.checkForExternalChanges(at: copy)
try session.write(edited, to: copy)
precondition(session.fileURL == copy)
let preserved = try Data(contentsOf: target)
precondition(preserved == original)

for (bytes, destination) in [(edited, root.appendingPathComponent("missing/fail.hwpx"))] {
    do {
        try session.write(bytes, to: destination)
        fatalError("Invalid writes must fail")
    } catch {
        precondition(session.dirty && session.fileURL == copy)
    }
}
let untitled = DocumentSession(bytes: original, url: nil)
precondition(untitled.fileURL == nil && !untitled.dirty)
try untitled.write(edited, to: root.appendingPathComponent("new.hwpx"))
precondition(untitled.fileURL != nil)
print("PASS: document persistence, external-change protection, Save As and failed-save state")

let empty = root.appendingPathComponent("empty.txt")
try session.write(Data(), to: empty)
let emptyBytes = try Data(contentsOf: empty)
precondition(emptyBytes.isEmpty)
