import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("Form state")
struct FormStateTests {
    @Test("Profile fields parse optional values and lists")
    func profileStateParsesOptionalFieldsAndLists() throws {
        var state = ProfileFormState()
        state.ageText = "28"
        state.heightText = "175.5"
        state.weightText = ""
        state.dietaryPreferencesText = "高蛋白、低脂，高蛋白"
        state.allergiesText = "花生, 牛奶"

        let input = try state.makeInput().validated()
        #expect(input.ageYears == 28)
        #expect(input.heightCentimeters == 175.5)
        #expect(input.currentWeightKilograms == nil)
        #expect(input.dietaryPreferences == ["高蛋白", "低脂"])
        #expect(input.allergies == ["花生", "牛奶"])
    }

    @Test("Manual phase requires calories")
    func manualPhaseRequiresCalories() throws {
        var state = PhasePlanFormState()
        state.energyStrategy = .manual
        state.caloriesText = ""
        #expect(throws: PhasePlanValidationError.missingManualCalories) {
            try state.makeInput().validated()
        }
    }

    @Test("Invalid numeric text identifies its field")
    func invalidNumericTextHasFieldError() {
        var state = ProfileFormState()
        state.heightText = "一米七五"
        #expect(throws: FormStateError.invalidNumber(field: "身高")) {
            try state.makeInput()
        }
    }
}
