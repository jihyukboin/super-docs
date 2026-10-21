import Foundation
import UniformTypeIdentifiers

enum HWPFormat {
    static let hwpx = DocumentFormat(fileExtension: "hwpx", contentType: UTType(importedAs: "tech.superdocs.hwpx", conformingTo: .data), displayName: "HWPX 문서 (.hwpx)")
    static let hwp = DocumentFormat(fileExtension: "hwp", contentType: UTType(importedAs: "tech.superdocs.hwp", conformingTo: .data), displayName: "HWP 문서 (.hwp)")
    static let formats = [hwpx, hwp]

    static func blankDocument() throws -> Data {
        guard let url = Bundle.main.url(forResource: "Blank", withExtension: "hwpx", subdirectory: "HWP") else {
            throw AppError.message("새 문서 서식을 찾을 수 없습니다.")
        }
        return try Data(contentsOf: url)
    }
}
