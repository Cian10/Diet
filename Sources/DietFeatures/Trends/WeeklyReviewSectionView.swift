import SwiftUI
import DietCore

@MainActor
public final class WeeklyReviewViewModel: ObservableObject {
    @Published public private(set) var overview: TrendsOverview?
    @Published public private(set) var proposal: AdjustmentProposal?
    @Published public private(set) var explanation = ""
    @Published public var errorMessage: String?

    private let trendsService: TrendsService
    private let phaseStore: PhasePlanStoring
    private let proposalStore: AdjustmentProposalStoring
    private let reviewEngine = ReviewEngine()

    public init(trendsService: TrendsService, phaseStore: PhasePlanStoring, proposalStore: AdjustmentProposalStoring) {
        self.trendsService = trendsService
        self.phaseStore = phaseStore
        self.proposalStore = proposalStore
    }

    public func load() {
        do {
            let trends = try trendsService.weeklyReview()
            overview = trends.overview
            guard try phaseStore.allPlans().contains(where: { $0.contains(Date()) }) else {
                proposal = nil
                explanation = "当前没有生效中的阶段，不生成调整建议。"
                return
            }
            var result = reviewEngine.review(days: trends.days, overview: trends.overview, endingOn: Date())
            if let generated = result.proposal {
                let existing = try proposalStore.allProposals().first {
                    Calendar.current.isDate($0.effectiveDate, inSameDayAs: generated.effectiveDate)
                        && $0.newCalories == generated.newCalories
                }
                if let existing {
                    result.proposal = existing
                } else {
                    try proposalStore.saveProposal(generated)
                }
            }
            proposal = result.proposal
            explanation = result.explanation
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func accept() {
        do {
            guard let proposal, let phase = try phaseStore.allPlans().first(where: { $0.contains(Date()) }) else { return }
            _ = try AdjustmentService(store: proposalStore, phaseStore: phaseStore).accept(proposal, phaseType: phase.phaseType)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func reject() {
        do {
            guard let proposal else { return }
            try AdjustmentService(store: proposalStore, phaseStore: phaseStore).reject(proposal)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct WeeklyReviewSectionView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    var onChanged: () -> Void

    public var body: some View {
        Section("每周复盘") {
            Text(viewModel.explanation)
            if let proposal = viewModel.proposal {
                LabeledContent("状态", value: proposal.status.displayName)
                LabeledContent("生效日期", value: proposal.effectiveDate.formatted(date: .abbreviated, time: .omitted))
                if let old = proposal.oldCalories, let new = proposal.newCalories {
                    LabeledContent("目标热量", value: "\(old.formatted()) → \(new.formatted()) kcal")
                }
                Text(proposal.triggerSummary).font(.footnote).foregroundStyle(.secondary)
                if proposal.status == .pending {
                    Button("接受并创建新阶段版本") {
                        viewModel.accept()
                        onChanged()
                    }
                    Button("拒绝此建议", role: .destructive) {
                        viewModel.reject()
                        onChanged()
                    }
                }
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            Text("单日偏差不会触发长期目标调整；接受建议前不会修改阶段。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

public extension AdjustmentStatus {
    var displayName: String {
        switch self {
        case .pending: "待确认"
        case .accepted: "已接受"
        case .rejected: "已拒绝"
        }
    }
}
