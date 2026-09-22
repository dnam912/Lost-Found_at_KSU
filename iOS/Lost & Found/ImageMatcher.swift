//
//  ImageMatcher.swift
//  Lost & Found
//
//  Vision-based on-device image similarity matching.
//  Uses VNGenerateImageFeaturePrintRequest to embed images into a
//  feature vector.
//

import UIKit
import Vision
import CoreImage

enum ImageMatcherError: Error, LocalizedError {
    case noImageData
    case visionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImageData:
            return "Couldn't read image data from that photo."
        case .visionFailed(let error):
            return "Vision analysis failed: \(error.localizedDescription)"
        }
    }
}

enum ImageMatcher {

    /// Fixed canvas size every image is redrawn into before feature
    /// extraction. Using an identical size/orientation/color-space for
    /// every image
    private static let canvasSize = CGSize(width: 360, height: 360)

    /// Number of cells per side in the color/pattern grid (e.g. 8 -> 8x8 = 64 cells).
    private static let colorGridSize = 8

    /// Everything we need to compare one photo against another
    struct AnalyzedSubject {
        let featurePrint: VNFeaturePrintObservation
        let colorSignature: ColorSignature
    }

   // color signiture pretty simple stuff using grid cells
    struct ColorSignature {
        /// Flattened [r, g, b] values (each 0...1), one triplet per grid cell.
        let values: [Float]
    }

    /// Runs full analysis (feature print + color signature) on an image once,
    /// so it can be cheaply compared against multiple candidates.
    static func analyze(_ image: UIImage) throws -> AnalyzedSubject {
        let subject = salientCrop(of: image)
        guard let normalized = subject.normalizedForVision(targetSize: canvasSize),
              let cgImage = normalized.cgImage else {
            throw ImageMatcherError.noImageData
        }

        let featurePrint = try featurePrint(fromPrepared: cgImage)
        let colorSignature = colorSignature(fromPrepared: cgImage)
        return AnalyzedSubject(featurePrint: featurePrint, colorSignature: colorSignature)
    }

    /// Generates a Vision feature print (embedding) for a given image.
    static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        (try? featurePrintOrThrow(for: image)) ?? nil
    }

    static func featurePrintOrThrow(for image: UIImage) throws -> VNFeaturePrintObservation {
        // Crop to the main object first so background/table/hand/lighting
        // differences between two photos of the *same* item matter far less
        // — VNGenerateImageFeaturePrintRequest embeds the whole frame, so
        // without this, a busier or emptier background can swing the score
        // even when the object itself is identical.
        let subject = salientCrop(of: image)

        guard let normalized = subject.normalizedForVision(targetSize: canvasSize),
              let cgImage = normalized.cgImage else {
            throw ImageMatcherError.noImageData
        }

        return try featurePrint(fromPrepared: cgImage)
    }

    private static func featurePrint(fromPrepared cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        // Image is already baked upright by normalizedForVision, so orientation is always .up.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("ImageMatcher: Vision perform failed - \(error)")
            throw ImageMatcherError.visionFailed(error)
        }

        guard let result = request.results?.first as? VNFeaturePrintObservation else {
            throw ImageMatcherError.noImageData
        }
        return result
    }

    /// Builds a color/pattern grid signature from an already-cropped,
    /// already-normalized (fixed-size, upright) subject image.
    private static func colorSignature(fromPrepared cgImage: CGImage) -> ColorSignature {
        let width = colorGridSize * 8   // sample at a modest fixed resolution, e.g. 64x64
        let height = colorGridSize * 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return ColorSignature(values: [Float](repeating: 0, count: colorGridSize * colorGridSize * 3))
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let cellPixels = width / colorGridSize
        var values = [Float](repeating: 0, count: colorGridSize * colorGridSize * 3)

        var globalSumR: Double = 0, globalSumG: Double = 0, globalSumB: Double = 0

        for cellY in 0..<colorGridSize {
            for cellX in 0..<colorGridSize {
                var sumR: Int = 0, sumG: Int = 0, sumB: Int = 0
                var count = 0
                for y in (cellY * cellPixels)..<((cellY + 1) * cellPixels) {
                    for x in (cellX * cellPixels)..<((cellX + 1) * cellPixels) {
                        let offset = y * bytesPerRow + x * bytesPerPixel
                        sumR += Int(pixelData[offset])
                        sumG += Int(pixelData[offset + 1])
                        sumB += Int(pixelData[offset + 2])
                        count += 1
                    }
                }
                let index = (cellY * colorGridSize + cellX) * 3
                let avgR = count > 0 ? Float(sumR) / Float(count) / 255.0 : 0
                let avgG = count > 0 ? Float(sumG) / Float(count) / 255.0 : 0
                let avgB = count > 0 ? Float(sumB) / Float(count) / 255.0 : 0
                values[index]     = avgR
                values[index + 1] = avgG
                values[index + 2] = avgB
                globalSumR += Double(avgR)
                globalSumG += Double(avgG)
                globalSumB += Double(avgB)
            }
        }

      // this is really bad im going to remove it
        let cellCount = colorGridSize * colorGridSize
        let epsilon = 0.02
        let meanR = max(globalSumR / Double(cellCount), epsilon)
        let meanG = max(globalSumG / Double(cellCount), epsilon)
        let meanB = max(globalSumB / Double(cellCount), epsilon)

        for cell in 0..<cellCount {
            let i = cell * 3
            values[i]     = Float(min(3.0, Double(values[i]) / meanR))
            values[i + 1] = Float(min(3.0, Double(values[i + 1]) / meanG))
            values[i + 2] = Float(min(3.0, Double(values[i + 2]) / meanB))
        }

        return ColorSignature(values: values)
    }
