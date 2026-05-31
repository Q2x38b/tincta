import Foundation
import Vision
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// On-device text extraction using the Vision framework's accurate OCR.
/// All work happens locally — no network, no third-party services.
enum OCRService {

    /// Recognize text from a UIImage. Returns one string per image with
    /// lines joined by newlines, preserving the on-page reading order. If
    /// no text is found the string is empty.
    static func recognize(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        return try await recognize(in: cgImage)
    }

    static func recognize(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Vision returns observations in roughly reading order; join their
                // top candidate strings with newlines so the LLM downstream sees
                // a faithful transcription.
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Convenience: recognise across many images in parallel and return
    /// each result paired with its original index, so callers can keep
    /// page ordering stable.
    static func recognize(in images: [UIImage]) async -> [(index: Int, text: String)] {
        await withTaskGroup(of: (Int, String).self) { group in
            for (idx, image) in images.enumerated() {
                group.addTask {
                    let text = (try? await recognize(in: image)) ?? ""
                    return (idx, text)
                }
            }
            var collected: [(Int, String)] = []
            for await result in group {
                collected.append(result)
            }
            return collected.sorted { $0.0 < $1.0 }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Couldn't read that image."
        }
    }
}
