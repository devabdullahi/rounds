import PDFKit
import UIKit
import Vision

/// Reads text out of a student's notes on the device: the PDF's own text, or on-device text
/// recognition for photos and scanned pages. Nothing is uploaded here; only the text is sent on.
enum NotesReader {
    /// Enough for a lecture or a chapter; more would be cut by `StudyNotes.maxLength` anyway.
    static let maxPages = 40
    static let maxPhotos = 10

    /// Pages with a text layer are read directly; scanned pages (no text) are recognized as images.
    /// The text and how many pages were read.
    static func text(fromPDF url: URL) async -> (text: String, pages: Int) {
        await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let document = PDFDocument(url: url) else { return ("", 0) }
            var pages: [String] = []
            for index in 0..<min(document.pageCount, maxPages) {
                guard !Task.isCancelled, let page = document.page(at: index) else { break }
                let own = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if own.count > 20 {
                    pages.append(own)
                } else if let image = render(page).cgImage {
                    pages.append(recognize(image))
                }
            }
            return (pages.joined(separator: "\n"), pages.count)
        }.value
    }

    /// Photos in the order picked, each recognized on the device.
    static func text(fromPhotos photos: [Data]) async -> String {
        await Task.detached(priority: .userInitiated) {
            photos.prefix(maxPhotos).compactMap { data -> String? in
                guard !Task.isCancelled, let image = UIImage(data: data)?.cgImage else { return nil }
                return recognize(image)
            }.joined(separator: "\n")
        }.value
    }

    /// A scanned page drawn at about 2× so small handwriting and print stay legible to recognition.
    private static func render(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(2, 2000 / max(bounds.width, bounds.height, 1))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private static func recognize(_ image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