// slop
    static func colorDistance(_ a: ColorSignature, _ b: ColorSignature) -> Float {
        guard a.values.count == b.values.count, !a.values.isEmpty else { return 1 }
        let cellCount = a.values.count / 3
        var totalDistance: Float = 0
        for cell in 0..<cellCount {
            let i = cell * 3
            let dr = a.values[i] - b.values[i]
            let dg = a.values[i + 1] - b.values[i + 1]
            let db = a.values[i + 2] - b.values[i + 2]
            totalDistance += sqrt(dr * dr + dg * dg + db * db)
        }
        return totalDistance / Float(cellCount)
    }

   // cropping to find main item which is more hacks to prevent using hte groumd
    private static func salientCrop(of image: UIImage) -> UIImage {
        // Bake orientation upright at full resolution first (no resizing yet)
        // so detection sees the photo the same way a person would.
        guard let upright = image.normalizedForVision(targetSize: image.size),
              let cgImage = upright.cgImage else {
            return image
        }

        if let instanceCrop = foregroundInstanceCrop(cgImage: cgImage) {
            return instanceCrop
        }

        return boundingBoxSaliencyCrop(cgImage: cgImage) ?? upright
    }

    /// Uses `VNGenerateForegroundInstanceMaskRequest` to segment out
    /// individual foreground objects, picks the *largest* one
    private static func foregroundInstanceCrop(cgImage: CGImage) -> UIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("ImageMatcher: foreground instance mask failed - \(error)")
            return nil
        }

        guard
            let observation = request.results?.first,
            !observation.allInstances.isEmpty
        else {
            return nil
        }

        var bestBuffer: CVPixelBuffer?
        var bestArea: CGFloat = 0

        for label in observation.allInstances {
            guard let buffer = try? observation.generateMaskedImage(
                ofInstances: IndexSet([label]),
                from: handler,
                croppedToInstancesExtent: true
            ) else { continue }

            let extent = CIImage(cvPixelBuffer: buffer).extent
            let area = extent.width * extent.height
            if area > bestArea {
                bestArea = area
                bestBuffer = buffer
            }
        }

        guard let bestBuffer else { return nil }

        let ciImage = CIImage(cvPixelBuffer: bestBuffer)
        let context = CIContext()
        guard let cropped = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cropped)
    }

    /// Looser fallback: crop to the bounding box of the most salient object
    /// (background inside the box is kept, but at least off-object clutter
    /// outside the box is removed).
    private static func boundingBoxSaliencyCrop(cgImage: CGImage) -> UIImage? {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("ImageMatcher: saliency request failed - \(error)")
            return nil
        }

        guard
            let observation = request.results?.first,
            let salientObject = observation.salientObjects?.first
        else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Vision's normalized rects have origin at bottom-left; convert to
        // top-left pixel coordinates for CGImage cropping.
        var rect = CGRect(
            x: salientObject.boundingBox.origin.x * imageWidth,
            y: (1 - salientObject.boundingBox.origin.y - salientObject.boundingBox.height) * imageHeight,
            width: salientObject.boundingBox.width * imageWidth,
            height: salientObject.boundingBox.height * imageHeight
        )

        // Add ~15% padding on each side so we don't crop the object's edges off. (hack)
        let paddingX = rect.width * 0.15
        let paddingY = rect.height * 0.15
        rect = rect.insetBy(dx: -paddingX, dy: -paddingY)

        // Clamp to image bounds.
        rect = rect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        guard rect.width > 1, rect.height > 1, let cropped = cgImage.cropping(to: rect) else {
            return nil
        }

        return UIImage(cgImage: cropped)
    }

    /// Raw distance between two feature prints. 0 = identical, larger = more different.
    static func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
            #if DEBUG
            print("ImageMatcher: raw distance = \(distance)")
            #endif
            return distance
        } catch {
            print("ImageMatcher: failed to compute distance - \(error)")
            return nil
        }
    }

    // i Harly like how this works this is just hacking %s again very bad
    static func matchPercentage(distance: Float, low: Float = 0.15, high: Float = 0.95) -> Int {
        let clamped = max(low, min(distance, high))
        let normalized = (clamped - low) / (high - low) // 0 = perfect match, 1 = no match
        let score = (1 - normalized) * 100
        return Int(score.rounded())
    }

    // genuinely too strong will hate comparing pink to light pink why is it like this maybe use AI / btter ML
    static func colorMatchPercentage(distance: Float, low: Float = 0.12, high: Float = 0.7) -> Int {
        let clamped = max(low, min(distance, high))
        let normalized = (clamped - low) / (high - low)
        let score = (1 - normalized) * 100
        return Int(score.rounded())
    }

