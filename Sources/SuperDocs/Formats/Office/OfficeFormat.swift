import UniformTypeIdentifiers

enum OfficeFormat {
    static let xlsx = DocumentFormat(fileExtension: "xlsx", contentType: UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet"), displayName: "Excel 통합 문서 (.xlsx)")
    static let pptx = DocumentFormat(fileExtension: "pptx", contentType: UTType(importedAs: "org.openxmlformats.presentationml.presentation"), displayName: "PowerPoint 프레젠테이션 (.pptx)")
    static let formats = [xlsx, pptx]
}
