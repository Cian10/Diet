# 02：技术架构与模块边界

## 技术选择

- UI：SwiftUI。
- 本地持久化：SwiftData。
- 图表：Swift Charts。
- 图片输入：PhotosUI 与系统相机能力。
- 提醒：UserNotifications。
- 密钥：Keychain。
- 可选扩展：HealthKit，仅在后续阶段实现。

默认不引入远程后端。网络请求只用于用户主动发起的 LLM 分析和后续明确选择的营养数据服务。

## 分层与职责

```text
UI 层
├── 今天、日记、趋势、我的
├── 文本/拍照记录流程
└── 识别确认、目标设置与调整确认

领域层
├── NutritionCalculator：营养换算与汇总
├── TargetEngine：每日目标与目标差额
├── RecommendationEngine：规则和候选食物推荐
├── ReviewEngine：周期复盘与调整建议
└── NotificationScheduler：本地提醒

服务层
├── LLMService：统一文本与图片请求
├── NutritionRepository：食物营养数据来源
├── ImageService：本地图片和上传副本
└── HealthKitService：后续可选

数据层
├── SwiftData
├── 本地图片存储
└── Keychain
```

## 依赖规则

1. UI 调用领域服务，不直接拼接模型请求或直接修改营养汇总值。
2. LLM 服务只返回结构化理解结果，不直接创建正式 `MealEntry`。
3. 营养计算引擎不依赖 LLM，可离线单独测试。
4. 推荐引擎只消费已计算的数据；LLM 可润色建议，但不能修改数值。
5. 每日汇总由明细重新计算或使用可重建的缓存，不能成为无法核对的手工数值。
6. 目标方案有版本，每日记录引用当天实际采用的目标快照。

## 核心数据流

```text
文本/图片
  → LLM 结构化理解
  → 字段与单位校验
  → 用户澄清和确认
  → 食物明细与营养来源快照
  → 本地营养计算
  → 每日汇总
  → 目标差额、推荐与复盘
```

## 工程验收

- 不联网时，手动记录、历史查看和营养计算仍可使用。
- 更换 LLM 供应商不需要修改界面和营养计算代码。
- 修改食物数量只需调用同一个计算引擎即可更新所有相关页面。
- API Key 不出现在源代码、SwiftData 普通字段或日志中。
