import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DietCore

@Suite("Image and photo logging", .serialized)
@MainActor
final class ImageServiceTests {
    @Test("Photo analysis and retry reuse one local original and one entry")
    func photoAnalysisAndRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let imageStore = try LocalImageStore(rootDirectory: root)
        let mealStore = InMemoryMealEntryStore()
        let provider = PhotoStubProvider()
        let foodService = FoodLoggingService(store: mealStore, clientProvider: provider)
        let service = PhotoLoggingService(imageStore: imageStore, foodLogging: foodService)

        let entry = try await service.analyze(originalData: Self.makeJPEG(), consumedAt: Date(), mealType: .lunch)
        let path = try #require(entry.localImagePath)
        #expect(try imageStore.loadOriginal(relativePath: path).isEmpty == false)
        #expect(provider.requests.count == 1)
        let retried = try await service.retry(entry)
        #expect(retried === entry)
        #expect(retried.localImagePath == path)
        #expect(provider.requests.count == 2)
        #expect(try mealStore.allEntries().count == 1)
    }

    @Test("Original image is retained and upload copy is JPEG")
    func imageStorage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LocalImageStore(rootDirectory: root)
        let original = try Self.makeJPEG()
        let stored = try store.save(originalData: original)

        #expect(stored.originalData == original)
        #expect(stored.uploadData.starts(with: [0xFF, 0xD8]))
        #expect(try store.loadOriginal(relativePath: stored.relativePath) == original)
        try store.delete(relativePath: stored.relativePath)
        #expect(throws: Error.self) { try store.loadOriginal(relativePath: stored.relativePath) }
    }

    @Test("Invalid image is rejected before model upload")
    func invalidImage() {
        #expect(throws: LLMError.invalidImage) {
            _ = try ImageProcessor.uploadJPEG(from: Data("not an image".utf8))
        }
    }

    private static func makeJPEG() throws -> Data {
        let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

@MainActor
private final class PhotoStubProvider: LLMClientProviding {
    var requests: [FoodUnderstandingRequest] = []
    func client() throws -> any LLMClient { PhotoStubClient(provider: self) }
}

@MainActor
private final class PhotoStubClient: LLMClient {
    let provider: PhotoStubProvider
    init(provider: PhotoStubProvider) { self.provider = provider }
    func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult {
        provider.requests.append(request)
        return FoodUnderstandingResult(items: [FoodCandidate(
            name: "测试食物",
            quantity: 1,
            unit: "份",
            nutrition: NutritionCandidate(
                basisQuantity: 1,
                basisUnit: "serving",
                calories: 300,
                proteinGrams: 20,
                carbohydrateGrams: 30,
                fatGrams: 10
            )
        )])
    }
}
