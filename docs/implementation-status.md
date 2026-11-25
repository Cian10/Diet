# 实施状态

更新时间：2026-11-21

## 当前交付方向

- 目标平台为 macOS 14+；用户本机为 macOS 27.2.1。
- `project.yml` 中的 `DietCore`、`DietFeatures` 和 `DietApp` 均为 macOS target。
- macOS 使用 `NavigationSplitView` 侧栏，保留“今天、日记、趋势、我的”。
- 图片记录支持文件选择、剪贴板图片和 Finder 文件 URL；识别、原图、重试、确认及营养计算继续复用原服务。
- 已使用 XcodeGen 2.48.0 生成 `DietApp.xcodeproj`，并使用 Xcode 27.2 完整构建。
- 本机 ad-hoc 签名应用位于 `DerivedData/Build/Products/Debug/DietApp.app`。
- 设计与迁移步骤见 [macOS 桌面版迁移设计](superpowers/specs/diet-app/14-macos-desktop.md) 和 [迁移实施计划](superpowers/plans/2026-11-19-macos-migration.md)。
- 本轮视觉改造依据 [UI 视觉设计](superpowers/specs/2026-11-21-diet-app-ui-design.md) 和 [UI 改造实施计划](superpowers/plans/2026-11-21-ui-refresh.md)，未修改业务算法、SwiftData schema、LLM 请求、Keychain 或隐私边界。

## 模块状态

| 模块 | 状态 | 已实现 | 验证边界 |
|---|---|---|---|
| 01 产品范围与 MVP | 已迁移为 macOS 范围 | 个人、本地优先、文本／图片记录和用户确认约束不变 | 范围与设计审查完成 |
| 02 技术架构 | 已构建并启动 | macOS target、窗口、品牌化侧栏导航、既有分层和仓库协议 | 完整 App 编译通过；首次设置及合成数据主界面已渲染，真实个人数据流程待人工验收 |
| 03 数据模型与持久化 | 宏和内存持久化已验证 | 全部设计实体、SwiftData schema/仓库、内存仓库、营养快照 | 两项 SwiftData 测试通过；应用真实磁盘数据和重启持久化待人工验收 |
| 04 用户档案与健身阶段 | 已实现，首次设置已渲染 | 首次设置、档案编辑、体重历史、手动目标、阶段切换和历史展示 | 服务与表单测试通过；未自动填写用户个人数据 |
| 05 营养计算与目标引擎 | 已实现 | 克／毫升／份换算、未知汇总、Mifflin–St Jeor、目标差额／实际缺口、自动目标确认 | 确定性单元测试通过；未接入健康平台训练消耗 |
| 06 LLM 服务 | 已实现，待真实 API 验证 | OpenAI 兼容 Chat Completions、文本／图片请求、JSON 校验、一次重试、Keychain 和设置页 | 本地 URLProtocol 测试通过；未调用真实供应商，macOS Keychain 待界面验收 |
| 07 文本饮食记录 | 已实现，待应用流程验收 | 原文草稿、失败重试、澄清信息、手动回退、确认编辑、重复保存保护 | 服务和确认页状态测试通过 |
| 08 图片饮食记录 | 桌面源码和导入测试已完成 | 文件／剪贴板输入、本地原图、JPEG 上传副本、视觉分析、原图重试、共用确认页 | PNG/JPEG、文件 URL、非法输入和状态保持测试通过；真实 `NSPasteboard`、文件面板和图片 API 待界面验收 |
| 09 首页、日记与趋势 | 已实现并完成视觉改造 | 今日重点与指标、日期／餐次日记、七日图表与文本摘要、响应式趋势布局 | 服务测试、SwiftUI 编译和合成数据渲染通过；真实数据与完整窗口交互待人工验收 |
| 10 推荐 | 已实现 | 本地规则、过敏／忌口过滤、营养改善计算 | 确定性测试通过 |
| 11 复盘与通知 | 复盘已实现；通知待应用验收 | 周期复盘、待确认调整建议、本地通知调度服务 | 未申请真实系统通知权限，未验证通知横幅和跳转 |
| 14 macOS 迁移 | 迁移、构建和启动已完成 | macOS 14 target、桌面窗口与导航、文件／粘贴图片、Xcode 工程、迁移文档和测试脚本 | 真实个人数据、剪贴板、API、重启和通知仍按下方清单验收 |

## 2026-11-21 UI 视觉改造

