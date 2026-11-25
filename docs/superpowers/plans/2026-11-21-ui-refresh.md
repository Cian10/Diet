# 健身饮食 macOS App UI 美化实施计划

日期：2026-11-21  
设计依据：[UI 设计方案](../specs/2026-11-21-diet-app-ui-design.md)

## 目标

在不改变业务模型、营养计算、目标引擎、记录仓库、LLM 请求和隐私边界的前提下，把现有 SwiftUI 界面统一为“轻量专注”视觉系统：

- 品牌化 macOS 侧栏。
- “今天”单一重点卡 + 三项指标 + 最近记录。
- 日记按日期与餐次组织。
- 趋势先展示七日事实，再展示复盘建议。
- 档案、首次设置、文本/图片记录与确认页使用相同设计语言。
- 浅色/深色、窗口缩放、键盘和 VoiceOver 路径可理解、可操作。

## 执行约束

- 不修改 `DietCore` 的业务模型、计算规则、持久化 schema、LLM 客户端和 Keychain 边界。
- 不新增 30 天趋势、备注编辑、云同步、导出、提醒或其它业务功能。
- 不把 `.green`、`.orange`、`.red` 和硬编码颜色散落到页面；统一通过 `DietTheme`。
- 不替换系统窗口交通灯、菜单和原生键盘导航。
- 不为了视觉重构删除现有的错误、估算、未知项和待确认提示。
- 每次只暂存本阶段明确列出的文件，禁止 `git add .`。
- 未完成真实 UI 人工验收前，不在文档中宣称“UI 美化已完成”。

## 仓库现状风险

当前 `main` 只有设计文档基线，现有 macOS 源码迁移、工程文件和部分设计文档仍处于未跟踪或有未提交修改的状态。执行 UI 计划前必须处理这一点：

1. 若用户同意，先审查并建立一个“当前 macOS App 基线”提交，只包含现有源码、工程、脚本和已确认文档；不混入 `.superpowers/`、DerivedData、构建产物或用户个人数据。
2. 若用户不希望对现状建基线，则后续阶段不得单独提交 UI 文件；改为保留所有改动并以精确文件列表和测试结果交付，避免把无关工作混进 UI 提交。
3. 任何情况下都不提交 `.superpowers/brainstorm/`、`.build*/`、`DerivedData/` 或个人健康数据。

---

## 阶段 0：基线验证与保护

### 目标

确认当前代码可测试、可构建，并记录视觉改造前的行为边界。

### 文件

- 只读检查：`Sources/`、`Tests/`、`Scripts/`、`project.yml`、`Package.swift`
- 本阶段不修改业务源码。

### 步骤

1. 运行默认测试：

   ```bash
   ./Scripts/test.sh
   ```

2. 运行 SwiftData 模式测试：

   ```bash
   ./Scripts/test.sh --swiftdata
   ```

3. 校验工程与脚本静态配置：

   ```bash
   plutil -lint App/Info.plist
   zsh -n Scripts/generate-project.sh Scripts/test.sh
   ```

