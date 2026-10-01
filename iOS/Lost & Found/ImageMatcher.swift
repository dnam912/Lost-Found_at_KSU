//
//  ImageMatcher.swift
//  Lost & Found
//
//  Image similarity matching with Vision and an optional MobileCLIP2 image encoder.
//

import UIKit
import Vision
import ImageIO
import CoreML

private let mobileCLIPModelName = "mobileclip_s2_image"

enum ImageMatcherError: Error, LocalizedError {
    case noImageData
    case visionFailed(Error)
    case mobileCLIPFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImageData:
            return "Couldn't read image data from that photo."
        case .visionFailed(let error):
            return "Vision analysis failed: \(error.localizedDescription)"
        case .mobileCLIPFailed(let error):
            return "MobileCLIP analysis failed: \(error.localizedDescription)"
        }
    }
}

enum ImageMatcher {
    static let disclosureSimilarityThreshold: Float = 0.75

    struct AnalyzedSubject {
        let featurePrint: VNFeaturePrintObservation
        let mobileCLIPEmbedding: [Float]?
    }

    struct MatchScore {
        let visionDistance: Float
        let mobileCLIPDistance: Float?

        var usesMobileCLIP: Bool {
            mobileCLIPDistance != nil
        }

        /// The model distance used for ranking. Lower is better.
        var distance: Float {
            mobileCLIPDistance ?? visionDistance
        }

        var mobileCLIPSimilarity: Float? {
            guard let mobileCLIPDistance else { return nil }
            return 1 - mobileCLIPDistance
        }

        /// Only MobileCLIP's raw cosine similarity can authorize showing a post.
        /// Vision fallback scores are not calibrated to this threshold.
        var qualifiesForDisclosure: Bool {
            guard let mobileCLIPSimilarity else { return false }
            return mobileCLIPSimilarity >= ImageMatcher.disclosureSimilarityThreshold
        }

        /// A display value only; it is not a probability or calibrated confidence.
        var percentage: Int {
            if let mobileCLIPSimilarity {
                return max(0, min(100, Int((mobileCLIPSimilarity * 100).rounded())))
            }
            return max(0, min(100, Int(((1 - visionDistance) * 100).rounded())))
        }
    }

    private static let mobileCLIP = MobileCLIPImageEncoder()

    static func mobileCLIPEmbedding(for image: UIImage) throws -> [Float] {
        try mobileCLIP.embedding(for: image)
    }

    static func analyze(_ image: UIImage) throws -> AnalyzedSubject {
        let featurePrint = try featurePrintOrThrow(for: image)
        let embedding = try? mobileCLIP.embedding(for: image)
        return AnalyzedSubject(featurePrint: featurePrint, mobileCLIPEmbedding: embedding)
    }

    static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        try? featurePrintOrThrow(for: image)
    }

    static func featurePrintOrThrow(for image: UIImage) throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else {
            throw ImageMatcherError.noImageData
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            throw ImageMatcherError.visionFailed(error)
        }

        guard let featurePrint = request.results?.first as? VNFeaturePrintObservation else {
            throw ImageMatcherError.noImageData
        }
        return featurePrint
    }

    static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
            return distance
        } catch {
            return nil
        }
    }

    static func compare(_ a: AnalyzedSubject, _ b: AnalyzedSubject) -> MatchScore? {
        guard let visionDistance = distance(a.featurePrint, b.featurePrint) else {
            return nil
        }

        let mobileCLIPDistance: Float?
        if let first = a.mobileCLIPEmbedding, let second = b.mobileCLIPEmbedding {
            mobileCLIPDistance = cosineDistance(first, second)
        } else {
            mobileCLIPDistance = nil
        }

        return MatchScore(
            visionDistance: visionDistance,
            mobileCLIPDistance: mobileCLIPDistance
        )
    }

    static func compare(_ imageA: UIImage, _ imageB: UIImage) -> MatchScore? {
        guard
            let subjectA = try? analyze(imageA),
            let subjectB = try? analyze(imageB)
        else {
            return nil
        }
        return compare(subjectA, subjectB)
    }

    private static func cosineDistance(_ first: [Float], _ second: [Float]) -> Float? {
        guard first.count == second.count, !first.isEmpty else { return nil }

        var dot: Float = 0
        var firstMagnitude: Float = 0
        var secondMagnitude: Float = 0
        for index in first.indices {
            dot += first[index] * second[index]
            firstMagnitude += first[index] * first[index]
            secondMagnitude += second[index] * second[index]
        }

        guard firstMagnitude > 0, secondMagnitude > 0 else { return nil }
        let cosineSimilarity = dot / (sqrt(firstMagnitude) * sqrt(secondMagnitude))
        return 1 - cosineSimilarity
    }
}

private final class MobileCLIPImageEncoder {
    private let model: MLModel?

    init() {
        guard let modelURL = Bundle.main.url(
            forResource: mobileCLIPModelName,
            withExtension: "mlmodelc"
        ) else {
            model = nil
            return
        }

        model = try? MLModel(contentsOf: modelURL)
    }

    func embedding(for image: UIImage) throws -> [Float] {
        guard let model else {
            throw ImageMatcherError.mobileCLIPFailed(MobileCLIPUnavailable())
        }
        guard let imageInput = model.modelDescription.inputDescriptionsByName.first(where: {
            $0.value.type == .image
        }) else {
            throw ImageMatcherError.mobileCLIPFailed(MobileCLIPModelError.missingImageInput)
        }
        guard let output = model.modelDescription.outputDescriptionsByName.first(where: {
            $0.value.type == .multiArray
        }) else {
            throw ImageMatcherError.mobileCLIPFailed(MobileCLIPModelError.missingEmbeddingOutput)
        }

        let constraint = imageInput.value.imageConstraint
        let width = constraint?.pixelsWide ?? 256
        let height = constraint?.pixelsHigh ?? 256
        let pixelBuffer = try makePixelBuffer(from: image, width: width, height: height)
        let input = MLFeatureValue(pixelBuffer: pixelBuffer)
        let provider = try MLDictionaryFeatureProvider(dictionary: [imageInput.key: input])
        let result = try model.prediction(from: provider)

        guard let array = result.featureValue(for: output.key)?.multiArrayValue else {
            throw MobileCLIPModelError.missingEmbeddingOutput
        }
        return (0..<array.count).map { array[$0].floatValue }
    }

    private func makePixelBuffer(from image: UIImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw MobileCLIPModelError.pixelBufferCreationFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw MobileCLIPModelError.pixelBufferCreationFailed
        }

        let targetSize = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let preparedImage = renderer.image { _ in
            let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }

        guard let cgImage = preparedImage.cgImage else {
            throw ImageMatcherError.noImageData
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw MobileCLIPModelError.pixelBufferCreationFailed }

        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

private struct MobileCLIPUnavailable: LocalizedError {
    var errorDescription: String? {
        "Add \(mobileCLIPModelName).mlmodel to the Xcode target to enable MobileCLIP."
    }
}

private enum MobileCLIPModelError: Error {
    case missingImageInput
    case missingEmbeddingOutput
    case pixelBufferCreationFailed
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
