# 目标自动化与 AI 饮食分析实施计划

日期：2026-11-25
设计依据：[目标自动化与 AI 饮食分析设计](../specs/2026-11-25-target-auto-confirmation-ai-analysis-design.md)

## 并行边界

- 子 agent A：目标 reconciliation、今日目标修改及目标测试。
- 子 agent B：纯文本 LLM 通道、AI 分析领域服务、独立 AI 页面及 AI 测试。
- 主 agent：实施计划、共享导航接线、代码审查、冲突整合、文档、全量测试、macOS 构建与 GitHub 同步。
- 子 agent 不修改 `MainTabView.swift`、`AppRootView.swift`、`App/DietApp.swift`、共享设计系统、README 或实施状态，避免重叠写入。

## 阶段 1：基线与目标自动化

1. 运行默认与 SwiftData 测试，记录既有基线。
2. 在 `DailyTargetService` 增加幂等 reconciliation：历史缺失补记、今日自动生成并保存、已有目标不覆盖。
3. 保留既有目标计算与校验语义；无阶段、数据不足及非法规则使用明确错误。
4. 为 `DailyTargetService` 增加单日修改入口，保存 `isSingleDayOverride`。
5. 改造 `NutritionHomeViewModel` 和 `NutritionHomeView`：去除正常流程的待确认阻塞，展示今日目标摘要与修改 Sheet。
6. 更新 `TodayFocusPresentation` 及测试，移除自动目标确认分支，保留餐食确认优先级。
7. 添加目标自动保存、历史范围、不覆盖、幂等、无阶段跳过和修改测试。

## 阶段 2：AI 纯文本分析

1. 为 OpenAI 兼容客户端增加通用文本请求；JSON 食物识别继续使用 `response_format`，饮食分析请求明确省略该字段。
2. 新增分析请求与领域服务，构造近 7／14／30 天窗口，筛选已确认记录，关联每日目标和本地汇总。
3. 请求材料不包含图片、图片路径、草稿、失败记录或完整个人档案；明确数据不完整与未记录日期。
4. 提示模型输出中文约 600–900 字、短段落与少量要点，不解析 JSON，不机械截断结果。
5. 新增独立 `DietAnalysisView` 与视图模型，支持范围选择、主动分析、加载、防重复、空态、错误重试和可复制结果。
6. 添加 URLProtocol 请求体测试、纯文本响应测试、记录过滤与隐私边界测试、视图状态测试。

## 阶段 3：共享接线与整合验收

1. 主 agent 审查两个工作面的实际 diff，先修复领域或并发问题，再接共享导航。
2. 在 `AppTab`、macOS 侧栏和其他平台标签页加入“AI 分析”，使用现有 provider 与 stores 构造页面。
3. 确认首页 reconciliation 在应用现有加载路径中触发，无需额外后台任务。
4. 更新 README 与 `docs/implementation-status.md`，记录新功能、当前档案补记口径和主动上传边界。
5. 运行 `./Scripts/test.sh` 与 `./Scripts/test.sh --swiftdata`，再执行完整 macOS Debug 构建。
6. 启动应用进行界面验收：今日自动目标、修改保存、AI 范围选择、无配置／无记录状态；网络请求使用 mock 测试验证。
7. 检查 `git diff --check`、个人数据与构建产物未进入提交，核对远程后提交并推送 `origin/main`。
