# 健身饮食 macOS App

个人 macOS 健身饮食记录项目。技术栈保持 SwiftUI + SwiftData，本地优先，自行配置兼容文本和图片理解的 LLM API。

- 当前交付目标：macOS 14 及以上。
- 用户本机：macOS 27.2.1；高于部署目标的系统可以运行该应用。
- macOS 主导航为“今天、日记、趋势、我的”侧栏。
- 图片记录支持本地文件、截图／图片剪贴板以及 Finder 复制的图片文件。
- iOS 条件编译代码仅作为历史兼容保留，不属于当前生成和交付目标。

## 设计文档

- [总索引](docs/superpowers/specs/diet-app/2026-11-10-diet-app-design.md)
- [macOS 桌面版迁移设计](docs/superpowers/specs/diet-app/14-macos-desktop.md)
- [macOS 迁移实施计划](docs/superpowers/plans/2026-11-19-macos-migration.md)
- [实施状态与验证边界](docs/implementation-status.md)

## 工程结构

```text
App/                     macOS App 入口与 Info.plist
Sources/DietCore/        模型、营养/目标引擎、LLM、记录、图片和 SwiftData 适配
Sources/DietFeatures/    桌面导航、今日、日记、趋势、档案、确认页和文本/图片记录
Tests/                   领域服务、数据不变量、表单和桌面图片导入测试
project.yml              XcodeGen macOS 工程描述
```

业务规则不依赖具体 UI 或数据库。默认 SwiftPM 测试使用内存仓库；macOS 工程定义 `DIETAPP_SWIFTDATA`，启用相同领域模型上的 SwiftData 宏和持久化仓库。

## 当前功能

- 首次录入身体信息、活动水平、饮食偏好、忌口和过敏食物；可留空的身体数据不会生成虚假的自动目标。
- 创建增肌、减脂、维持、休息／恢复阶段，保留历史目标和独立体重记录。
- 本地计算克、毫升和份的营养摄入；未知项目不会被当成零。
- 使用 Mifflin–St Jeor 和活动系数生成目标建议，用户确认后保存。
- 分别展示目标差额和实际热量缺口，修改份量后重新计算。
- 配置 OpenAI 兼容 Chat Completions API，API Key 存入 Keychain。
- 文本分析、失败重试、手动回退、食物确认和营养修正。
- 从文件或剪贴板导入图片，本地保存原图并生成压缩 JPEG 上传副本；识别仍使用原确认页。
- 日记、七日趋势、规则推荐、周期复盘和待确认调整建议。

## 运行测试

```bash
./Scripts/test.sh
# 额外启用真实 SwiftData 宏和持久化测试
./Scripts/test.sh --swiftdata
```

测试脚本显式使用 SwiftPM `native` 构建系统和独立构建目录，避免新版 `swiftbuild` 与旧构建产物混用。2026-11-20：默认模式 **61 项测试通过**，`--swiftdata` 模式 **63 项测试通过**，目标均为 `arm64e-apple-macos14.0`。

如果苹果命令行工具更新后提示尚未同意许可，需要用户本人在终端完成：

```bash
sudo xcodebuild -license accept
```

默认测试覆盖领域逻辑、SwiftUI 编译和纯数据图片导入，不访问真实剪贴板，也不调用真实 LLM 供应商。没有完整 Xcode 时，不声称覆盖 SwiftData 宏、应用重启持久化、Keychain 或 App UI。

## 生成并运行 macOS 工程

前置条件：完整 Xcode、XcodeGen，以及已同意的 Apple SDK 许可。最低部署目标保持 macOS 14，不需要把部署目标改为 macOS 27。

```bash
# 未安装 XcodeGen 时，可在具备 Homebrew 的环境中执行：brew install xcodegen
./Scripts/generate-project.sh
open DietApp.xcodeproj
```

在 Xcode 中选择 `DietApp` scheme 和 **My Mac**。个人本机运行可以选择 **Sign to Run Locally**，不需要连接 iPhone，也不需要相机或相册权限。

当前已检测到 Xcode 27.2，并使用仓库 `.tooling-home` 中的 XcodeGen 2.48.0 实际生成 `DietApp.xcodeproj`。生成脚本会优先使用系统 XcodeGen，并自动回退到该本地工具。

完整 macOS Debug 构建已通过，ad-hoc 签名验证通过，应用已实际启动并显示首次设置界面。构建产物位于：

```text
DerivedData/Build/Products/Debug/DietApp.app
```

如需从命令行重新构建本机签名版本：

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

后续人工验收项目：

1. 首次设置、退出重开后的 SwiftData 数据和 Keychain。
2. 文件选择、截图粘贴、Finder 图片文件粘贴、取消选择和非法图片。
3. 真实供应商的文本／图片请求、失败重试及离线手动记录。
4. 窗口缩放、深色模式、本地通知和完整确认流程。

完整验收清单见 [macOS 桌面版迁移设计](docs/superpowers/specs/diet-app/14-macos-desktop.md)。
