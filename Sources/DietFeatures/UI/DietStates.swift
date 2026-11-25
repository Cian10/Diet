import SwiftUI

enum DietNoticeKind {
    case info
    case warning
    case error

    var foreground: Color {
        switch self {
        case .info: DietTheme.Palette.primaryText
        case .warning: DietTheme.Palette.warning
        case .error: DietTheme.Palette.danger
        }
    }

    var background: Color {
        switch self {
        case .info: DietTheme.Palette.primarySoft
        case .warning: DietTheme.Palette.warningSoft
        case .error: DietTheme.Palette.dangerSoft
        }
    }

    var icon: String {
        switch self {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

struct DietInlineNotice: View {
    let kind: DietNoticeKind
    let title: String?
    let message: String

    init(_ kind: DietNoticeKind, title: String? = nil, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.icon)
                .font(.body)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title).font(.footnote.weight(.semibold))
                }
                Text(message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(kind.foreground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(kind.background)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DietEmptyState<Actions: View>: View {
    let title: String
    let message: String
    let systemImage: String
    @ViewBuilder let actions: Actions

    init(
        title: String,
        message: String,
        systemImage: String = "fork.knife",
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DietTheme.Palette.primaryText)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(DietTheme.Palette.ink)
            Text(message)
                .font(.footnote)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .multilineTextAlignment(.center)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
}

extension DietEmptyState where Actions == EmptyView {
    init(title: String, message: String, systemImage: String = "fork.knife") {
        self.init(title: title, message: message, systemImage: systemImage) { EmptyView() }
    }
}

struct DietLoadingLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}
