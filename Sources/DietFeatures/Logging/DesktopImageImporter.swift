#if os(macOS)
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum DesktopImageImportError: LocalizedError, Equatable {
    case noImage
    case invalidImage
    case unreadableFile

    public var errorDescription: String? {
        switch self {
        case .noImage:
            "剪贴板中没有可用图片。请复制截图或图片文件后再粘贴。"
        case .invalidImage:
            "所选内容不是可解码的图片，当前图片和草稿未被修改。"
        case .unreadableFile:
            "无法读取所选图片文件，请检查文件是否仍可访问。"
        }
    }
}

@MainActor
public struct DesktopImageImporter {
    public init() {}

    public static func imageDataFromClipboard(_ pasteboard: NSPasteboard = .general) throws -> Data {
        var candidates: [Data] = []
        for type in pasteboard.types ?? [] {
            guard UTType(type.rawValue)?.conforms(to: .image) == true,
                  let data = pasteboard.data(forType: type) else { continue }
            candidates.append(data)
        }

        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let fileURLs = (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] ?? [])
            .map { $0 as URL }

        if let image = NSImage(pasteboard: pasteboard),
           let data = image.tiffRepresentation {
            candidates.append(data)
        }

        return try imageData(fromImageDataCandidates: candidates, fileURLs: fileURLs)
    }

    static func imageData(fromImageDataCandidates candidates: [Data], fileURLs: [URL]) throws -> Data {
        var lastError: DesktopImageImportError?
        for data in candidates {
            do {
                return try validatedImageData(data)
            } catch let error as DesktopImageImportError {
                lastError = error
            }
        }
        for fileURL in fileURLs {
            do {
                return try imageData(fromFile: fileURL)
            } catch let error as DesktopImageImportError {
                lastError = error
            }
        }
        throw lastError ?? .noImage
    }

    public static func imageData(fromFile url: URL) throws -> Data {
        guard url.isFileURL else { throw DesktopImageImportError.unreadableFile }
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            return try validatedImageData(data)
        } catch let error as DesktopImageImportError {
            throw error
        } catch {
            throw DesktopImageImportError.unreadableFile
        }
    }

    private static func validatedImageData(_ data: Data) throws -> Data {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 16
              ] as CFDictionary) != nil else {
            throw DesktopImageImportError.invalidImage
        }
        return data
    }
}
#endif