- 新增 `Sources/DietFeatures/UI/` 共享设计系统：语义主题色、字体与间距、三类按钮、卡片、重点卡、指标、餐食行、状态标签、页面容器、标题区、空态／加载态及品牌化侧栏。
- 今天页改为“今日重点＋三项指标＋目标参考＋建议＋今日记录”；新增纯展示模型 `TodayFocusPresentation`，只决定重点卡优先级，不改变保存、目标确认或营养计算。
- 日记支持日期导航、当日摘要、按餐次分组和空组记录入口；趋势提供七日柱图、目标虚线／菱形、今天标记、文本／VoiceOver 摘要和宽窄窗口自适应布局。
- “我的”改为个人摘要和六项双列设置入口；首次设置、档案／阶段表单、LLM 设置、文字／图片记录、周期复盘和餐食确认页统一接入主题。
- 餐食确认页在宽窗口使用左右分栏、窄窗口使用纵向布局，固定底部营养合计与“返回修改／确认并保存”；仍调用原 `confirm()`，模型估算、未知营养、原图和原文均保留。
- 使用合成内存数据通过 AppKit 实际渲染并逐张检查：今天浅色／深色及 960／1100／1280 宽度，日记、趋势、我的、首次设置、文字／图片记录和确认页的代表性浅色／深色；另检查 742 pt 内容区和 680 pt 确认页窄布局。
- 截图位于被 Git 忽略的 `DerivedData/UIPreviews/`；渲染未写入真实 SwiftData 或 Keychain，临时渲染测试未纳入最终测试套件。
- 关键文字／背景配色的脚本对比度检查均不低于 4.5:1；这不替代完整键盘和 VoiceOver 人工验收。

## 最终验证结果

### 自动测试

- `./Scripts/test.sh`：**66 项测试、17 个套件全部通过**。
- `./Scripts/test.sh --swiftdata`：**68 项测试、18 个套件全部通过**。
- 两种模式目标均为 `arm64e-apple-macos14.0`。
- SwiftData 模式额外通过“完整 schema 创建内存容器”和“SwiftData 仓库保存档案／阶段”。
- 测试不访问真实剪贴板，不调用真实模型供应商。

### Xcode 与应用

- `DietApp.xcodeproj` 已生成，`project.pbxproj` 通过 Plist 校验。
- 全部 target 使用 `SDKROOT = macosx`，部署目标为 14.0，并启用 `DIETAPP_SWIFTDATA`。
- 2026-11-21 最终完整 Debug 构建成功，包含 SwiftData 宏、应用入口、新 UI 源文件和两个嵌入 framework。
- 两个 framework 自动生成 Info.plist 的配置问题已修复。
- ad-hoc 签名通过 `codesign --verify --deep --strict` 和 Designated Requirement 校验。
- App 已实际启动并持续运行；窗口截图确认显示正常“开始使用”表单，不是初始化错误页。

### 静态检查

- `App/Info.plist`、`project.pbxproj`、YAML 和脚本语法检查通过。
- 文档本地链接检查通过。
- 未发现 iOS 设备族、iOS SDK、相机权限或方向设置残留。

## 仍需人工验收

1. 输入真实个人档案并完成首次设置，检查今天、日记、趋势和我的侧栏页面。
2. 退出并重开 App，验证真实磁盘上的档案、目标、记录和本地图片。
3. 验证文件选择、截图粘贴、Finder 文件粘贴、空剪贴板、非图片、取消选择和大图。
4. 保存 API Key，调用真实供应商验证文本／图片识别、失败重试和确认后每日汇总。
5. 验证离线手动记录、真实 App 的窗口缩放与深色模式、本地通知和通知跳转。
6. 验证完整键盘导航、焦点顺序和 VoiceOver 朗读；合成截图与颜色对比度检查不能替代这些流程。

当前 ad-hoc 构建用于本机开发运行，不代表已完成 Developer ID、公证或公开分发验收。

## 环境备注

- Apple SDK 许可和 Xcode 首次启动组件已配置完成。
- SwiftPM 测试使用 `native` 构建系统以避开本次工具链更新时的 `swiftbuild`／Testing 宏问题；该构建系统目前会输出弃用警告，但测试全部通过。
- 当前 Documents／文件提供程序可能给构建产物附加 `FinderInfo` 扩展属性；若严格签名校验出现 `Disallowed xattr`，可只对 DerivedData 中的 app 执行 `xattr -dr com.apple.FinderInfo <app-path>` 后重新校验。
