import AppKit
import WebKit

final class WebClipboardBridge: NSObject, WKScriptMessageHandlerWithReply {
    private let baseURL: URL

    init(baseURL: URL) { self.baseURL = baseURL }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.absoluteString.hasPrefix(baseURL.absoluteString) == true,
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
}
