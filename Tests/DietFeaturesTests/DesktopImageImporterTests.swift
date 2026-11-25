#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DietFeatures
import DietCore

@Suite("Desktop image importing", .serialized)
@MainActor
final class DesktopImageImporterTests {
    @Test("Valid PNG and JPEG files retain their original bytes")
    func importsImageFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for type in [UTType.png, UTType.jpeg] {
            let data = try Self.makeImage(type: type)
            let url = root.appendingPathComponent("meal.\(type.preferredFilenameExtension ?? "image")")
            try data.write(to: url)
            #expect(try DesktopImageImporter.imageData(fromFile: url) == data)
        }
    }

    @Test("Clipboard image candidates and Finder file URLs share validation")
    func importsClipboardRepresentations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try Self.makeImage(type: .png)
        let url = root.appendingPathComponent("finder-meal.png")
        try data.write(to: url)

        #expect(try DesktopImageImporter.imageData(fromImageDataCandidates: [data], fileURLs: []) == data)
        #expect(try DesktopImageImporter.imageData(fromImageDataCandidates: [], fileURLs: [url]) == data)
        #expect(try DesktopImageImporter.imageData(
            fromImageDataCandidates: [Data("not an image".utf8), data],
            fileURLs: []
        ) == data)
    }

    @Test("Empty and invalid imports have explicit errors")
    func rejectsInvalidInputs() throws {
        #expect(throws: DesktopImageImportError.noImage) {
            _ = try DesktopImageImporter.imageData(fromImageDataCandidates: [], fileURLs: [])
        }
        #expect(throws: DesktopImageImportError.invalidImage) {
            _ = try DesktopImageImporter.imageData(
                fromImageDataCandidates: [Data("not an image".utf8)],
                fileURLs: []
            )
        }

        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        #expect(throws: DesktopImageImportError.unreadableFile) {
            _ = try DesktopImageImporter.imageData(fromFile: missing)
        }
    }

    @Test("Failed replacement preserves the current image and draft")
    func failedReplacementPreservesState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let mealStore = InMemoryMealEntryStore()
        let foodService = FoodLoggingService(store: mealStore, clientProvider: ImportStubProvider())
        let viewModel = PhotoLoggingViewModel(
            photoService: PhotoLoggingService(imageStore: try LocalImageStore(rootDirectory: root), foodLogging: foodService),
            foodService: foodService
        )
        let validData = try Self.makeImage(type: .png)
        viewModel.importImage { validData }
        viewModel.draft = try viewModel.photoService.createDraft()
        let draft = viewModel.draft

        viewModel.importImage { throw DesktopImageImportError.invalidImage }

        #expect(viewModel.originalData == validData)
        #expect(viewModel.draft === draft)
        #expect(viewModel.errorMessage == DesktopImageImportError.invalidImage.localizedDescription)
    }

    private static func makeImage(type: UTType) throws -> Data {
        let context = CGContext(
            data: nil,
            width: 12,
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 12, height: 10))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

@MainActor
private final class ImportStubProvider: LLMClientProviding {
    func client() throws -> any LLMClient { throw LLMError.notConfigured }
}
#endif
