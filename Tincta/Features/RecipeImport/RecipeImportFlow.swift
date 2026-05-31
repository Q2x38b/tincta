import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Source for the import flow. Selected before the sheet opens so the user
/// doesn't see an empty UI while we wait for them to pick a source.
public enum RecipeImportSource: String, Identifiable {
    case camera, photos, files
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Scan with Camera"
        case .photos: return "Pick from Photos"
        case .files:  return "Choose Files"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "camera"
        case .photos: return "photo.on.rectangle"
        case .files:  return "folder"
        }
    }
}

/// Coordinator view presented as a sheet when the user picks a scan source
/// from the menu. Owns the import state machine.
struct RecipeImportFlow: View {
    @Environment(\.dismiss) private var dismiss
    let source: RecipeImportSource

    @State private var viewModel = RecipeImportViewModel()
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showReview = false

    var body: some View {
        ZStack {
            Color.tinctaParchment.ignoresSafeArea()
            content
                .padding(24)
        }
        .onAppear(perform: startSource)
        .fullScreenCover(isPresented: $showCamera) {
            // VisionKit's document scanner: edge-detection, perspective fix,
            // multi-page capture, all in one sheet. Returns every captured
            // page when the user taps "Save".
            DocumentScannerView(
                onPicked: { images in
                    showCamera = false
                    viewModel.add(images: images)
                    Task { await runProcess() }
                },
                onCancel: {
                    showCamera = false
                    if viewModel.images.isEmpty { dismiss() }
                }
            )
            .ignoresSafeArea()
        }
        .imageFileImporter(
            isPresented: $showFiles,
            onPicked: { images in
                viewModel.add(images: images)
                showFiles = false
                Task { await runProcess() }
            },
            onCancel: {
                showFiles = false
                if viewModel.images.isEmpty { dismiss() }
            }
        )
        .background(
            PhotosImagePicker(
                selection: $photoSelection,
                onPicked: { images in
                    viewModel.add(images: images)
                    Task { await runProcess() }
                },
                onCancel: {
                    if viewModel.images.isEmpty { dismiss() }
                }
            )
            .hidden()
        )
        .fullScreenCover(isPresented: $showReview, onDismiss: { dismiss() }) {
            RecipeImportReviewView(viewModel: viewModel)
        }
    }

    // MARK: - Content for each stage

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .empty:
            empty
        case .capturing:
            captureSummary
        case .processing(let progress):
            processing(progress)
        case .ready:
            // Auto-segue to review on iOS — keep a quick "open" button as fallback.
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Opening review…")
                    .font(.tinctaBody(14))
                    .foregroundStyle(.secondary)
            }
            .task { showReview = true }
        case .finished:
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Recipes saved!")
                    .font(.tinctaDisplay(22))
            }
            .task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.tinctaBody(15))
                Button("Try again") {
                    viewModel.clear()
                    startSource()
                }
                .padding(.top, 4)
                Button("Cancel", role: .cancel) { dismiss() }
                    .padding(.top, 4)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: source.systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(source.title)
                .font(.tinctaDisplay(24))
            Text("Opening picker…")
                .font(.tinctaBody(13))
                .foregroundStyle(.secondary)
        }
    }

    private var captureSummary: some View {
        VStack(spacing: 16) {
            Text("\(viewModel.images.count) image\(viewModel.images.count == 1 ? "" : "s") captured")
                .font(.tinctaDisplay(20))
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Add another", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button {
                    Task { await runProcess() }
                } label: {
                    Label("Process", systemImage: "wand.and.stars")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(viewModel.images.isEmpty)
            }
            Button("Cancel", role: .cancel) {
                viewModel.clear()
                dismiss()
            }
            .padding(.top, 6)
        }
    }

    private func processing(_ progress: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(progress)
                .font(.tinctaBody(15))
                .multilineTextAlignment(.center)
            Text("All processing happens on this device.")
                .font(.tinctaUILabel(10))
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    // MARK: - Source dispatch

    private func startSource() {
        guard case .empty = viewModel.stage else { return }
        switch source {
        case .camera:
            // VisionKit scanner handles multi-page + crop inline, then hands
            // every captured page back at once. We skip straight from .empty
            // to .processing when it dismisses.
            showCamera = true
        case .photos:
            // Trigger the photos picker by writing to its selection binding.
            // (PhotosPicker's presentation is driven by the picker's own
            // button mechanic; we present it through a hidden anchor.)
            photoSelection = []  // ensures onChange fires on the next selection
            // Defer presentation by a tick so the host has wired up the binding.
            DispatchQueue.main.async { presentPhotosLibrary() }
        case .files:
            showFiles = true
        }
    }

    private func presentPhotosLibrary() {
        // Use the system Photos picker by configuration. We rely on PHPicker
        // through PhotosPicker hidden in the background — selection triggers
        // onPicked. To actually surface it, post an interaction by toggling
        // an internal flag; the PhotosImagePicker is mounted hidden but the
        // PHPicker presentation is driven via its label tap. The simpler
        // approach: present the PHPicker directly.
        showPHPickerViaUIKit()
    }

    /// Bypass the SwiftUI PhotosPicker (which insists on a label) and present
    /// a `PHPickerViewController` directly so we can fire it programmatically
    /// the moment the user lands on this sheet.
    private func showPHPickerViaUIKit() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return
        }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 20
        config.selection = .ordered
        let picker = PHPickerViewController(configuration: config)
        let handler = PHPickerHandler { images in
            if images.isEmpty {
                dismiss()
            } else {
                viewModel.add(images: images)
                Task { await runProcess() }
            }
        }
        picker.delegate = handler
        objc_setAssociatedObject(picker, &PHPickerHandler.key, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        // Walk up to the topmost presented controller before presenting.
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        presenter.present(picker, animated: true)
    }

    @MainActor
    private func runProcess() async {
        await viewModel.process()
    }
}

// MARK: - PHPicker delegate adapter

private final class PHPickerHandler: NSObject, PHPickerViewControllerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    let onPicked: ([UIImage]) -> Void
    init(onPicked: @escaping ([UIImage]) -> Void) {
        self.onPicked = onPicked
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else {
            onPicked([])
            return
        }
        let providers = results.map(\.itemProvider)
        Task { [onPicked] in
            var images: [UIImage] = []
            for provider in providers {
                if provider.canLoadObject(ofClass: UIImage.self) {
                    let image: UIImage? = await withCheckedContinuation { cont in
                        provider.loadObject(ofClass: UIImage.self) { obj, _ in
                            cont.resume(returning: obj as? UIImage)
                        }
                    }
                    if let image { images.append(image) }
                }
            }
            await MainActor.run { onPicked(images) }
        }
    }
}
