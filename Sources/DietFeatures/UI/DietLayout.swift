import SwiftUI

struct DietPageHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let actions: Actions

    init(title: String, subtitle: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                heading
                Spacer(minLength: 12)
                actions
            }
            VStack(alignment: .leading, spacing: 16) {
                heading
                actions
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var nonEmptySubtitle: String? {
        guard let subtitle else { return nil }
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : subtitle
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: nonEmptySubtitle == nil ? 0 : 5) {
            Text(title)
                .font(DietTheme.Typography.pageTitle)
                .foregroundStyle(DietTheme.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitleText = nonEmptySubtitle {
                Text(subtitleText)
                    .font(.body)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension DietPageHeader where Actions == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct DietPage<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DietTheme.Metrics.sectionSpacing) {
                content
            }
            .padding(.horizontal, DietTheme.Metrics.pagePadding)
            .padding(.top, 26)
            .padding(.bottom, 36)
            .frame(maxWidth: DietTheme.Metrics.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(DietTheme.Palette.paper.ignoresSafeArea())
    }
}

struct DietWorkbenchPage<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        DietTheme.Metrics.pagePadding
        #else
        DietTheme.Metrics.compactPagePadding
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DietTheme.Metrics.sectionSpacing) {
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 36)
            .frame(maxWidth: DietTheme.Metrics.workbenchMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DietTheme.Palette.paper.ignoresSafeArea())
    }
}

struct DietDateCapsule: View {
    let date: Date

    var body: some View {
        Label(date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(Locale(identifier: "zh_CN"))), systemImage: "calendar")
            .font(.footnote.weight(.medium))
            .foregroundStyle(DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background {
                Capsule()
                    .fill(DietTheme.Palette.surfaceMuted)
            }
            .accessibilityLabel("日期：\(DietFormat.day(date))")
    }
}
