import SwiftUI

#if os(macOS)
struct DietSidebar: View {
    @Binding var selection: AppTab
    var phaseSummary: String = "未设置阶段"
    var weightSummary: String? = nil

    @State private var hoveredTab: AppTab?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(AppTab.primarySidebarItems, id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                                .font(.body)
                                .frame(width: 18)
                                .accessibilityHidden(true)
                            Text(tab.title)
                                .font(.body.weight(selection == tab ? .semibold : .regular))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(selection == tab ? DietTheme.Palette.primaryText : DietTheme.Palette.ink)
                        .symbolRenderingMode(.monochrome)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(rowBackgroundColor(for: tab))
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            hoveredTab = tab
                        } else if hoveredTab == tab {
                            hoveredTab = nil
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hoveredTab)
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(DietTheme.Palette.primaryText)

            DietHairline()
            Button {
                selection = .profile
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selection == .profile ? AppTab.profile.selectedIcon : AppTab.profile.icon)
                        .font(.body)
                        .foregroundStyle(selection == .profile ? DietTheme.Palette.primaryText : DietTheme.Palette.inkSecondary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phaseSummary)
                            .font(.footnote.weight(selection == .profile ? .semibold : .medium))
                            .foregroundStyle(selection == .profile ? DietTheme.Palette.primaryText : DietTheme.Palette.ink)
                            .lineLimit(1)
                        if let weightSummary, !weightSummary.isEmpty {
                            Text(weightSummary)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(selection == .profile ? DietTheme.Palette.primarySoft : Color.clear)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(profileAccessibilityLabel)
            .accessibilityHint("打开我的与设置")
            .accessibilityAddTraits(selection == .profile ? .isSelected : [])
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func rowBackgroundColor(for tab: AppTab) -> Color {
        if selection == tab {
            return DietTheme.Palette.primarySoft
        }
        if hoveredTab == tab {
            return DietTheme.Palette.surfaceMuted.opacity(0.65)
        }
        return .clear
    }

    private var profileAccessibilityLabel: String {
        if let weightSummary, !weightSummary.isEmpty {
            return "我的，\(phaseSummary)，\(weightSummary)"
        }
        return "我的，\(phaseSummary)"
    }
}
#endif

extension AppTab {
    static var primarySidebarItems: [AppTab] { [.today, .diary, .trends, .analysis] }

    var title: String {
        switch self {
        case .today: "今天"
        case .diary: "日记"
        case .trends: "趋势"
        case .analysis: "AI 分析"
        case .profile: "我的"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .diary: "book.closed"
        case .trends: "chart.line.uptrend.xyaxis"
        case .analysis: "sparkles"
        case .profile: "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: "sun.max.fill"
        case .diary: "book.closed.fill"
        case .trends: "chart.line.uptrend.xyaxis"
        case .analysis: "sparkles"
        case .profile: "person.fill"
        }
    }
}
