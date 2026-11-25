# 前四个模块实施计划

日期：2026-11-10

## 范围

实现设计文档 01–04，不提前实现营养目标计算、LLM、拍照、推荐或通知。

1. 模块 01：用工程结构和实施状态文件固定 MVP 边界。
2. 模块 02：建立 `DietCore`、`DietFeatures` 和 iOS App 三层结构。
3. 模块 03：实现 SwiftData schema、内存测试容器、历史快照与阶段日期规则。
4. 模块 04：实现个人档案、初始阶段、手动目标输入、阶段切换及历史保留。

## 验证策略

- 使用 Swift Package 在 macOS 14 兼容环境编译 `DietCore` 与 `DietFeatures`。
- 使用内存 SwiftData 容器测试档案唯一性、手动目标校验、阶段切换、历史目标和营养快照。
- 提供 `project.yml`，在安装完整 Xcode 与 XcodeGen 后生成 iOS 工程。
- 当前环境没有完整 Xcode，iOS UI、签名、模拟器和真机行为不得标记为已验证。

## 非目标

- 不计算 BMR、TDEE 或自动营养目标。
- 不创建正式饮食记录流程和每日汇总计算器。
- 不接入网络、API Key、照片、HealthKit 或通知权限。
