import AppKit

// Only the operations used by the document window belong to this boundary.
protocol DocumentEditor: AnyObject {
    var view: NSView { get }
    var saveFormats: [DocumentFormat] { get }
    var defaultFormat: DocumentFormat { get }
    var onReady: (() -> Void)? { get set }
    var onChange: (() -> Void)? { get set }
    var onOpen: (() -> Void)? { get set }
    var onSave: (() -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    var onTermination: (() -> Void)? { get set }
    func start()
    func load(_ bytes: Data, name: String) async throws -> String
    func export(format: String) async throws -> Data
    func didSave(name: String) async throws
    func command(_ id: String) async throws
    func setStatus(_ text: String)
    func setInteractionEnabled(_ enabled: Bool) async throws
    func close()
}
