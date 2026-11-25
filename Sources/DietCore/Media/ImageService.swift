import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct StoredImage: Sendable {
    public var relativePath: String
    public var originalData: Data
    public var uploadData: Data

    public init(relativePath: String, originalData: Data, uploadData: Data) {
        self.relativePath = relativePath
        self.originalData = originalData
        self.uploadData = uploadData
    }
}

public protocol ImageStoring: AnyObject {
    func save(originalData: Data) throws -> StoredImage
    func loadOriginal(relativePath: String) throws -> Data
    func delete(relativePath: String) throws
}

public enum ImageProcessor: Sendable {
    public static func uploadJPEG(from originalData: Data, maximumPixelSize: Int = 1600) throws -> Data {
        guard !originalData.isEmpty,
              let source = CGImageSourceCreateWithData(originalData as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
              ] as CFDictionary) else {
            throw LLMError.invalidImage
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { throw LLMError.invalidImage }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw LLMError.invalidImage }
        return output as Data
    }
}

public final class LocalImageStore: ImageStoring {
    private let rootDirectory: URL
    private let fileManager: FileManager

    public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootDirectory = applicationSupport.appendingPathComponent("DietApp/Images", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    public func save(originalData: Data) throws -> StoredImage {
        let uploadData = try ImageProcessor.uploadJPEG(from: originalData)
        let fileExtension = Self.fileExtension(for: originalData) ?? "image"
        let filename = UUID().uuidString + "." + fileExtension
        let url = rootDirectory.appendingPathComponent(filename)
        try originalData.write(to: url, options: .atomic)
        return StoredImage(relativePath: filename, originalData: originalData, uploadData: uploadData)
    }

    public func loadOriginal(relativePath: String) throws -> Data {
        guard Self.isSafeRelativePath(relativePath) else { throw LLMError.invalidImage }
        return try Data(contentsOf: rootDirectory.appendingPathComponent(relativePath))
    }

    public func delete(relativePath: String) throws {
        guard Self.isSafeRelativePath(relativePath) else { throw LLMError.invalidImage }
        let url = rootDirectory.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func fileExtension(for data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) else { return nil }
        return UTType(identifier as String)?.preferredFilenameExtension
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && URL(fileURLWithPath: path).lastPathComponent == path && path != "." && path != ".."
    }
}

@MainActor
public final class PhotoLoggingService {
    private let imageStore: ImageStoring
    private let foodLogging: FoodLoggingService

    public init(imageStore: ImageStoring, foodLogging: FoodLoggingService) {
        self.imageStore = imageStore
        self.foodLogging = foodLogging
    }

    public func analyze(
        originalData: Data,
        consumedAt: Date = Date(),
        mealType: MealType = .other,
        existingEntry: MealEntry? = nil
    ) async throws -> MealEntry {
        let replacedPath = existingEntry?.localImagePath
        let stored = try imageStore.save(originalData: originalData)
        do {
            let entry = try await foodLogging.analyzeImage(
                uploadData: stored.uploadData,
                localImagePath: stored.relativePath,
                consumedAt: consumedAt,
                mealType: mealType,
                existingEntry: existingEntry
            )
            if let replacedPath, replacedPath != stored.relativePath {
                try? imageStore.delete(relativePath: replacedPath)
            }
            return entry
        } catch {
            if let replacedPath, replacedPath != stored.relativePath {
                try? imageStore.delete(relativePath: replacedPath)
            }
            throw error
        }
    }

    public func createDraft(consumedAt: Date = Date(), mealType: MealType = .other) throws -> MealEntry {
        try foodLogging.createManualEntry(consumedAt: consumedAt, mealType: mealType)
    }

    public func retry(_ entry: MealEntry) async throws -> MealEntry {
        guard let path = entry.localImagePath else { throw FoodLoggingError.missingImage }
        let original = try imageStore.loadOriginal(relativePath: path)
        let upload = try ImageProcessor.uploadJPEG(from: original)
        return try await foodLogging.analyzeImage(
            uploadData: upload,
            localImagePath: path,
            consumedAt: entry.consumedAt,
            mealType: entry.mealType,
            existingEntry: entry
        )
    }
}
