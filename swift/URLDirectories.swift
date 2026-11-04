// Standard-directory behavior follows swift-foundation f4fa153ff96659cd1678d7cab6cfe1ee799d9ab9,
// Sources/FoundationEssentials/URL/URL.swift (Apache 2.0 with Runtime Library Exception).
// Compiler-owned module migration follows Swift 03411785264fa8951c9c42b3f0c8a724780a7212,
// docs/ReferenceGuides/UnderscoredAttributes.md and AST mangling implementation.
// Import the existing nominal URL type; do not redeclare its representation.
import Foundation

@available(iOS 16.0, *)
@_originallyDefinedIn(module: "Foundation", iOS 16.0)
extension URL {
    public static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

@available(iOS 16.0, *)
@_originallyDefinedIn(module: "Foundation", iOS 16.0)
extension URL {
    /// The path, percent-encoded unless asked otherwise (URL.path decodes it).
    public func path(percentEncoded: Bool = true) -> String {
        guard percentEncoded else { return path }
        return URLComponents(url: self, resolvingAgainstBaseURL: true)?.percentEncodedPath ?? path
    }
}
