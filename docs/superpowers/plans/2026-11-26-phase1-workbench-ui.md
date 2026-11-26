# Phase 1 执行文档：静谧营养工作台（Atelier Nutrition Desk）

> **定位**：面向多 Agent 分工执行的 Phase 1 实施蓝图。每个任务严格限定**只读文件范围**、**独占可写文件**、**冻结接口契约**与**验收命令**，接收任务的 Agent 无需全仓扫描，按卡片指引即可独立交付。
>
> **视觉方向**：石纸白 + 中性炭黑 + 深松针绿交互主色 + 蛋白/碳水/脂肪三色低饱和营养信号色 + 斜纹不确定态；去 60% 卡片框线，升级为原生 macOS Toolbar、毛玻璃侧栏与「今天」双栏营养工作台。

---

## 0. 全局红线（所有 Agent 必须遵守）

1. **禁止修改 `Sources/DietCore/`**：Phase 1 不改动领域模型、SwiftData Schema、营养算法、目标引擎、LLM 客户端或 Keychain 边界。
2. **禁止新增第三方依赖**：仅使用 macOS 14+ 原生 `SwiftUI`、`Charts`、`AppKit`（保留 `#if os(macOS)` / `#if os(iOS)` 条件编译兼容）。
3. **保留既有产品原则**：
   - 未知营养不得当作 `0`，热量进度条和提示必须明确标出“部分合计 / 含未知项”。
   - 热量超出目标不得自动标红惩罚，保持中性或提示语。
   - 不伪造身体数据或未确认记录，单日修改不改变阶段方案。
   - 所有正文与交互对比度满足 WCAG AA（普通文字 ≥ 4.5:1，大字号/图形 ≥ 3:1），尊重 `@Environment(\.accessibilityReduceMotion)` 与 Dynamic Type。
4. **向后兼容旧页面**：日记、趋势、AI 分析、首次设置在 Phase 1 不做页面重构，但会通过 `DietTheme.Palette` 自动继承新色板；因此 **`DietTheme.Palette` 原有静态属性名必须全部保留**，只更新色值并追加新令牌。

---

## 1. 任务依赖拓扑与文件所有权矩阵

```text
Wave 1 (串行打底)        Wave 2 (三路完全并行，零文件重叠)        Wave 3 (装配收口)
┌─────────────────┐      ┌─────────────────────────────┐      ┌─────────────────────┐
│ T1 DesignSystem │─────▶│ T2 Shell & Sidebar          │─────▶│                     │
│                 │      ├─────────────────────────────┤      │ T5 Today Assembly & │
│                 │─────▶│ T3 Today Dashboard & Focus  │─────▶│    Verification     │
│                 │      ├─────────────────────────────┤      │                     │
│                 │─────▶│ T4 Supporting & Quick Log   │─────▶│                     │
└─────────────────┘      └─────────────────────────────┘      └─────────────────────┘
```

| Task | 执行波次 | 独占可写文件（Write） | 仅需读取文件（Read-only） |
| --- | --- | --- | --- |
| **T1** | Wave 1 | `Sources/DietFeatures/UI/DietTheme.swift`<br>`Sources/DietFeatures/UI/DietButtons.swift`<br>`Sources/DietFeatures/UI/DietLayout.swift`<br>`Sources/DietFeatures/UI/DietComponents.swift` | 仅自身可写文件 |
| **T2** | Wave 2 | `Sources/DietFeatures/UI/DietSidebar.swift`<br>`Sources/DietFeatures/Nutrition/MainTabView.swift`<br>`App/DietApp.swift` | `Sources/DietFeatures/UI/DietTheme.swift`<br>`Sources/DietFeatures/Profile/ProfileRootViewModel.swift` |
| **T3** | Wave 2 | `Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift`<br>`Sources/DietFeatures/Nutrition/TodayDashboardComponents.swift` *(新建)*<br>`Tests/DietFeaturesTests/TodayFocusPresentationTests.swift` | `Sources/DietFeatures/UI/DietTheme.swift`<br>`Sources/DietFeatures/UI/DietComponents.swift`<br>`Sources/DietCore/Models/DailyTarget.swift`<br>`Sources/DietCore/Trends/TrendsService.swift` |
| **T4** | Wave 2 | `Sources/DietFeatures/Recommendations/RecommendationSectionView.swift`<br>`Sources/DietFeatures/Nutrition/TodayTargetEditView.swift`<br>`Sources/DietFeatures/Logging/TextLoggingView.swift` | `Sources/DietFeatures/UI/DietTheme.swift`<br>`Sources/DietFeatures/UI/DietComponents.swift`<br>`Sources/DietCore/Recommendations/RecommendationEngine.swift` |
| **T5** | Wave 3 | `Sources/DietFeatures/Nutrition/NutritionHomeView.swift`<br>`Tests/DietFeaturesTests/NutritionHomeViewModelTests.swift`<br>`Sources/DietFeatures/UI/DietComponents.swift` *(仅删除已无调用的旧组件)* | `Sources/DietFeatures/Nutrition/TodayDashboardComponents.swift`<br>`Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift`<br>`Sources/DietFeatures/Recommendations/RecommendationSectionView.swift`<br>`Sources/DietFeatures/Logging/TextLoggingView.swift`<br>`Sources/DietFeatures/UI/DietLayout.swift` |

