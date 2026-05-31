import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Camera

/// `UIImagePickerController` wrapped for SwiftUI sheet presentation. The
/// system camera UI only returns a single image per dismissal, so the host
/// presents this repeatedly if the user picked "multiple shots".
struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - Photos

/// Multi-select Photos picker. Loads the selected items into UIImages on the
/// MainActor and hands them back to the host.
struct PhotosImagePicker: View {
    @Binding var selection: [PhotosPickerItem]
    let onPicked: ([UIImage]) -> Void
    let onCancel: () -> Void

    var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: 20,
            matching: .images,
            photoLibrary: .shared()
        ) {
            EmptyView()
        }
        .photosPickerStyle(.presentation)
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if images.isEmpty {
                    onCancel()
                } else {
                    onPicked(images)
                }
                selection = []
            }
        }
    }
}

// MARK: - Files

/// Wraps `.fileImporter` to surface picked image files as UIImages.
struct ImageFileImporter: ViewModifier {
    @Binding var isPresented: Bool
    let onPicked: ([UIImage]) -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.image, .png, .jpeg, .heic, .pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .failure:
                onCancel()
            case .success(let urls):
                var images: [UIImage] = []
                for url in urls {
                    let needsScope = url.startAccessingSecurityScopedResource()
                    defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if images.isEmpty {
                    onCancel()
                } else {
                    onPicked(images)
                }
            }
        }
    }
}

extension View {
    func imageFileImporter(
        isPresented: Binding<Bool>,
        onPicked: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(ImageFileImporter(isPresented: isPresented, onPicked: onPicked, onCancel: onCancel))
    }
}