4. 完整构建：

   ```bash
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

5. 记录基线：默认测试 61 项、SwiftData 测试 63 项、完整构建是否通过；若数字变化，以实际输出为准并写明。

### 通过条件

- 测试和构建均通过，或记录已存在的失败且确认与 UI 改造无关。
- 工作区状态已记录，后续不误提交无关文件。

### 提交

不创建 UI 提交。若用户批准建立现状基线，提交信息建议：

```text
chore: establish current macOS app baseline
```

---

## 阶段 1：建立主题和通用组件

### 目标

先建立单一视觉来源，后续页面只组合组件，不重复定义颜色和间距。

### 新增文件

- `Sources/DietFeatures/UI/DietTheme.swift`
- `Sources/DietFeatures/UI/DietButtons.swift`
- `Sources/DietFeatures/UI/DietComponents.swift`
- `Sources/DietFeatures/UI/DietStates.swift`

### `DietTheme.swift`

实现以下内部语义层：

```text
DietTheme
├── Palette
│   ├── canvas / paper / sidebar / surface / surfaceMuted
│   ├── ink / inkSecondary / inkTertiary / border
│   ├── primary / primaryDeep / primaryText / onPrimary / onPrimaryDeep
│   ├── primarySoft / primaryLine
│   └── warning / warningSoft / danger / dangerSoft
├── Metrics
│   ├── pagePadding
│   ├── sectionSpacing
│   ├── cardPadding
│   ├── controlHeight
│   └── cardRadius / controlRadius / sheetRadius
└── Typography
```

实现要求：

- macOS 使用 `NSColor(name: nil, dynamicProvider:)` 生成浅色/深色自适应 `Color`，遵循 `NSAppearance`。
- 保留 iOS 条件编译 fallback，至少保证源码可编译；当前交付只验收 macOS。
- 字体优先使用系统语义样式：`.largeTitle`、`.title2`、`.headline`、`.body`、`.footnote`；数据数字用 `.monospacedDigit()`。
- 不新增资源目录、第三方字体或依赖。
- 主题类型对 `DietFeatures` 内部可见；需要跨模块公开的既有视图 API 保持 `public`。

### `DietButtons.swift`

实现：

- `DietPrimaryButtonStyle`：`primary` 实心、`onPrimary` 前景、9 pt 圆角、32–36 pt 高、按下反馈不超过 2%。
- `DietSecondaryButtonStyle`：`surface` 底、`border` 描边。
- `DietTextButtonStyle`：无底色，仅用于次要动作。
- 危险动作继续使用系统 `role: .destructive` 和 `danger` 色，不制作独立大按钮样式。

### `DietComponents.swift`

实现可组合组件：

- `DietPageHeader`：标题、副标题、右侧任意内容。
- `DietCard<Content>`：统一 `surface`、`border`、14 pt 圆角、16–20 pt 内边距。
- `DietFocusCard`：标题、说明、主操作、完成率；允许待确认/估算颜色变体。
- `DietMetric` / `DietMetricRow`：数值、单位、标签。
- `DietSectionHeader`：区块标题与可选辅助文本。
- `DietMealRow`：餐别图标、标题、时间/营养摘要、状态。
- `DietStatusBadge`：已确认、待确认、估算、失败四种语义。
- 组件使用 `@ViewBuilder` 接收内容，避免把所有页面逻辑塞入共享组件。

### `DietStates.swift`

实现：

- `DietInlineNotice`：`.info`、`.warning`、`.error` 三种。
- `DietEmptyState`：说明 + 可选主操作。
- `DietLoadingLabel`：按钮内加载态，不改变调用方 ViewModel。

### 验证

1. 编译 `DietFeatures`：

   ```bash
   swift build --target DietFeatures
   ```

2. 运行完整测试：

   ```bash
   ./Scripts/test.sh
   ```

3. 静态检查不得出现未封装的页面级 `.green` / `.orange` / `.red`；新组件内部通过主题令牌使用颜色。

### 提交

```text
feat(ui): add shared visual theme and components
```

只暂存 `Sources/DietFeatures/UI/`。

---

## 阶段 2：品牌化 macOS 侧栏

### 目标

保留现有四项导航与 `NavigationSplitView`，完成 S2 外壳。

### 文件

- `Sources/DietFeatures/Nutrition/MainTabView.swift`
- 必要时新增：`Sources/DietFeatures/UI/DietSidebar.swift`

### 实施

1. 将侧栏内容组织为：
   - `DietSidebarHeader`：32 pt 品牌图标、产品名、`TODAY`/日期说明。
   - 四项 `List` 导航：今天、日记、趋势、我的，保留 `AppTab` 和 `selection` 绑定。
   - 底部个人入口：头像、个人空间、设置图标；点击 `profile` 切换到“我的”。
2. 侧栏宽度改为 `min: 200, ideal: 218, max: 240`。
3. 当前项使用 `primarySoft` 背景、`primaryText` 文字；不要移除 `List` 的原生键盘导航。
4. `NavigationSplitView` 外层保持系统窗口行为，不自定义交通灯，不设置全局深色侧栏。
5. `destination(for:)` 和所有业务依赖注入保持不变。
6. iOS `TabView` 分支保留条件编译，不在本次重构中删除。

### 验证

- `swift build --target DietFeatures`。
- 启动 App，确认侧栏四项可点击、可键盘切换，选中态切换正确。
- 1100 × 760 与 960 × 640 下品牌头、四项导航、底部个人入口不重叠。

### 提交

```text
feat(ui): restyle macOS sidebar shell
```

只暂存 `MainTabView.swift` 和新增侧栏组件。

---

## 阶段 3：“今天”页改造

### 目标

把现有多 Section 的 `List` 改为“单一重点卡 + 三项指标 + 最近记录”，同时保留所有今日数据的业务行为和待确认状态。

### 文件

- `Sources/DietFeatures/Nutrition/NutritionHomeView.swift`
- 新增：`Sources/DietFeatures/Nutrition/TodayFocusPresentation.swift`
- 新增测试：`Tests/DietFeaturesTests/TodayFocusPresentationTests.swift`
- 需要时微调：`Sources/DietFeatures/UI/DietComponents.swift`

### 展示逻辑

新增纯展示模型 `TodayFocusPresentation`，输入只来自现有状态：

- `target` 是否待确认。
- 当前记录中是否存在 `.draft` 或 `.failed`。
- 今日是否已经有晚餐记录。
- 今日是否已完成目标或缺口较小。

输出优先级：

1. 目标待确认：展示“确认今日目标”和确认按钮。
2. 存在待确认/失败记录：展示“完成这一餐的确认”。
3. 有目标且晚餐未记录：展示“记录晚餐”。
4. 已完成或缺口较小：展示“查看今日记录/保持当前节奏”。

该模型只决定视觉重点，不修改任何保存、目标确认或营养计算规则。

### 页面结构

1. `NavigationStack` 内使用 `ScrollView` + `LazyVStack`，最大内容宽度约 1180 pt。
2. `DietPageHeader`：标题“今天”、副标题、日期胶囊、主记录按钮。
3. `DietFocusCard`：待确认目标、待确认记录、晚餐建议、完成态四种内容。
4. 三个指标：已摄入热量、蛋白质、本周达标天数；只使用 `NutritionHomeViewModel` 和现有趋势来源可得的数据。
5. “今天吃过”使用 `DietMealRow`，最多 8 条；点击仍打开现有 `MealConfirmationView`。
6. 现有 `RecommendationSectionView` 改用 `DietCard` 或保留其内容但统一标题、间距和颜色。
7. 错误、营养不完整、目标假设警告全部使用 `DietInlineNotice`；不隐藏原有文案。

### 交互

- 顶部“＋ 记一餐”先打开一个明确入口菜单或选择动作，沿用现有：
  - 文本记录：`TextLoggingView`
  - 图片识别：`PhotoLoggingView`
- 不新增手动输入之外的保存规则；手动记录仍从文本记录页的现有按钮进入。
- 最近记录、目标确认、建议查看均复现现有行为。
- 如果保留 `NavigationLink`，不改成无法关闭的模态阻塞页面。

### 测试

新增 `TodayFocusPresentationTests`，至少覆盖：

1. 待确认目标优先于其它状态。
2. 待确认或失败记录优先于晚餐建议。
3. 有目标且无晚餐记录时输出晚餐建议。
4. 已完成目标输出完成态。
5. 无目标时不生成虚假完成率或“已完成”文案。

运行：

```bash
./Scripts/test.sh
./Scripts/test.sh --swiftdata
```

### 提交

```text
feat(ui): redesign today dashboard
```

只暂存今天相关视图、展示模型和测试。

---

## 阶段 4：日记与趋势页

### 目标

统一日记的日期/餐次结构与趋势的证据层级，不改变数据来源和判断规则。

### 文件

- `Sources/DietFeatures/Diary/DiaryView.swift`
- `Sources/DietFeatures/Trends/TrendsView.swift`
- `Sources/DietFeatures/Trends/WeeklyReviewSectionView.swift`
- 必要时新增：`Sources/DietFeatures/UI/DietCharts.swift`

### 日记改造

1. 页面外层由 `List` 改为 `ScrollView` + `LazyVStack`。
2. 顶部使用 `DietPageHeader`：标题“饮食日记”、副标题、主记录按钮。
3. 日期导航：
   - 上一天/下一天按钮。
   - 当前日期主标签。
   - 现有 `DatePicker` 作为日历选择入口。
   - 沿用现有日期范围与过滤规则，不新增限制。
4. 当日摘要卡展示已知热量、当天目标和未知项提示；不使用目标外推值。
5. 按 `MealType` 分组展示记录；每行使用 `DietMealRow`。
6. 空组显示 `DietEmptyState` 或虚线添加卡，点击复用现有记录流程。
7. 删除仍调用 `viewModel.delete`，确认对话框保留；不改变级联/图片删除开关。
8. 记录详情仍进入 `MealDetailView`，不改变编辑、来源展示或重试逻辑。

### 趋势改造

1. 页面外层改为 `ScrollView` + `LazyVStack`。
2. 标题区固定为七日周期与现有日期范围，不新增 30 天/阶段切换。
3. 图表保留 Swift Charts 的 `BarMark` 与目标 `PointMark`，只统一主题：
   - 完整摄入：`primarySoft` / `primary` 系。
   - 部分未知：`warningSoft` / `warning` 系。
   - 目标：菱形 + 虚线或同等非颜色编码。
4. 概况卡展示现有 ViewModel 字段：记录天数、平均热量、目标完成率、体重变化。
5. `hasSufficientData == false` 时保留“数据不足”提示，不生成趋势性结论。
6. `WeeklyReviewSectionView` 改为 `DietCard` 风格，保留：
   - 当前解释。
   - 待确认建议、生效日期、热量变化、触发摘要。
   - 接受/拒绝操作及确认后刷新。
7. 图表添加辅助文本摘要和 VoiceOver 可读标签，不只依赖视觉或 hover tooltip。

### 验证

- 运行全部测试。
- 使用测试数据或用户同意的合成数据，检查：
  - 空记录、1–2 天记录、3 天以上记录。
  - 部分营养未知的柱子颜色与文字提示。
  - 目标待确认与复盘建议同屏时不互相遮挡。
- 检查 960 × 640 下日期导航、图表和复盘按钮不被截断。

### 提交

```text
feat(ui): redesign diary and trends pages
```

只暂存日记、趋势和相关图表组件。

---

## 阶段 5：档案、设置与首次体验

### 目标

把“我的”、档案编辑和首次设置统一到品牌视觉，同时保留现有 Sheet 与表单校验。

### 文件

- `Sources/DietFeatures/Nutrition/MainTabView.swift` 中的 `SettingsHubView`
- `Sources/DietFeatures/Profile/ProfileRootView.swift`
- `Sources/DietFeatures/Profile/OnboardingView.swift`
- `Sources/DietFeatures/Profile/ProfileEditView.swift`
- `Sources/DietFeatures/Phase/PhasePlanFormView.swift`
- `Sources/DietFeatures/Settings/LLMSettingsView.swift`

### “我的”页

1. 用 `ScrollView` + 两列自适应卡片网格替代默认 `List` 作为主结构。
2. 顶部摘要卡显示姓名/个人档案、年龄/身高/体重/训练频率、当前阶段；数据只读自 `profileViewModel`。
3. 六项摘要卡：
   - 今日目标
   - 健身阶段
   - 身体数据
   - 饮食偏好
   - LLM API
   - 隐私与数据
4. 目标/阶段/身体数据/偏好入口复用现有 `ProfileRootView` 和编辑 Sheet；LLM 入口复用 `LLMSettingsView`；不得复制或重写表单逻辑。
5. 底部隐私说明继续使用现有文案，改为 `DietCard` 的说明样式。

### 档案与阶段

1. `ProfileRootView` 的当前方案、个人档案、阶段历史改用 `DietCard`、`DietSectionHeader` 和统一行样式。
2. 编辑档案按钮保持 Sheet；创建/切换阶段保持原有 Sheet 与 ViewModel 调用。
3. `ProfileEditView`、`PhasePlanFormView` 保留字段和校验，只统一背景、按钮、错误提示与间距。
4. 不把未知/未填写的身体数据视觉上处理成 0。

### 首次设置

1. `OnboardingView` 改为居中表单卡，宽度约 560–620 pt，背景为 `canvas`。
2. 顶部显示产品名、隐私说明，不新增多步骤进度；字段顺序沿用现有 `ProfileFormFields` 和 `PhasePlanFormFields`。
3. 保留“不完整身体数据不会用于猜测自动目标”的说明。
4. 底部“保存并开始”使用主题主按钮，并保留固定 safe area 行为。
5. 错误提示显示在表单顶部或对应 Section，不隐藏真实错误。

### 验证

- 运行默认和 SwiftData 测试。
- 启动应用，验证首次设置能完整保存，档案编辑、阶段创建、LLM 设置入口可返回。
- 960 × 640 与深色模式下检查摘要卡、表单字段、错误提示和主按钮。

### 提交

```text
feat(ui): redesign profile settings and onboarding
```

只暂存相关档案、设置和启动页文件。

---

## 阶段 6：记录、图片与确认流程

### 目标

让记录路径与设计板一致，同时保持 ViewModel、图片保存、LLM 请求和确认保存不变。

### 文件

- `Sources/DietFeatures/Logging/TextLoggingView.swift`
- `Sources/DietFeatures/Logging/PhotoLoggingView.swift`
- `Sources/DietFeatures/Logging/MealConfirmationView.swift`
- 必要时新增：`Sources/DietFeatures/Logging/MealLoggingSheet.swift`
- `Sources/DietFeatures/Nutrition/NutritionHomeView.swift`
- `Sources/DietFeatures/Diary/DiaryView.swift`

### 记录入口

1. 新增 `MealLoggingSheet`，只负责入口组织与关闭，不持有业务逻辑：
   - 分段控件：文字描述 / 图片识别。
   - 将现有 `TextLoggingView` 或 `PhotoLoggingView` 放入 `NavigationStack` sheet。
   - 确认完成后回调来源页 `reload()` 并关闭 Sheet。
2. 今天、日记的“记一餐”与空组添加入口复用该 Sheet。
3. iOS 分支保持原导航，或不在本次范围继续使用原流程；不得因为 macOS Sheet 破坏 iOS 编译。

### 文本记录

1. 将 `Form` 保持为可编辑表单，外层加 `DietCard`/主题背景。
2. 用餐时间、餐别、文本域、分析按钮、手动记录、错误/澄清信息按设计层级排列。
3. 分析中禁用重复提交并显示“正在分析…”。
4. `navigationDestination` 到现有 `MealConfirmationView` 的逻辑保持。

### 图片记录

1. 将有图/无图状态分离为稳定的预览区与空态。
2. 保留文件选择、剪贴板粘贴、Command–V、重试与本地图片路径逻辑。
3. 上传识别前主按钮只对用户主动操作响应；无图时不请求 LLM。
4. 预览替换、删除、非法图片错误不覆盖已有有效图片。

### 确认页

1. macOS 宽度 ≥ 760 pt 时使用左右分栏：左侧原始输入/图片，右侧识别项。
2. 窄窗口改为上下布局；底部动作区固定。
3. 识别项保留名称、份量、估算标记、营养来源、未知项提示。
4. “返回修改”“确认并保存”使用主题按钮。
5. 确认保存仍调用 `viewModel.confirm()` 和原有 `onConfirmed()`；重复保存保护不变。

### 验证

- `swift build --target DietFeatures`。
- 全量测试。
- 文本分析、手动记录、图片文件、剪贴板粘贴、取消、非法图片、分析失败、未知营养、保存后刷新路径逐项人工检查。
- 不在自动测试中使用真实 API、真实剪贴板或用户真实图片。

### 提交

```text
feat(ui): restyle logging and confirmation flows
```

只暂存记录与确认相关文件，以及来源页的必要调用。

---

## 阶段 7：深色、响应式与可访问性收口

### 目标

完成全应用一致性与边界检查，不新增功能。

### 文件

- 所有 `Sources/DietFeatures/UI/`
- 所有被改造页面
- 测试和必要截图记录

### 检查

1. 浅色/深色：
   - 自动跟随系统外观。
   - 侧栏、卡片、图表、Sheet、错误提示均无纯黑/纯白硬编码残留。
   - 橙色/红色状态底色与文字达到对比度要求。
2. 窗口：
   - 1100 × 760、960 × 640、1280 × 800。
   - 无横向滚动、主操作缺失、文本溢出或卡片重叠。
3. 键盘：
   - Tab 顺序完整。
   - Return 触发主操作。
   - Escape 关闭 Sheet/取消编辑。
4. VoiceOver / Accessibility：
   - 图标按钮有标签。
   - 状态文字可读，图表有摘要。
   - 估算/未知状态不只依赖颜色。
5. Reduce Motion：
   - 非必要出现/位移关闭，数据仍可理解。
6. 文案：
   - 不出现羞辱、补偿性进食或确定性因果表达。
   - 单位与数值格式保持统一，未知值不显示成 0。

### 自动化命令

```bash
./Scripts/test.sh
./Scripts/test.sh --swiftdata
plutil -lint App/Info.plist
zsh -n Scripts/generate-project.sh Scripts/test.sh
git diff --check
```

### 完整构建

```bash
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

