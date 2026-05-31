import SwiftUI
import VisionKit
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen document scanner powered by `VNDocumentCameraViewController`.
///
/// Why this instead of `UIImagePickerController`:
/// - Live edge detection — the user just points and the scanner snaps when a
///   page is in frame.
/// - The user adjusts the four crop corners after capture; no settling for a
///   fixed square crop.
/// - Perspective is corrected automatically, so a phone-held shot of a tilted
///   recipe book becomes a flat rectangle ready for OCR.
/// - Native multi-page scanning — the user can capture many recipe pages back
///   to back and we get all of them at once when they tap Save.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onPicked: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onPicked: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping ([UIImage]) -> Void,
             onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for i in 0 ..< scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) { [onPicked] in
                onPicked(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [onCancel] in
                onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) { [onCancel] in
                onCancel()
            }
        }
    }
}

/// Availability check — VisionKit's document scanner needs a real camera.
extension DocumentScannerView {
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
