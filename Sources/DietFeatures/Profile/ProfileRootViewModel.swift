import Foundation
import Combine
import DietCore

@MainActor
public final class ProfileRootViewModel: ObservableObject {
    @Published public private(set) var profile: UserProfile?
    @Published public private(set) var plans: [PhasePlan] = []
    @Published public var errorMessage: String?

    private let profileService: ProfileService
    private let phaseService: PhasePlanService

    public init(profileStore: ProfileStoring, phasePlanStore: PhasePlanStoring) {
        self.profileService = ProfileService(store: profileStore)
        self.phaseService = PhasePlanService(store: phasePlanStore)
    }

    public func reload() {
        do {
            profile = try profileService.fetchProfile()
            plans = try phaseService.allPlans()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveProfile(_ input: ProfileInput) throws {
        _ = try profileService.saveProfile(input)
        reload()
    }

    public func startNewPhase(_ input: PhasePlanInput) throws {
        _ = try phaseService.startNewPhase(input)
        reload()
    }

    public func suggestedPhaseStartDate() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let current = plans.first(where: { $0.contains(Date()) }),
           calendar.isDate(current.startDate, inSameDayAs: today) {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }
}
