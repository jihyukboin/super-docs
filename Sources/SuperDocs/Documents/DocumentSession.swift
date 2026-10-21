import Foundation
import CryptoKit

final class DocumentSession {
    private(set) var fileURL: URL?
    private(set) var dirty = false
    private(set) var initialBytes: Data
    private var diskHash: Data?

    init(bytes: Data, url: URL?) {
        initialBytes = bytes
        fileURL = url
        if url != nil { diskHash = Data(SHA256.hash(data: bytes)) }
    }

    func didLoad() { initialBytes = Data() }
    func markChanged() { dirty = true }
    func markSaved() { dirty = false }

    func checkForExternalChanges(at target: URL) throws {
        if target == fileURL, let diskHash {
            let current = try Data(contentsOf: target, options: .mappedIfSafe)
            guard Data(SHA256.hash(data: current)) == diskHash else {
                throw AppError.message("다른 앱에서 원본을 변경했습니다. ‘다른 이름으로 저장’으로 편집본을 보관해 주세요.")
            }
        }
    }

    func write(_ bytes: Data, to target: URL) throws {
        guard !bytes.isEmpty else { throw AppError.message("저장 데이터를 만들지 못했습니다.") }
        try bytes.write(to: target, options: .atomic)
        fileURL = target
        diskHash = Data(SHA256.hash(data: bytes))
    }
}
