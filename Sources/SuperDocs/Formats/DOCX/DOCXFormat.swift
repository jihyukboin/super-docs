import UniformTypeIdentifiers

enum DOCXFormat {
    static let docx = DocumentFormat(fileExtension: "docx", contentType: UTType(importedAs: "org.openxmlformats.wordprocessingml.document"), displayName: "Word 문서 (.docx)")
}
