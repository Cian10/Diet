# macOS 桌面版迁移实施计划

日期：2026-11-19
设计依据：[14：macOS 桌面版迁移设计](../specs/diet-app/14-macos-desktop.md)

## 实施顺序

1. 同步总索引、产品范围、技术架构、图片记录、界面、隐私和交付文档，将交付目标改为 macOS 14+。
2. 修改 `project.yml`、应用入口、生成脚本和 `Info.plist`，生成目标只保留 macOS。
3. 将 macOS 主导航改为 `NavigationSplitView`，复用四个现有功能页面。
4. 新增 `DesktopImageImporter`，统一处理图片文件和剪贴板图片，输出经过验证的 `Data`。
5. 在 `PhotoLoggingView` 的 macOS 分支接入文件选择、粘贴按钮和 Command–V；识别及确认服务不变。
6. 增加文件、图片剪贴板、Finder 文件 URL、非法输入和错误保持测试。
7. 更新 README 与实施状态，运行 SwiftPM 测试、脚本和工程描述静态检查。
8. 在具备完整 Xcode 与 XcodeGen 后生成工程，执行设计文档列出的应用内验收。

## 明确不做

- 不重写 `DietCore` 业务规则或更换数据库。
- 不接入真实收费 API 作为单元测试。
- 不读取或清空用户真实剪贴板进行自动测试。
- 不新增 Windows、云同步、HealthKit、菜单栏常驻或全局快捷键。
- 不在没有完整 Xcode 验证时宣称 macOS App 已可交付。

## 验证命令

```bash
./Scripts/test.sh
plutil -lint App/Info.plist
zsh -n Scripts/generate-project.sh Scripts/test.sh
```

工程生成和应用运行还需要：

```bash
./Scripts/generate-project.sh
open DietApp.xcodeproj
```

## 2026-11-20 实施进展

- macOS 源码、工程描述和文档迁移已完成。
- 已使用本地 XcodeGen 2.48.0 生成 `DietApp.xcodeproj`，工程静态检查通过。
- Apple SDK 许可和首次启动组件问题已解决；默认 61 项测试、SwiftData 63 项测试、完整 macOS 构建和 ad-hoc 签名验证均通过。
- App 已实际启动并显示首次设置界面；后续只保留个人数据、真实剪贴板／API、重启和通知的人工验收。
