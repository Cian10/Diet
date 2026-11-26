# Today Page Overrides — Atelier Nutrition Desk

> **PROJECT:** Atelier Nutrition Desk
> **PAGE:** Today (`NutritionHomeView`)
> **Page Type:** Native macOS Dual-Column Nutrition Workbench
> **Reconciled:** 2026-11-27

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/atelier-nutrition-desk/MASTER.md`) for the Today workbench page. For all shared tokens, contrast ratios, and SwiftUI rules, refer to `MASTER.md`.

---

## Page-Specific Overrides (`search.py` Generic Defaults -> Frozen Spec)

- **Overrode `Max Width: 1400px` -> `1220pt` (`DietTheme.Metrics.workbenchMaxWidth`).**
- **Overrode `12-column CSS grid` -> Responsive SwiftUI Two-Column Workbench (`twoColumnBreakpoint = 840pt`)** inside `DietWorkbenchPage` (with `GeometryReader` placed outside `DietWorkbenchPage`, never nested inside `ScrollView`).
- **Overrode generic web hover cards -> Single Elevated Stage (`DietHeroSurface`)**: Only `TodayMacroDashboardCard` renders as an elevated `surface` card; timeline, recommendations, and 7-day rhythm are borderless/lightweight panels separated by `DietHairline`.

---

## Layout Architecture

### 1. Window & Toolbar Chrome
- **Toolbar (`.toolbar`):** Compact localized date label (e.g., `11月21日 周六`, `inkSecondary`) + `+ 记一餐` primary/menu action bound to `.keyboardShortcut("n", modifiers: .command)`.
- **No preachy header:** Remove in-scroll `DietPageHeader` subtitle, legacy `DietFocusCard`, `todayTargetCard`, 3× `DietMetricCard`, and redundant `目标参考` card.

### 2. Responsive Breakpoint (`width >= 840pt`)
- **Wide Workbench (`>= 840pt`, e.g., `1100×760` and `1280×800`):**
  - `HStack(alignment: .top, spacing: 24)` (`DietTheme.Metrics.sectionSpacing`):
  - **Primary Left Column (`.frame(maxWidth: .infinity)`):**
    1. Inline error banner (`dangerSoft` / `danger`, shown only on error)
    2. `TodayMacroDashboardCard` (`DietHeroSurface`)
    3. `TodayMealTimelineSection` (borderless timeline + bottom inline quick-log bar)
  - **Utility Right Rail (`.frame(minWidth: 290, idealWidth: 320, maxWidth: 340)`, bounded by `railMinWidth: 290` .. `railMaxWidth: 350`):**
    1. Conditional compact amber action bar (only when `focus.needsAttention` for pending/failed meal; clicking opens `focusedEntry`)
    2. `RecommendationSectionView` (lightweight contextual rows, `Next training` toggle, `kcal / P` right-aligned)
    3. `TodayWeeklyRhythmPanel` (7-day capsule bars + `记录 X/7 天` / `达标 Y/Z 天` + latest weight & delta)
- **Compact Single Column (`< 840pt`, e.g., `960×640` where detail column is ~740pt):**
  - Vertical order: `TodayMacroDashboardCard` -> conditional attention banner -> `TodayMealTimelineSection` -> `RecommendationSectionView` -> `TodayWeeklyRhythmPanel`.

---

## Page-Specific Components (`TodayDashboardComponents.swift`)

### 1. `TodayMacroDashboardCard` (Sole Elevated Stage)
- **Top row:**
  - Remaining state: `"剩余可摄入"` + `heroMetric` (`36pt` Bold SF Rounded, `.monospacedDigit()`) + supporting `"已摄入 X / 目标 Y kcal"`.
  - Over-target state: Neutral `"已超出目标"` in `ink` / `inkSecondary` — **never red**.
  - Missing-target state: `"已摄入 X kcal · 尚未设置今日目标"`.
  - Right trailing controls: compact status capsule (`"单日修改"` or `"已生效"`) + lightweight `"修改"` button (`onEditTarget`).
- **Center bar:** `DietFuelBar(progress: ..., tint: DietTheme.Palette.primary, height: 10, hasUncertainTail: !intake.isComplete)`.
- **Incomplete disclosure:** When `!intake.isComplete`, render a compact clickable row directly below the bar: `warning` SF Symbol + `ink`/`inkSecondary` text `"部分合计：<item>（份量未知），未按 0 处理"` + `"去补全"` action (`onTapIncomplete`).
- **Bottom 3-column macro grid:** Equal-width columns for Protein (`macroProtein`), Carbs (`macroCarbs`), and Fat (`macroFat`) using `DietFuelBar(height: 5)` + `"74 / 130 g"` and `"剩 56 g"` (all `.monospacedDigit()`, text in `ink` / `inkSecondary`). Optional estimated calorie deficit (`assessment?.actualCalorieDeficit`) renders as a single minimal footnote at the bottom edge.

### 2. `TodayMealTimelineSection`
- **Header:** `DietGroupHeader("今日餐食", detail: "\(entries.count) 条记录")`.
- **Rows:** All today's entries sorted ascending chronologically (no `.prefix(8)` cap), separated by `DietHairline`:
  - Monospaced time prefix (`08:20`) + meal title/summary + right-aligned `kcal · 蛋白 Xg` + subdued status dot/label.
  - Clicking navigates via `.navigationDestination` / `destination(entry)`.
- **Inline Quick-Log Slot:** `surface` fill + `1pt` `hairline` border:
  - Left: meal-type menu defaulting to `TodayFocusPresentation.suggestedMealType(for: hour, recorded:)`.
  - Center: `TextField` submitting on `⌘↩` -> opens `TextLoggingView` with `initialText`, `initialMealType`, `autoAnalyzeOnAppear: true`.
  - Right: photo-log icon button (explicit `.accessibilityLabel`) + `"分析"` button + secondary `"手动记录"` text link.

### 3. `TodayWeeklyRhythmPanel`
- **Header:** `DietGroupHeader("近 7 日节奏")`.
- **Chart:** 7 equal-width capsule bars (`日 一 二 三 四 五 六`), today highlighted in `primary`, days with unknown nutrition marked with `warning` dashed stroke / stripe pattern (`color-not-only`).
- **Summary & Weight:** Compact 2-column summary (`记录 X/7 天`, `达标 Y/Z 天`) + bottom latest weight (`subMetric` `68.0 kg` + `weightDeltaText`, or `"暂无体重记录"`).

---

## Today Accessibility & Motion Acceptance Rules
- **VoiceOver Readouts:** Expose clear `.accessibilityLabel` / `.accessibilityValue` strings for:
  1. Remaining calories (or neutral over-target amount)
  2. Remaining grams for Protein, Carbs, and Fat
  3. Unknown-nutrition item names and `"部分合计 / 含未知项"` disclosure
  4. 7-day logging/goal rhythm and latest weight summary
  5. Icon-only actions (`+ 记一餐`, photo quick-log button)
- **Reduce Motion:** Under `@Environment(\.accessibilityReduceMotion)`, `DietFuelBar` updates and state transitions must avoid spatial displacement or scale bounce.
- **Dynamic Type & Non-Overflow:** Test at `960×640`, `1100×760`, and `1280×800` in both Light and Dark modes; verify zero horizontal overflow, button crushing, or clipped macro labels.