---

## 2. 冻结接口契约（Wave 1 输出 / Wave 2-3 消费）

> 以下签名在跨 Agent 协作时视为冻结契约；除非明确协调，不要改名或删除参数。

### 2.1 `DietTheme` 令牌规范（T1 落地）

#### A. 既有令牌更新（保留全部属性名，替换色值）
| Token | Light Hex | Dark Hex | 用途 |
| --- | --- | --- | --- |
| `canvas` | `0xF1F1EC` | `0x101110` | 表单底色 / 最外层画布 |
| `paper` | `0xF6F6F3` | `0x131413` | 主内容石纸底（去淡绿偏色） |
| `sidebar` | `0xEFEFE9` | `0x181918` | 侧栏回退色（macOS 优先系统材质） |
| `surface` | `0xFFFFFF` | `0x1C1E1C` | 主仪表台、输入区、弹窗表面 |
| `surfaceMuted` | `0xECECE7` | `0x252825` | 轨道槽、分段底、悬停行底 |
| `ink` | `0x181A18` | `0xF2F2EE` | 主标题、核心数字、食物名 |
| `inkSecondary` | `0x5B605C` | `0xA2A8A3` | 次级正文与单位（对比度 > 5.5:1） |
| `inkTertiary` | `0x6E7470` | `0x868D88` | 仅 ≥ 11pt 辅助信息 |
| `border` | `0xE2E2DC` | `0x2D302D` | 描边与边框 |
| `primary` | `0x1F5E43` | `0x5CC192` | 主操作、进度达标、焦点强调 |
| `primaryDeep` | `0x174833` | `0x8ADBB3` | 悬停 / 强强调按钮 |
| `primaryText` | `0x1D573E` | `0x7AD4A8` | 浅底状态文字 / 文本按钮 |
| `onPrimary` | `0xFFFFFF` | `0x0D1F17` | 主按钮文字 |
| `onPrimaryDeep` | `0xFFFFFF` | `0x0F241B` | 深主按钮文字 |
| `primarySoft` | `0xE4EFE9` | `0x1E3329` | 轻强调胶囊底 |
| `primaryLine` | `0xC7DDD1` | `0x2E4B3D` | 轻强调描边 |
| `warning` | `0xB86B1A` | `0xF0B25F` | 估算 / 未知项强调 |
| `warningSoft` | `0xFBF1E3` | `0x362A1B` | 估算 / 未知项浅底 |
| `danger` | `0xB33A32` | `0xF08078` | 删除 / 失败 |
| `dangerSoft` | `0xFAE7E5` | `0x38201E` | 错误底色 |