// storing all this stuff
    struct CombinedMatchScore {
        let overallPercentage: Int
        let visionPercentage: Int
        let colorPercentage: Int
        let visionDistance: Float
        let colorDistance: Float
    }

    /// Compares two already-analyzed subjects and produces a combined score.
    static func compare(_ a: AnalyzedSubject, _ b: AnalyzedSubject) -> CombinedMatchScore? {
        guard let visionDist = distance(a.featurePrint, b.featurePrint) else { return nil }
        let colorDist = colorDistance(a.colorSignature, b.colorSignature)

        let visionPct = matchPercentage(distance: visionDist)
        let colorPct = colorMatchPercentage(distance: colorDist)

       // more shitty hacks. Not a fan. Probably wont be here for lomng
        let weighted = (Double(colorPct) * 0.55) + (Double(visionPct) * 0.45)
        let capped = min(weighted, Double(colorPct) + 25)
        let overall = Int(max(0, min(100, capped)).rounded())
        // this is actually terrible I just keep spamming hacks togehter
        return CombinedMatchScore(
            overallPercentage: overall,
            visionPercentage: visionPct,
            colorPercentage: colorPct,
            visionDistance: visionDist,
            colorDistance: colorDist
        )
    }

    ///  analyzes and compares two images directly.
    static func compare(_ imageA: UIImage, _ imageB: UIImage) -> CombinedMatchScore? {
        guard
            let subjectA = try? analyze(imageA),
            let subjectB = try? analyze(imageB)
        else { return nil }
        return compare(subjectA, subjectB)
    }
}

// MARK: - Helpers

extension UIImage {
// make the bitmap
    func normalizedForVision(targetSize: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            // a really mid tier hack in order to not use alot of background (I need to imporve this lol)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))

            // Aspect-fill: scale so the shorter side fills the canvas, then
            // center-crop, so the subject fills the frame consistently.
            let widthRatio = targetSize.width / size.width
            let heightRatio = targetSize.height / size.height
            let scale = max(widthRatio, heightRatio)
            let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
