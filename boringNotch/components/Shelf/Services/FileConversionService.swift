//
//  FileConversionService.swift
//  boringNotch
//
//  Converts files dropped on the shelf (images, video, audio, PDF).
//

import AVFoundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

enum ConversionTarget: Hashable, Identifiable {
    case image(ImageConversionOptions.ImageFormat)
    case imagesToPDF
    case pdfToPNG
    case videoMP4
    case videoMOV
    case extractAudio
    case audioM4A

    var id: Self { self }

    var title: String {
        switch self {
        case .image(let format):
            switch format {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .heic: return "HEIC"
            case .tiff: return "TIFF"
            case .bmp: return "BMP"
            }
        case .imagesToPDF: return "PDF"
        case .pdfToPNG: return "PNG"
        case .videoMP4: return "MP4"
        case .videoMOV: return "MOV"
        case .extractAudio: return "Audio (M4A)"
        case .audioM4A: return "M4A"
        }
    }
}

enum FileConversionError: LocalizedError {
    case unsupported
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This conversion is not supported for these files."
        case .exportFailed(let reason): return reason
        }
    }
}

@MainActor
final class FileConversionService {
    static let shared = FileConversionService()
    private init() {}

    enum Category {
        case image, video, audio, pdf
    }

    func category(of url: URL) -> Category? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return nil
    }

    /// Conversions offered for a set of dropped files. Empty when the files are mixed or unsupported.
    func targets(for urls: [URL]) -> [ConversionTarget] {
        let categories = Set(urls.map { category(of: $0) })
        guard categories.count == 1, let category = categories.first ?? nil else { return [] }

        switch category {
        case .image:
            return [.image(.png), .image(.jpeg), .image(.heic), .image(.tiff), .imagesToPDF]
        case .video:
            return [.videoMP4, .videoMOV, .extractAudio]
        case .audio:
            return [.audioM4A]
        case .pdf:
            return [.pdfToPNG]
        }
    }

    func convert(_ urls: [URL], to target: ConversionTarget) async throws -> [URL] {
        switch target {
        case .image(let format):
            let options = ImageConversionOptions(
                format: format, compressionQuality: 0.9, maxDimension: nil, removeMetadata: false)
            var results: [URL] = []
            for url in urls {
                if let out = try await ImageProcessingService.shared.convertImage(from: url, options: options) {
                    results.append(out)
                }
            }
            return results

        case .imagesToPDF:
            guard let out = try await ImageProcessingService.shared.createPDF(from: urls) else {
                throw FileConversionError.exportFailed("Could not create the PDF.")
            }
            return [out]

        case .pdfToPNG:
            var results: [URL] = []
            for url in urls { results += try await renderPDFPages(url) }
            return results

        case .videoMP4:
            return try await exportEach(urls, preset: AVAssetExportPresetHighestQuality, type: .mp4, ext: "mp4")
        case .videoMOV:
            return try await exportEach(urls, preset: AVAssetExportPresetHighestQuality, type: .mov, ext: "mov")
        case .extractAudio, .audioM4A:
            return try await exportEach(urls, preset: AVAssetExportPresetAppleM4A, type: .m4a, ext: "m4a")
        }
    }

    // MARK: - PDF

    private func renderPDFPages(_ url: URL) async throws -> [URL] {
        guard let document = PDFDocument(url: url) else { throw FileConversionError.unsupported }
        let base = url.deletingPathExtension().lastPathComponent
        var results: [URL] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let image = page.thumbnail(of: CGSize(width: bounds.width * 2, height: bounds.height * 2), for: .mediaBox)
            guard let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
                  let out = await TemporaryFileStorageService.shared.createTempFile(
                      for: .data(png, suggestedName: "\(base)_page\(index + 1).png"))
            else { continue }
            results.append(out)
        }

        guard !results.isEmpty else { throw FileConversionError.exportFailed("The PDF has no readable pages.") }
        return results
    }

    // MARK: - Audio / video

    private func exportEach(_ urls: [URL], preset: String, type: AVFileType, ext: String) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            results.append(try await export(url, preset: preset, type: type, ext: ext))
        }
        return results
    }

    private func export(_ url: URL, preset: String, type: AVFileType, ext: String) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw FileConversionError.unsupported
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let output = directory.appendingPathComponent(
            url.deletingPathExtension().lastPathComponent + "_converted." + ext)

        session.outputURL = output
        session.outputFileType = type

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }

        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: directory)
            throw FileConversionError.exportFailed(session.error?.localizedDescription ?? "Export failed.")
        }
        return output
    }
}
