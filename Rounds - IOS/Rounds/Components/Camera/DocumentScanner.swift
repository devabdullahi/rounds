import SwiftUI
import VisionKit

/// Apple's document scanner: finds the page edges, straightens and sharpens each page, and can
/// take several pages in one go, so handwriting and print read better than in a plain photo.
/// Hands back each page as a JPEG; the caller reads the text.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([Data]) -> Void
    let onCancel: () -> Void

    /// False on devices without a camera (and in the simulator).
    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onCancel: onCancel) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([Data]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([Data]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 0.8) }
            onScan(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onCancel() }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onCancel() }
    }
}
