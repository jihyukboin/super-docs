import Foundation
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
try Data("bundled asset".utf8).write(to: root.appendingPathComponent("index.html"))
try Data([0, 97, 115, 109]).write(to: root.appendingPathComponent("engine.wasm"))
let server = try AssetServer(root: root)
func request(_ url: URL, method: String = "GET") -> (HTTPURLResponse, Data) {
    var request = URLRequest(url: url); request.httpMethod = method
    let done = DispatchSemaphore(value: 0)
    var result: (HTTPURLResponse, Data)?
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let response = response as? HTTPURLResponse, let data { result = (response, data) }
        done.signal()
    }.resume()
    precondition(done.wait(timeout: .now() + 5) == .success)
    return result!
}
let (html, bytes) = request(server.baseURL)
precondition(html.statusCode == 200 && bytes == Data("bundled asset".utf8))
precondition(html.value(forHTTPHeaderField: "Content-Security-Policy")!.contains("connect-src 'self'"))
let (wasm, _) = request(server.baseURL.appendingPathComponent("engine.wasm"))
precondition(wasm.value(forHTTPHeaderField: "Content-Type") == "application/wasm")
let (head, empty) = request(server.baseURL, method: "HEAD")
precondition(head.statusCode == 200 && empty.isEmpty)
var missingToken = URLComponents(url: server.baseURL, resolvingAgainstBaseURL: false)!
missingToken.path = "/index.html"
precondition(request(missingToken.url!).0.statusCode == 404)
precondition(request(URL(string: server.baseURL.absoluteString + "%2e%2e/outside")!).0.statusCode == 404)
precondition(request(server.baseURL, method: "POST").0.statusCode == 400)
print("PASS: loopback assets, WASM MIME, HEAD, token, path traversal and CSP")
