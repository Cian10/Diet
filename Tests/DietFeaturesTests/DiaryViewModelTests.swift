import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("DiaryViewModel")
@MainActor
final class DiaryViewModelTests {
    @Test("Diary filters dates and offers separate image deletion")
    func diaryDateAndDeletion() throws {
        let meals = InMemoryMealEntryStore()
        let targets = InMemoryDailyTargetStore()
        let images = DiaryImageStore()
        let viewModel = DiaryViewModel(mealStore: meals, targetStore: targets, imageStore: images)
        let date = Date()
        let other = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let entry = MealEntry(consumedAt: date, status: .confirmed, localImagePath: "meal.jpg")
        try meals.saveEntry(entry)
        try meals.saveEntry(MealEntry(consumedAt: other, status: .confirmed))

        viewModel.selectedDate = date
        viewModel.load()
        #expect(viewModel.entries.count == 1)
        viewModel.delete(entry, deletingImage: false)
        #expect(images.deleted.isEmpty)
        #expect(try meals.allEntries().count == 1)

        try meals.saveEntry(entry)
        viewModel.delete(entry, deletingImage: true)
        #expect(images.deleted == ["meal.jpg"])
    }
}

private final class DiaryImageStore: ImageStoring {
    var deleted: [String] = []
    func save(originalData: Data) throws -> StoredImage {
        StoredImage(relativePath: "meal.jpg", originalData: originalData, uploadData: originalData)
    }
    func loadOriginal(relativePath: String) throws -> Data { Data() }
    func delete(relativePath: String) throws { deleted.append(relativePath) }
}