#### B. 新增语义令牌（T1 追加）
```swift
// DietTheme.Palette 追加
static let hairline = Color.dietAdaptive(light: 0xE2E2DC, dark: 0x2D302D)
static let macroProtein = Color.dietAdaptive(light: 0x2A6F97, dark: 0x64B5E5)
static let macroProteinSoft = Color.dietAdaptive(light: 0xE6F0F6, dark: 0x1B2F3B)
static let macroCarbs = Color.dietAdaptive(light: 0xC47D2B, dark: 0xE5A952)
static let macroCarbsSoft = Color.dietAdaptive(light: 0xF8EFE3, dark: 0x352919)
static let macroFat = Color.dietAdaptive(light: 0x8A5A7E, dark: 0xC68FB8)
static let macroFatSoft = Color.dietAdaptive(light: 0xF2EBF0, dark: 0x31232E)

// DietTheme.Typography 追加
static let heroMetric = Font.system(size: 36, weight: .bold, design: .rounded)
static let subMetric = Font.system(size: 18, weight: .semibold, design: .rounded)
static let groupEyebrow = Font.caption.weight(.semibold)

// DietTheme.Metrics 追加
static let workbenchMaxWidth: CGFloat = 1220
static let railMinWidth: CGFloat = 290
static let railMaxWidth: CGFloat = 350
static let twoColumnBreakpoint: CGFloat = 840
```

### 2.2 新增基础原语签名（T1 在 `DietComponents.swift` / `DietLayout.swift` 提供）

```swift
// 1) 发丝分割线（0.5pt，避免四处套外框）
struct DietHairline: View

// 2) 无边框分组眉题（左侧 12pt Semibold 次级标题 + 右侧可选辅助信息/动作 + 下方细分割线）
struct DietGroupHeader<Trailing: View>: View {
    init(_ title: String, @ViewBuilder trailing: () -> Trailing)
}
extension DietGroupHeader where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil)
}

// 3) 抬升主视觉台（全页仅主舞台使用，更克制的圆角与阴影）
struct DietHeroSurface<Content: View>: View {
    init(padding: CGFloat = 22, @ViewBuilder content: () -> Content)
}

// 4) 带斜纹不确定段的横向进度条（支持三大宏量或热量主进度）
struct DietFuelBar: View {
    let progress: Double            // 0...1+（内部 clamp 展示，不自动标红）
    let tint: Color
    var height: CGFloat = 8
    var hasUncertainTail: Bool = false // true 时在已填段末尾渲染琥珀斜纹不确定区
}

// 5) 紧凑页面头（允许 subtitle 为 nil，避免强塞说教副标题）
// DietPageHeader 增加可选 subtitle: String? = nil 初始化器，同时保留原有 (title:subtitle:actions:) 兼容
```

### 2.3 `TextLoggingView` 扩展签名（T4 提供，T5 消费）

```swift
// Sources/DietFeatures/Logging/TextLoggingView.swift
public init(
    service: FoodLoggingService,
    initialText: String = "",
    initialMealType: MealType? = nil,   // nil 时按当前小时推断（05-10早/11-14午/17-21晚/其余加餐）
    initialDate: Date = Date(),
    autoAnalyzeOnAppear: Bool = false,  // true 且 initialText 非空时打开后自动发起一次分析
    onSwitchToPhoto: @escaping () -> Void = {},
    onConfirmed: @escaping () -> Void = {}
)
```
> 保留向后兼容：现有 `TextLoggingView(service:onSwitchToPhoto:onConfirmed:)` 调用无需任何改动即可编译。

### 2.4 `TodayFocusPresentation` 扩展签名（T3 提供，T5 消费）

```swift
// Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift
struct TodayFocusPresentation: Equatable {
    enum Kind: Equatable {
        case reviewMeal
        case startLogging
        case recordMeal(MealType) // 替代僵硬的单一 recordDinner，按当前时段推荐早/午/晚
        case completed
        case maintain
    }

    init(
        hasTarget: Bool,
        hasPendingOrFailedMeal: Bool,
        recordedMealTypes: Set<MealType>,
        hour: Int,
        isGoalMet: Bool
    )
    // 同时提供便捷兼容方法或同步更新 TodayFocusPresentationTests.swift
}
```

### 2.5 `TodayDashboardComponents.swift` 导出签名（T3 新建，T5 消费）

```swift
// 1) 主营养仪表台（左栏顶部唯一抬升卡片）
struct TodayMacroDashboardCard: View {
    let target: TargetResolution?
    let intake: NutritionTotals
    let assessment: NutritionAssessment?
    let onEditTarget: () -> Void
    let onTapIncomplete: () -> Void
}

// 2) 今日餐食时间轴 + 行内快速输入槽（左栏下方无外框列表）
struct TodayMealTimelineSection<RowDestination: View>: View {
    let entries: [MealEntry]
    let suggestedMealType: MealType
    @Binding var quickInputText: String
    let onQuickAnalyze: (String, MealType) -> Void
    let onOpenPhoto: () -> Void
    let onOpenManual: (MealType) -> Void
    @ViewBuilder let destination: (MealEntry) -> RowDestination
}

// 3) 右侧 7 日节奏与体重微缩卡（右栏底部无重边框轻面板）
struct TodayWeeklyRhythmPanel: View {
    let days: [DailyTrend]
    let eligibleDays: Int
    let metDays: Int?
    let latestWeight: WeightRecord?
    let weightDeltaText: String?
    let onJumpToTrends: (() -> Void)?
}
```