### 提交

```text
fix(ui): polish dark mode and accessibility
```

只提交本阶段修复。若发现功能回归，回到对应阶段修复，不用最终阶段掩盖问题。

---

## 阶段 8：文档与交付收口

### 目标

记录真实完成状态和未完成的验收项。

### 文件

- `README.md`（仅在文档索引或运行说明需要时）
- `docs/implementation-status.md`
- 本实施计划

### 步骤

1. 在实施状态中新增 UI 阶段：
   - 设计令牌与组件
   - 今天、日记、趋势、我的
   - 设置、首次体验、记录与确认
   - 深色/响应式/可访问性
2. 写明自动测试与构建的实际数字；不复制旧数字，除非本次实际运行一致。
3. 单独列出仍需人工验收的项目：
   - 真实用户数据下的首次设置和重启持久化。
   - 真实剪贴板、文件选择、图片分析。
   - 真实 Keychain 与供应商 API。
   - 通知权限与深色模式截图。
4. 若任何页面或状态未完成，保留明确待办，不宣称“全部美化完成”。

### 最终命令

```bash
./Scripts/test.sh
./Scripts/test.sh --swiftdata
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

### 提交

```text
docs: record UI refresh verification
```

---

## 最终验收清单

### 自动与工程

- [ ] `./Scripts/test.sh` 全部通过。
- [ ] `./Scripts/test.sh --swiftdata` 全部通过。
- [ ] `xcodebuild` macOS Debug 构建通过。
- [ ] `plutil`、脚本语法和 `git diff --check` 通过。
- [ ] 未新增第三方依赖或网络请求。

### 视觉

- [ ] 四个一级页面均使用统一主题。
- [ ] “今天”首先展示单一重点卡，不退回等权重卡片墙。
- [ ] 侧栏为 S2 品牌化原生分栏，不使用深色侧栏。
- [ ] 浅色与深色模式均检查通过。
- [ ] 三种窗口尺寸无截断、溢出或重叠。
- [ ] 估算、未知、失败、空态和加载态都有明确文案。

### 交互

- [ ] 侧栏四项可用鼠标与键盘切换。
- [ ] 文本、图片、手动记录均可完成确认并返回刷新。
- [ ] 删除、取消、重试和关闭 Sheet 不丢失用户输入。
- [ ] 目标待确认时不会错误显示“已完成”。
- [ ] 未知营养不会在 UI 上显示为 0。

### 真实环境

- [ ] 首次设置在真实 App 中完成并重开验证数据。
- [ ] 真实 Keychain 与供应商文本/图片请求通过。
- [ ] 真实文件选择、剪贴板粘贴和大图检查完成。
- [ ] 通知和深色模式按设计文档人工验收。

只有全部完成且没有未说明的功能回归，才可宣称本次 UI 美化完成。
