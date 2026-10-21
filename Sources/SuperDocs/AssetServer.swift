import Foundation
import Network

/// Serves only bundled assets on an ephemeral IPv4 loopback port.
final class AssetServer {
    private let root: URL
    private let listener: NWListener
    private let queue = DispatchQueue(label: "tech.superdocs.assets")
    private let token = UUID().uuidString
    private(set) var baseURL: URL!

    init(root: URL) throws {
        self.root = root.resolvingSymlinksInPath()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        let ready = DispatchSemaphore(value: 0)
        var startupError: Error?
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let self, let port = self.listener.port {
                    self.baseURL = URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/")!
                }
                ready.signal()
            case .failed(let error): startupError = error; ready.signal()
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receive(connection, buffer: Data())
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, baseURL != nil else {
            listener.cancel()
            throw startupError ?? NSError(domain: "SuperDocs", code: 1, userInfo: [NSLocalizedDescriptionKey: "로컬 편집기를 시작하지 못했습니다."])
        }
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { [weak self] bytes, _, complete, error in
            guard let self else { connection.cancel(); return }
            var data = buffer
            if let bytes { data.append(bytes) }
            if data.count > 32768 { self.respond(connection, status: "431 Request Header Fields Too Large"); return }
            if let request = String(data: data, encoding: .utf8), request.contains("\r\n\r\n") {
                self.serve(request, connection)
            } else if complete || error != nil { connection.cancel() }
            else { self.receive(connection, buffer: data) }
        }
    }

    private func serve(_ request: String, _ connection: NWConnection) {
        let parts = request.components(separatedBy: "\r\n")[0].split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "HEAD",
              let components = URLComponents(string: String(parts[1])) else {
            respond(connection, status: "400 Bad Request"); return
        }
        let path = components.path
        let prefix = "/\(token)/"
        guard path.hasPrefix(prefix) else { respond(connection, status: "404 Not Found"); return }
        let relative = String(path.dropFirst(prefix.count))
        let file = root.appendingPathComponent(relative.isEmpty ? "index.html" : relative).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(root.path + "/"),
              let content = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            respond(connection, status: "404 Not Found"); return
        }
        let mime = ["html": "text/html; charset=utf-8", "js": "text/javascript", "mjs": "text/javascript", "css": "text/css", "wasm": "application/wasm", "json": "application/json", "woff2": "font/woff2", "woff": "font/woff", "ttf": "font/ttf", "otf": "font/otf", "svg": "image/svg+xml", "png": "image/png", "ico": "image/x-icon"]
        respond(connection, status: "200 OK", mime: mime[file.pathExtension] ?? "application/octet-stream", body: content, head: parts[0] == "HEAD")
    }

    private func respond(_ connection: NWConnection, status: String, mime: String = "text/plain", body: Data = Data(), head: Bool = false) {
        let csp = "default-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; connect-src 'self'; font-src 'self' data:; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; worker-src 'self' blob:; object-src 'none'; base-uri 'self'"
        var response = Data("HTTP/1.1 \(status)\r\nContent-Type: \(mime)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: \(csp)\r\n\r\n".utf8)
        if !head { response.append(body) }
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
    deinit { listener.cancel() }
}