---

## 3. 分工任务卡片（直接派发给各 Agent）

---

### Task 1 (`T1-DesignSystem`) — 设计系统令牌与无框基础原语

- **波次**：Wave 1（前置任务，完成后解锁 T2/T3/T4）
- **独占可写文件**：
  - `Sources/DietFeatures/UI/DietTheme.swift`
  - `Sources/DietFeatures/UI/DietButtons.swift`
  - `Sources/DietFeatures/UI/DietLayout.swift`
  - `Sources/DietFeatures/UI/DietComponents.swift`
- **禁止修改**：`Sources/DietCore/`、`DietSidebar.swift` 及所有业务 Feature 视图。
- **实施清单**：
  1. **`DietTheme.swift`**：按 §2.1 完整更新 `Palette` Light/Dark 十六进制值，追加 `hairline`、`macroProtein`/`macroCarbs`/`macroFat` 及其 `*Soft` 令牌；追加 `Typography.heroMetric`、`subMetric`、`groupEyebrow`；追加 `Metrics.workbenchMaxWidth`、`railMinWidth`、`railMaxWidth`、`twoColumnBreakpoint`。
  2. **`DietButtons.swift`**：收紧按钮高度与圆角（`controlHeight = 32`、`controlRadius = 8`），为 `DietSecondaryButtonStyle` 与 `DietTextButtonStyle` 补上 hover 状态反馈（macOS 指针悬停微变底色，不位移），保持无障碍焦点环。
  3. **`DietLayout.swift`**：
     - 扩展 `DietPageHeader` 支持 `subtitle: String? = nil`（无副标题时不占多余垂直空隙）；
     - 保留 `DietPage` 兼容旧页面，同时新增 `DietWorkbenchPage`（支持 `maxWidth: DietTheme.Metrics.workbenchMaxWidth`、更紧凑顶部留白 `top: 18` 以配合原生 macOS Toolbar）。
  4. **`DietComponents.swift`**：
     - 弱化 `DietCard` 阴影（由 `0.035/radius 5` 降为 `0.02/radius 2`，圆角调为 `12pt`），让尚未改造的页面瞬间更利落；
     - 按 §2.2 新增 `DietHairline`、`DietGroupHeader`、`DietHeroSurface`、`DietFuelBar`（含 `Canvas` 绘制的 `45°` 琥珀斜纹不确定段，支持 Reduce Motion）；
     - **优化 `DietMealRow`**：增加 `showsMealIcon: Bool = true` 与 `showsMealTypeInSubtitle: Bool = true` 默认参数（向后兼容），新增蛋白克数简洁显示（如 `480 kcal · 蛋白 24g`），把状态标记收敛为更克制的圆点+文字或小胶囊；
     - **暂保留 `DietFocusCard` 和 `DietMetricCard`**（等待 T5 切换 `NutritionHomeView` 后删除，防止 Wave 1/2 期间编译中断）。
- **验证命令**：
  ```bash
  ./Scripts/test.sh
  ```
- **完成定义**：所有既有测试 100% 编译通过；§2.1 与 §2.2 全部符号可用；无硬编码 `.green`/`.orange` 散落。

---

### Task 2 (`T2-ShellSidebar`) — macOS 原生外壳、侧栏重塑与快捷键

- **波次**：Wave 2（与 T3、T4 并行）
- **独占可写文件**：
  - `Sources/DietFeatures/UI/DietSidebar.swift`
  - `Sources/DietFeatures/Nutrition/MainTabView.swift`
  - `App/DietApp.swift`
- **只读参考**：
  - `Sources/DietFeatures/UI/DietTheme.swift`
  - `Sources/DietFeatures/Profile/ProfileRootViewModel.swift`
