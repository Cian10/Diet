import SwiftUI
import DietCore

@MainActor
public final class DietAnalysisViewModel: ObservableObject {
    @Published public var selectedRange: DietAnalysisRange = .sevenDays
    @Published public private(set) var isLoading = false
    @Published public private(set) var resultText: String?
    @Published public private(set) var lastCompletedRange: DietAnalysisRange?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var hasNoConfirmedEntries = false

    private let service: DietAnalysisService
    private let nowProvider: () -> Date

    public convenience init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        llmProvider: LLMClientProviding
    ) {
        self.init(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: llmProvider,
            calendar: .current,
            nowProvider: Date.init
        )
    }

    public init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        llmProvider: LLMClientProviding,
        calendar: Calendar,
        nowProvider: @escaping () -> Date
    ) {
        service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: llmProvider,
            calendar: calendar
        )
        self.nowProvider = nowProvider
    }

    public func rangeDidChange() {
        resultText = nil
        lastCompletedRange = nil
        errorMessage = nil
        hasNoConfirmedEntries = false
    }

    public func analyze() async {
        guard !isLoading else { return }
        let requestedRange = selectedRange
        isLoading = true
        resultText = nil
        lastCompletedRange = nil
        errorMessage = nil
        hasNoConfirmedEntries = false
        defer { isLoading = false }

        do {
            let report = try await service.analyze(range: requestedRange, now: nowProvider())
            resultText = report
            lastCompletedRange = requestedRange
        } catch DietAnalysisError.noConfirmedEntries {
            hasNoConfirmedEntries = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
public struct DietAnalysisView: View {
    @StateObject private var viewModel: DietAnalysisViewModel

    public init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        llmProvider: LLMClientProviding
    ) {
        _viewModel = StateObject(wrappedValue: DietAnalysisViewModel(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: llmProvider
        ))
    }

    public var body: some View {
        NavigationStack {
            DietPage {
                DietPageHeader(
                    title: "AI 饮食分析",
                    subtitle: "由你主动选择已确认记录，让 AI 帮你整理饮食模式与下一步重点。"
                )

                scopeCard
                privacyCard
                actionArea

                if viewModel.isLoading {
                    DietCard {
                        DietLoadingLabel(title: "正在整理并分析所选记录…")
                    }
                }

                if viewModel.hasNoConfirmedEntries {
                    DietCard {
                        DietEmptyState(
                            title: "没有可分析的已确认记录",
                            message: "所选日期内还没有已确认餐食。请先确认饮食记录，或选择更长的时间范围。",
                            systemImage: "fork.knife.circle"
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 12) {
                        DietInlineNotice(.error, title: "分析失败", message: error)
                        Button("重试") { analyze() }
                            .buttonStyle(.dietSecondary)
                            .disabled(viewModel.isLoading)
                    }
                }

                if let result = viewModel.resultText {
                    reportCard(result)
                }
            }
            .onChange(of: viewModel.selectedRange) { _, _ in
                viewModel.rangeDidChange()
            }
        }
    }

    private var scopeCard: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 14) {
                DietSectionHeader(title: "分析范围", subtitle: "包含今天")
                Picker("分析范围", selection: $viewModel.selectedRange) {
                    ForEach(DietAnalysisRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isLoading)
                Text("按本地日历计算近 7、14 或 30 个自然日；切换范围不会自动发起请求。")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyCard: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("仅在点击后上传", systemImage: "lock.shield")
                    .font(DietTheme.Typography.cardTitle)
                    .foregroundStyle(DietTheme.Palette.ink)
                Text("上传所选日期内已确认餐食的文字、食物组成、本地营养汇总和已保存每日目标。不会上传图片、图片路径、草稿、失败记录或完整个人档案。")
                    .font(.body)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("未知营养不会被当作零；未记录日期也不会被推断为零摄入。分析报告仅在当前页面展示，不会保存。")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionArea: some View {
        HStack(spacing: 12) {
            Button(viewModel.resultText == nil ? "开始分析" : "重新分析") {
                analyze()
            }
            .buttonStyle(.dietPrimary)
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                DietLoadingLabel(title: "分析中")
            } else {
                Text("默认返回中文纯文本，不要求模型输出 JSON。")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func reportCard(_ report: String) -> some View {
        DietCard {
            VStack(alignment: .leading, spacing: 12) {
                DietSectionHeader(
                    title: "分析结果",
                    subtitle: viewModel.lastCompletedRange?.displayName
                )
                ScrollView {
                    Text(verbatim: report)
                        .font(.body)
                        .foregroundStyle(DietTheme.Palette.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 520)
                Text("可直接选择文字并复制。建议仅供饮食记录整理与日常调整参考，不替代医疗意见。")
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
        }
    }

    private func analyze() {
        Task { await viewModel.analyze() }
    }
}
