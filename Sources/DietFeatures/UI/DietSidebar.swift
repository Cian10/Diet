import SwiftUI

#if os(macOS)
struct DietSidebar: View {
    @Binding var selection: AppTab

    private var optionalSelection: Binding<AppTab?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? selection }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DietSidebarHeader()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            List(selection: optionalSelection) {
                ForEach(AppTab.sidebarItems, id: \.self) { tab in
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.body)
                            .frame(width: 18)
                        Text(tab.title)
                            .font(.body.weight(selection == tab ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundStyle(selection == tab ? DietTheme.Palette.primaryText : DietTheme.Palette.ink)
                    .symbolRenderingMode(.monochrome)
                        .padding(.vertical, 4)
                        .tag(tab)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selection == tab ? DietTheme.Palette.primarySoft : Color.clear)
                                .padding(.horizontal, 5)
                        )
                        .accessibilityLabel(tab.title)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DietTheme.Palette.sidebar)
            .tint(DietTheme.Palette.primaryText)

            Divider()
                .overlay(DietTheme.Palette.border)
            Button {
                selection = .profile
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DietTheme.Palette.primaryText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("个人空间")
                            .font(.footnote.weight(.semibold))
                        Text("本地个人档案")
                            .font(.caption)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
                .foregroundStyle(DietTheme.Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selection == .profile ? DietTheme.Palette.primarySoft : Color.clear)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开我的与个人设置")
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .background(DietTheme.Palette.sidebar.ignoresSafeArea())
    }
}

private struct DietSidebarHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "leaf.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(DietTheme.Palette.onPrimary)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DietTheme.Palette.primary)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("健身饮食")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.ink)
                Text("TODAY · \(Date().formatted(.dateTime.month(.defaultDigits).day().locale(Locale(identifier: "zh_CN"))))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif

extension AppTab {
    static var sidebarItems: [AppTab] { [.today, .diary, .trends, .profile] }

    var title: String {
        switch self {
        case .today: "今天"
        case .diary: "日记"
        case .trends: "趋势"
        case .profile: "我的"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .diary: "book.closed"
        case .trends: "chart.line.uptrend.xyaxis"
        case .profile: "person"
        }
    }
}