- **禁止修改**：`NutritionHomeView.swift`、`DietComponents.swift`、`Sources/DietCore/`。
- **实施清单**：
  1. **`DietSidebar.swift`**：
     - **移除模板化 `DietSidebarHeader`**（删掉绿色圆角方块绿叶图标与 `TODAY · MM/dd` 全大写英文标签）；
     - 侧栏主导航列表 `AppTab.primarySidebarItems` 仅保留 4 项：`[.today, .diary, .trends, .analysis]`，去除列表中的 `.profile` 重复项；
     - 在 macOS 上保留 `NavigationSplitView` 原生 `.listStyle(.sidebar)` 材质，去掉强制铺满的纯色 `.background(DietTheme.Palette.sidebar)`（改用原生系统侧栏材质 + 选中态细微 `primarySoft` 胶囊 + `primaryText` 文字/图标，选中项使用填充态 SF Symbol 如 `sun.max.fill`）；
     - 侧栏底部保留**唯一**档案状态入口（接收 `phaseSummary: String` 与 `weightSummary: String?`，如 `维持 · v1` / `68.0 kg`），点击选中 `.profile`，视觉与主列表区分（细发丝顶分割线 + 紧凑单行/双行状态条，不再使用“个人空间 / 本地个人档案”模板文案）。
  2. **`MainTabView.swift`**：
     - 透传 `profileViewModel` 的当前阶段名与最新体重给 `DietSidebar`；
     - 在 `MainTabView` 为 macOS 增加键盘导航快捷方式（如 `.background` 隐藏按钮或菜单命令支持 `⌘1` 今天、`⌘2` 日记、`⌘3` 趋势、`⌘4` AI 分析、`⌘5` 我的）；
     - 顺手清理 `SettingsHubView`（[MainTabView.swift](file:///Users/yuzhao/Documents/ChatGPT/饮食APP/Sources/DietFeatures/Nutrition/MainTabView.swift#L132-L299)）内最明显的重复项：
       - 移除页面说教副标题或缩短为可选；
       - `targetSummary` 直接读取今日已保存的 `DailyTarget`（需传入 `targetStore` 或从已有参数读，若不想改 `SettingsHubView` public `init` 签名，可增加可选 `targetStore: DailyTargetStoring? = nil` 默认参数）；
       - 区分不可点击的“隐私与数据”与可点击卡片样式（改为页面底部一行轻量文字说明，从 2 列卡片网格中移除，避免用户误点）。
  3. **`App/DietApp.swift`**：
     - 保持 `minWidth: 960, minHeight: 640` 和 `defaultSize(width: 1120, height: 760)`；
     - 为 macOS 添加 `.windowToolbarStyle(.unified)`（若适配 macOS 14 无告警），使内容区 Toolbar 与标题栏融为一体。
- **验证命令**：
  ```bash
  ./Scripts/test.sh
  ```
- **完成定义**：侧栏无绿叶方块头、无“我的/个人空间”双入口重复；`MainTabView` 和 `SettingsHubView` 原有公开构造签名向后兼容；所有单测通过。

---

### Task 3 (`T3-TodayComponents`) — 时段感知焦点逻辑 + 今天页核心子组件

- **波次**：Wave 2（与 T2、T4 并行）
- **独占可写文件**：
  - `Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift`
  - `Sources/DietFeatures/Nutrition/TodayDashboardComponents.swift` *(新建)*
  - `Tests/DietFeaturesTests/TodayFocusPresentationTests.swift`
- **只读参考**：
  - `Sources/DietFeatures/UI/DietTheme.swift`
  - `Sources/DietFeatures/UI/DietComponents.swift`
  - `Sources/DietCore/Models/DailyTarget.swift`
  - `Sources/DietCore/Trends/TrendsService.swift`
- **禁止修改**：`NutritionHomeView.swift`、`Sources/DietCore/`。
- **实施清单**：
  1. **`TodayFocusPresentation.swift` + `TodayFocusPresentationTests.swift`**：
     - 改造为按时段感知（`hour: Int` + `recordedMealTypes: Set<MealType>`）：
       - 优先级 1：`hasPendingOrFailedMeal` → `.reviewMeal`（需注意，标题“完成待确认餐食”）
       - 优先级 2：`!hasTarget` → `.startLogging`
       - 优先级 3：时段餐次推断——`5..<11` 且未记 `.breakfast` → `.recordMeal(.breakfast)`；`11..<16` 且未记 `.lunch` → `.recordMeal(.lunch)`；`16..<23` 且未记 `.dinner` → `.recordMeal(.dinner)`
       - 优先级 4：`isGoalMet` → `.completed`
       - 兜底：`.maintain`
     - 同步提供静态 helper `TodayFocusPresentation.suggestedMealType(for hour: Int, recorded: Set<MealType>) -> MealType`，供行内快速输入槽默认选餐别。
     - 更新并扩充 `TodayFocusPresentationTests.swift`（覆盖早上 8 点建议早餐、中午 12 点建议午餐、晚上 19 点建议晚餐、待确认优先、无目标不报完成）。
  2. **新建 `TodayDashboardComponents.swift`**（严格匹配 §2.5 签名）：
     - **`TodayMacroDashboardCard`**：
       - 使用 `DietHeroSurface` 作为全页唯一抬升卡片；
       - 顶行：左侧“剩余可摄入”（或超出时显示中性文案“已超出目标”，不标红）+ `DietTheme.Typography.heroMetric` 大号数字（如 `1,070 kcal`）+ 旁注“已摄入 1,130 / 目标 2,200 kcal”；右侧放状态小胶囊（“单日修改”或“已生效”）与轻量 `修改` 按钮（调用 `onEditTarget`）；无目标时清晰展示“已摄入 X kcal · 尚未设置今日目标”。
       - 中部：`DietFuelBar` 主热量进度条（`height: 10`，`tint: DietTheme.Palette.primary`，`hasUncertainTail: !intake.isComplete`）。
       - 当 `!intake.isComplete` 时，在主条下方显示一条**紧凑可点击提醒行**（琥珀小图标 + “部分合计：坚果（份量未知），未按 0 处理” + `去补全` 按钮调用 `onTapIncomplete`），替代原先占据大量垂直空间的独立大黄框。
       - 底部：3 列等分横向宏量进度区（使用 `macroProtein`、`macroCarbs`、`macroFat` 三色 `DietFuelBar(height: 5)`），每项展示 `蛋白质 74 / 130 g` 及 `剩 56 g`（全部 `.monospacedDigit()`）；如有估算实际热量缺口（`assessment?.actualCalorieDeficit`），仅以一行极简脚注放于卡片最底角，不再另开一张 `目标参考` 卡。
     - **`TodayMealTimelineSection`**：
       - 无外框设计，顶部用 `DietGroupHeader("今日餐食", detail: "\(entries.count) 条记录")`；
       - 按时间正序展示今日已记录餐食（点击通过 `destination(entry)` 进入 `MealDetailView`），行间使用 `DietHairline`，使用精简时间前缀（`08:20` 等宽）+ 餐别/食物名 + 右对齐热量与蛋白克数 + 状态点，不再每行套白框或重复图标；
       - 列表底部内置**行内快速记一餐槽位**（轻底色 `surface` + `1pt hairline` 边框）：左侧显示可切换的餐别小菜单（默认 `suggestedMealType`），中间单行/双行 `TextField`（placeholder 如“记下晚餐，按 ⌘↩ 分析…”），右侧图标按钮（图片识别）与主小按钮（分析，支持回车/`⌘↩` 提交调用 `onQuickAnalyze`），下方极简文字入口“手动记录”。
     - **`TodayWeeklyRhythmPanel`**：
       - 用于右侧辅助栏，无厚重边框（轻底或 `DietGroupHeader("近 7 日节奏")` + 简洁内容）；
       - 展示 7 根等宽迷你胶囊柱（高度按热量占比，今天高亮 `primary`，含未知项的柱子用 `warning` 虚线描边/斜纹，带“日一二三四五六”极简底标）+ 下方紧凑 2 列摘要（`记录 6/7 天`、`达标 0/5 天`）；
       - 底部展示最新体重（如 `68.0 kg` + `weightDeltaText`），若无记录则显示“暂无体重记录”。
- **验证命令**：
  ```bash
  ./Scripts/test.sh
  ```
- **完成定义**：`TodayFocusPresentationTests` 全绿；`TodayDashboardComponents.swift` 在 macOS/iOS 均无编译警告，包含完整无障碍标签（VoiceOver 可读出热量、三大宏量和 7 日摘要）。

---

### Task 4 (`T4-TodaySupporting`) — 推荐面板轻量化 + 快速录入参数承接

- **波次**：Wave 2（与 T2、T3 并行）
- **独占可写文件**：
  - `Sources/DietFeatures/Recommendations/RecommendationSectionView.swift`
  - `Sources/DietFeatures/Nutrition/TodayTargetEditView.swift`
  - `Sources/DietFeatures/Logging/TextLoggingView.swift`
- **只读参考**：
  - `Sources/DietFeatures/UI/DietTheme.swift`
  - `Sources/DietFeatures/UI/DietComponents.swift`
  - `Sources/DietCore/Recommendations/RecommendationEngine.swift`
- **禁止修改**：`NutritionHomeView.swift`、`DiaryView.swift`、`Sources/DietCore/`。
- **实施清单**：
  1. **`RecommendationSectionView.swift`**：
     - 从原先占满整页宽度的重边框 `DietCard` 改造为适合右侧工作台辅栏（宽 `290–350pt`）的轻盈面板：
     - 顶部使用 `DietGroupHeader("今日情境")` + 紧凑“接下来有训练”芯片开关（`Toggle` `.controlSize(.mini)` 或可切换胶囊按钮）；
     - 建议条目去掉嵌套多层圆角灰框，改为紧凑列表行（食物名 + 份量 + 右对齐 `kcal / P` 等宽读数）+ 右上角轻巧“忽略”；
     - 空态与底部参考值提示收紧为单行小字（`caption`），不占大块垂直高度。
  2. **`TodayTargetEditView.swift`**：
     - 适配新 `DietTheme.Palette`（确保深浅色下表单背景、分隔线、错误条清晰可辨），在热量输入框下方加一行实时宏量估算参考提示（`按当前蛋白/碳水/脂肪折算约 X kcal`，纯展示不强制改写用户手动值）。
  3. **`TextLoggingView.swift`**：
     - 按 §2.3 为 `TextLoggingView` 和 `TextLoggingViewModel` 增加向后兼容的可选参数：`initialText`、`initialMealType`（为 `nil` 时按 `initialDate` 小时段自动推断默认餐别，取代永远默认 `.other`）、`initialDate`、`autoAnalyzeOnAppear`；
     - 当 `autoAnalyzeOnAppear == true` 且 `initialText` 非空时，在 `.task` 中自动触发一次 `viewModel.analyze()`（防重复触发，分析成功自动跳入 `MealConfirmationView`，失败保留原文和错误提示）；
     - 保留所有原有调用方式零改动兼容（`DiaryView` 等仍正常编译运行）。
- **验证命令**：
  ```bash
  ./Scripts/test.sh
  ```
- **完成定义**：所有既有测试通过；`TextLoggingView` 新旧初始化器均工作正常；`RecommendationSectionView` 在 `290pt` 窄栏与宽栏下均不截断不溢出。

---

### Task 5 (`T5-TodayAssembly`) — 装配「今天」双栏工作台、清理死代码与总验收

- **波次**：Wave 3（等待 T2、T3、T4 全部合并后执行）
- **独占可写文件**：
  - `Sources/DietFeatures/Nutrition/NutritionHomeView.swift`
  - `Tests/DietFeaturesTests/NutritionHomeViewModelTests.swift`
  - `Sources/DietFeatures/UI/DietComponents.swift` *(仅清理无引用的 `DietFocusCard` 与 `DietMetricCard`)*
- **只读参考**：
  - `Sources/DietFeatures/Nutrition/TodayDashboardComponents.swift`
  - `Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift`
  - `Sources/DietFeatures/Recommendations/RecommendationSectionView.swift`
  - `Sources/DietFeatures/Logging/TextLoggingView.swift`
  - `Sources/DietFeatures/UI/DietLayout.swift`
- **实施清单**：
  1. **`NutritionHomeViewModel` 最小增量数据暴露**：
     - 新增 `@Published public private(set) var weeklyDays: [DailyTrend] = []`
     - 新增 `@Published public private(set) var latestWeight: WeightRecord?`
     - 新增 `@Published public private(set) var weightDeltaText: String?`
     - 在现有 `refreshHomeData()` 中复用已调用的 `trendsService.weeklyReview()` 结果填充上述字段（避免额外查表；不改 `DietCore`）。
  2. **`NutritionHomeView` 双栏工作台装配**：
     - **移除 4 重重复旧模块**：删除 `DietFocusCard`、`todayTargetCard`、3×`DietMetricCard`、`目标参考` 卡与滚动区内的说教 `DietPageHeader`；
     - **接入原生 macOS Toolbar**：在 `.toolbar` 中放置日期显示（如 `11月21日 周六`）与 `+ 记一餐` 菜单（绑定 `.keyboardShortcut("n", modifiers: .command)`）；
     - **双栏响应式布局**（用 `GeometryReader` / `ViewThatFits` 判断 `width >= DietTheme.Metrics.twoColumnBreakpoint`）：
       - **宽屏（≥ 840pt）**：`HStack(alignment: .top, spacing: 24)`
         - 左主栏（`.frame(maxWidth: .infinity)`）：`errorMessage`（如有）→ `TodayMacroDashboardCard` → `TodayMealTimelineSection`
         - 右辅助栏（`.frame(minWidth: 290, idealWidth: 320, maxWidth: 340)`）：仅当 `focus.needsAttention`（有待确认/失败餐食）时在顶部渲染紧凑琥珀行动条（点击直达 `focusedEntry`）→ `RecommendationSectionView` → `TodayWeeklyRhythmPanel`
       - **窄屏（< 840pt）**：自动折叠为单列垂直顺序（主仪表台 → 待处理提示 → 今日餐食时间轴 → 今日情境建议 → 近 7 日节奏）。
     - **串联行内快速录入**：用户在 `TodayMealTimelineSection` 输入一句话按 `⌘↩` 时，携带 `initialText`、`initialMealType` 和 `autoAnalyzeOnAppear: true` 打开 `TextLoggingView` Sheet 直接进入分析与确认流；确认保存后清空 `quickInputText` 并 `reload()`。
     - **点击主仪表台“去补全”**：若存在未知营养的当日餐食，直接跳转该餐的 `MealConfirmationView` 或滚动定位至该餐。
  3. **清理死代码**：
     - 先用 grep 确认全仓已无 `DietFocusCard` 与 `DietMetricCard` 引用，再从 `Sources/DietFeatures/UI/DietComponents.swift` 删除这两个废弃组件。
  4. **单测补齐**：
     - 在 `Tests/DietFeaturesTests/NutritionHomeViewModelTests.swift` 补充测试：验证 `weeklyDays` 长度为 7、`latestWeight` 与 `weightDeltaText` 在有/无体重记录时的正确性。
  5. **工程文件同步与全量验证**：
     - 因 T3 新建了 `TodayDashboardComponents.swift`，执行 `./Scripts/generate-project.sh` 刷新 `DietApp.xcodeproj`（若本机装有 `xcodegen`；否则确认源码引用已纳入 Xcode 工程）。

---

## 4. 总验收清单（T5 完成后执行）

### 自动化测试与构建
```bash
# 1. SwiftPM 默认测试（内存仓库 + SwiftUI 编译）
./Scripts/test.sh

# 2. SwiftData 宏与持久化测试
./Scripts/test.sh --swiftdata

# 3. macOS Debug 完整构建
xcodebuild -project DietApp.xcodeproj \
  -scheme DietApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  build
```

### 视觉与交互人工核对点
- [ ] **去模板化达标**：打开「今天」页，全页仅主营养仪表台为抬升白卡，餐食时间轴与右侧面板无多余边框套娃，无说教副标题，无侧栏绿叶方块与重复“个人空间”。
- [ ] **三档窗口尺寸**：`960 × 640`、`1100 × 760`、`1280 × 800` 下双栏/单列切换自然，无横向溢出、文字截断或按钮挤压。
- [ ] **深浅色双检**：浅色石纸白与深色石墨黑下，主数字、蛋白/碳水/脂肪三色条、斜纹不确定区、分割线均清晰可读（≥ AA 对比度）。
- [ ] **核心流不断裂**：Toolbar `+ 记一餐 (⌘N)`、行内快速输入按 `⌘↩` 分析、手动记录、单日目标修改、点击待确认餐食继续确认、查看并删除餐食全部跑通且刷新首页数据。
- [ ] **可访问性与动效**：开启 Reduce Motion 时无位移缩放；VoiceOver 可朗读剩余热量、三大宏量剩余克数、未知项名称与 7 日节奏摘要。
