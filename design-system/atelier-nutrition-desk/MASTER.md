# Design System Master File — Atelier Nutrition Desk

> **LOGIC:** When building a specific page, first check `design-system/atelier-nutrition-desk/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Atelier Nutrition Desk (静谧营养工作台)
**Platform:** macOS 14+ / iOS 17+ (Native `SwiftUI`, `Charts`, `AppKit` — zero third-party UI dependencies)
**Generated & Reconciled:** 2026-11-27
**Authoritative Contract:** `docs/superpowers/plans/2026-11-26-phase1-workbench-ui.md` §0, §2.1–§2.2
**Token File:** `tokens.json` (W3C Design Tokens Community Group JSON; master-level only)

---

## Reconciliation & Override Notes (`ui-ux-pro-max` -> Frozen Spec)

The baseline `ui-ux-pro-max` `search.py --design-system` generator targets generic web wellness apps and emitted defaults that were explicitly overridden to align with the frozen Phase 1 Atelier Nutrition Desk specification:

| Dimension | `search.py` Generic Default | Overridden Frozen Atelier Nutrition Desk Spec |
|---|---|---|
| **Visual Style** | `Neumorphism` (convex/embossed multi-shadows) | **Quiet Editorial Workbench** — Stone Paper `#F6F6F3` / Graphite `#131413`, 60% fewer card borders, `0.5pt` `hairline` dividers, and a single elevated `DietHeroSurface` per workbench view. |
| **Color Palette** | Purple `#7C3AED` / `#8B5CF6`, Lavender `#FAF5FF`, Accent `#059669`, Red `#DC2626` | **Deep Pine & Stone Paper** (`#1F5E43` Light / `#5CC192` Dark primary, `#F6F6F3` / `#131413` paper, `#181A18` / `#F2F2EE` ink) + desaturated macro signal tokens (`macroProtein`, `macroCarbs`, `macroFat` & `*Soft`). |
| **Typography** | Google Fonts (`Lora` + `Raleway` via CSS `@import`) | **Native Apple System Type** — **SF Pro** (`Font.largeTitle`, `.title3`, `.headline`, `.body`, `.footnote`, `.caption`) and **SF Rounded** (`heroMetric` 36pt Bold `.rounded`, `subMetric` 18pt Semibold `.rounded`), `.monospacedDigit()` on all numeric telemetry, respecting Dynamic Type. |
| **Page Pattern** | Web landing (`Hero + Testimonials + CTA`, `max-w` CSS, 375/768/1024/1440) | **Native macOS Workbench Shell** — `NavigationSplitView` + `.listStyle(.sidebar)` native vibrancy + `.windowToolbarStyle(.unified)` (`minWidth: 960, minHeight: 640`, `defaultSize: 1120×760`), `workbenchMaxWidth: 1220pt`, `twoColumnBreakpoint: 840pt`, `railMinWidth: 290pt`, `railMaxWidth: 350pt`. |
| **Iconography & Effects** | Web SVG (Heroicons/Lucide) + CSS hover lift `translateY(-2px)` | **SF Symbols** (explicit `.fill` mapping for active sidebar tabs) + **non-shifting hover** (subtle `surfaceMuted` background tint only; zero positional jump; honors `@Environment(\.accessibilityReduceMotion)`). |

---

## 1. Color Palette (`DietTheme.Palette`)

All 20 legacy static properties are preserved for backward compatibility across secondary tabs (Diary, Trends, AI Analysis, Profile), updated in place to the Atelier palette, and extended with 7 semantic tokens. Raw hex literals must never appear in feature views; always reference `DietTheme.Palette.*`.

### 1.1 Surface, Text & Structural Tokens (20 Existing + `hairline`)

| Swift Token | Light Hex | Dark Hex | Role & Usage |
|---|---|---|---|
| `canvas` | `#F1F1EC` | `#101110` | Outer form backdrop / grouped sheet canvas |
| `paper` | `#F6F6F3` | `#131413` | Primary Stone Paper / Graphite workspace background |
| `sidebar` | `#EFEFE9` | `#181918` | Fallback sidebar surface (macOS uses native `.listStyle(.sidebar)` vibrancy) |
| `surface` | `#FFFFFF` | `#1C1E1C` | Elevated primary stage (`DietHeroSurface`), inputs, modal sheets |
| `surfaceMuted` | `#ECECE7` | `#252825` | Progress bar tracks, segmented slots, hover row fill |
| `ink` | `#181A18` | `#F2F2EE` | Primary headings, hero metrics, meal titles |
| `inkSecondary` | `#5B605C` | `#A2A8A3` | Supporting body text, units, secondary labels |
| `inkTertiary` | `#6E7470` | `#868D88` | Auxiliary metadata >= 11pt only (see WCAG guardrails below) |
| `border` | `#E2E2DC` | `#2D302D` | Structural strokes and borders |
| `hairline` | `#E2E2DC` | `#2D302D` | `0.5pt` divider (`DietHairline`) separating borderless timeline rows & section headers |
| `primary` | `#1F5E43` | `#5CC192` | Deep Pine primary actions, target progress fill, active focus emphasis |
| `primaryDeep` | `#174833` | `#8ADBB3` | Hover / high-emphasis primary button background |
| `primaryText` | `#1D573E` | `#7AD4A8` | Light-surface status text, text buttons, active sidebar selection tint |
| `onPrimary` | `#FFFFFF` | `#0D1F17` | Text/icons rendered on `primary` |
| `onPrimaryDeep` | `#FFFFFF` | `#0F241B` | Text/icons rendered on `primaryDeep` |
| `primarySoft` | `#E4EFE9` | `#1E3329` | Subtle active pill / sidebar selection pill background |
| `primaryLine` | `#C7DDD1` | `#2E4B3D` | Subtle active pill border |
| `warning` | `#B86B1A` | `#F0B25F` | Estimated / unknown-nutrition icon, hatched tail, and badge accent |
| `warningSoft` | `#FBF1E3` | `#362A1B` | Unknown-nutrition notice and pending-meal banner tint |
| `danger` | `#B33A32` | `#F08078` | Destructive actions (delete meal) and request/validation errors **only** |
| `dangerSoft` | `#FAE7E5` | `#38201E` | Error container fill |

### 1.2 Macro Nutrition Signal Tokens (6 New)

| Swift Token | Light Hex | Dark Hex | Role & Usage |
|---|---|---|---|
| `macroProtein` | `#2A6F97` | `#64B5E5` | Protein progress bar fill and subtle icon/dot accent |
| `macroProteinSoft` | `#E6F0F6` | `#1B2F3B` | Protein soft badge/chip background |
| `macroCarbs` | `#C47D2B` | `#E5A952` | Carbohydrate progress bar fill and subtle icon/dot accent |
| `macroCarbsSoft` | `#F8EFE3` | `#352919` | Carbohydrate soft badge/chip background |
| `macroFat` | `#8A5A7E` | `#C68FB8` | Fat progress bar fill and subtle icon/dot accent |
| `macroFatSoft` | `#F2EBF0` | `#31232E` | Fat soft badge/chip background |

---

## 2. Verified WCAG AA Contrast Matrix & Guardrails

Target thresholds per WCAG 2.1 AA and `ui-ux-pro-max` Priority #1 (`color-contrast`, `color-accessible-pairs`, `color-dark-mode`): **>= 4.5:1** for normal text, **>= 3.0:1** for large text (>= 18pt / 14pt bold) and non-text UI graphics (bars, icons, borders).

| Foreground / Background Pair | Light Ratio | Dark Ratio | Compliance & Required Rule |
|---|---|---|---|
| `ink` on `surface` | **17.50:1** | **14.95:1** | AAA — safe for all text sizes |
| `ink` on `paper` | **16.17:1** | **16.45:1** | AAA — safe for all text sizes |
| `ink` on `surfaceMuted` | **14.77:1** | **13.28:1** | AAA — safe for all text sizes |
| `inkSecondary` on `surface` | **6.42:1** | **6.92:1** | AA+ — safe for all body & supporting text |
| `inkSecondary` on `paper` | **5.93:1** | **7.62:1** | AA+ — safe for all body & supporting text |
| `inkSecondary` on `surfaceMuted` | **5.41:1** | **6.15:1** | AA — safe for pill/track labels |
| `inkTertiary` on `surface` | **4.78:1** | **4.94:1** | AA — safe on `surface` (>= 11pt auxiliary metadata) |
| `inkTertiary` on `paper` | **4.41:1** | **5.43:1** | **Guardrail:** In Light mode `4.41:1` is slightly below 4.5:1 on `paper`. Use `inkSecondary` (`5.93:1`) for small text on `paper`; restrict `inkTertiary` on `paper` to >= 11pt non-critical captions or place inside `surface`. |
| `onPrimary` on `primary` | **7.66:1** | **7.75:1** | AAA — primary CTA buttons |
| `onPrimaryDeep` on `primaryDeep` | **10.44:1** | **9.98:1** | AAA — hovered/pressed primary CTA |
| `primaryText` on `surface` | **8.45:1** | **9.43:1** | AAA — links & inline text actions |
| `primaryText` on `primarySoft` | **7.17:1** | **7.57:1** | AAA — active sidebar item & status pills |
| `primary` on `surface` / `surfaceMuted` | **7.66:1 / 6.47:1** | **7.59:1 / 6.74:1** | AAA / AA+ — main fuel bar fill & focus rings |
| `danger` on `surface` / `dangerSoft` | **5.89:1 / 4.94:1** | **6.44:1 / 5.79:1** | AA — error messages & destructive buttons |
| `warning` on `surface` / `warningSoft` | **4.07:1 / 3.64:1** | **8.98:1 / 7.47:1** | **Guardrail:** Light mode meets >= 3:1 (graphics/icons/stripes/large text) but < 4.5:1 for small text. Pair `warning` icons/stripes with `ink` or `inkSecondary` copy on `surface`/`warningSoft`. |
| `macroProtein` on `surface` / `surfaceMuted` | **5.50:1 / 4.64:1** | **7.42:1 / 6.59:1** | AA — safe for graphical bar & label |
| `macroFat` on `surface` / `surfaceMuted` | **5.46:1 / 4.61:1** | **6.41:1 / 5.69:1** | AA — safe for graphical bar & label |
| `macroCarbs` on `surface` / `surfaceMuted` | **3.33:1 / 2.81:1** | **8.09:1 / 7.19:1** | **Guardrail:** Light mode `macroCarbs` (`#C47D2B`) meets 3.33:1 on `surface` (graphical bar fill) but is 2.81:1 against `surfaceMuted` (`#ECECE7`). Never render small text in `macroCarbs` on Light surfaces—keep macro titles/grams in `ink` / `inkSecondary` and always pair bars with explicit text labels (`color-not-only`). |

---

## 3. Typography (`DietTheme.Typography`) & Number Formatting

Uses native **SF Pro** and **SF Rounded** via SwiftUI semantic font styles so macOS and iOS Dynamic Type scaling work automatically.

| Token | Definition | Usage |
|---|---|---|
| `pageTitle` | `Font.largeTitle.weight(.semibold)` | Top-level view header (when not moved to native macOS Toolbar) |
| `sectionTitle` | `Font.title3.weight(.semibold)` | Major section headings |
| `cardTitle` | `Font.headline.weight(.semibold)` | Card and sheet titles |
| `body` | `Font.body` | Primary prose, meal descriptions, form fields |
| `supporting` | `Font.footnote` | Secondary explanations, inline error hints, references |
| `metric` | `Font.title2.weight(.semibold)` | Secondary metric readouts (`.monospacedDigit()`) |
| `micro` | `Font.caption.weight(.medium)` | Status pills, timestamps, unit annotations |
| `heroMetric` *(new §2.1)* | `Font.system(size: 36, weight: .bold, design: .rounded)` | Remaining / over-target hero kcal number inside `TodayMacroDashboardCard` (pair with `.monospacedDigit()` and Dynamic Type / `@ScaledMetric` accommodation) |
| `subMetric` *(new §2.1)* | `Font.system(size: 18, weight: .semibold, design: .rounded)` | Compact panel KPIs (e.g., latest weight `68.0 kg`, `.monospacedDigit()`) |
| `groupEyebrow` *(new §2.1)* | `Font.caption.weight(.semibold)` | `DietGroupHeader` borderless section eyebrow |

### Typography Rules (`ui-ux-pro-max` + Apple HIG)
- **Tabular figures (`number-tabular`):** Apply `.monospacedDigit()` to every calorie, macro gram, clock timestamp (`08:20`), and weight value so live refreshes never cause horizontal layout jitter.
- **Locale-aware formatting (`number-formatting`):** Use `DietFormat` (`1,070 kcal`, `68.0 kg`) with thousand separators.
- **No forced truncation (`truncation-strategy`):** Prefer wrapping across 2 lines over ellipsis where space allows; expose full text via VoiceOver and tooltips when truncated.

---

## 4. Layout Metrics & Spacing (`DietTheme.Metrics`)

| Token | Value | Usage |
|---|---|---|
| `pagePadding` | `28pt` | Standard desktop page padding |
| `compactPagePadding` | `20pt` | Compact / narrow-width padding |
| `sectionSpacing` | `24pt` | Vertical spacing between major sections and `HStack` column gutter |
| `itemSpacing` | `12pt` | Standard stack spacing between sibling rows/controls |
| `cardPadding` | `18pt` | Internal padding for `DietCard` |
| `focusPadding` | `22pt` | Internal padding for `DietHeroSurface` |
| `controlHeight` | `32pt` | Tightened macOS desktop control height (buttons/inputs) |
| `cardRadius` | `12pt` | Softened `DietCard` corner radius |
| `focusRadius` | `16pt` | `DietHeroSurface` corner radius |
| `controlRadius` | `8pt` | Tightened button/input corner radius |
| `sheetRadius` | `18pt` | Modal sheet corner radius |
| `contentWidth` | `1180pt` | Legacy `DietPage` max width |
| `workbenchMaxWidth` *(new §2.1)* | `1220pt` | `DietWorkbenchPage` maximum readable width |
| `railMinWidth` *(new §2.1)* | `290pt` | Right utility rail minimum width |
| `railMaxWidth` *(new §2.1)* | `350pt` | Right utility rail maximum width |
| `twoColumnBreakpoint` *(new §2.1)* | `840pt` | Detail-area width threshold for 2-column vs 1-column folding |

---

## 5. Native Shell, Primitives & Component Specs

### 5.1 macOS Native Window & Sidebar Shell
- **Window:** `WindowGroup` with `.frame(minWidth: 960, minHeight: 640)`, `.defaultSize(width: 1120, height: 760)`, and `.windowToolbarStyle(.unified)`.
- **Sidebar (`DietSidebar`):**
  - Uses `NavigationSplitView` + `.listStyle(.sidebar)` native macOS vibrancy (do **not** flood with opaque `Palette.sidebar` on macOS).
  - Remove decorative brand header blocks (no green leaf square, no `TODAY · MM/dd` eyebrow).
  - Primary nav items (`AppTab.primarySidebarItems`): strictly 4 items (`today`, `diary`, `trends`, `analysis`), eliminating duplicate profile item in the main list.
  - Explicit active `.fill` SF Symbol mapping: `sun.max.fill`, `book.closed.fill`, `chart.line.uptrend.xyaxis` (no `.fill` exists), `sparkles` (no `.fill` exists), `person.fill`.
  - Active row pill: `primarySoft` background + `primaryText` foreground.
  - Single bottom profile status bar separated by `DietHairline`, showing phase + version and latest weight (e.g., `维持 · v1` / `68.0 kg`), clickable to `.profile`.
- **Keyboard Shortcuts:** `⌘1`–`⌘5` tab switching, `⌘N` quick-log action, `⌘↩` inline text analysis submit.

### 5.2 Frozen Primitives (§2.2)
1. **`DietHairline`**: `0.5pt` horizontal divider tinted `DietTheme.Palette.hairline`, used instead of per-row card borders.
2. **`DietGroupHeader<Trailing: View>`**: Borderless section header combining `groupEyebrow` (`12pt Semibold` `inkSecondary`) on the left, optional trailing view or `detail: String?` on the right, and `DietHairline` underneath.
3. **`DietHeroSurface<Content: View>`**: Sole elevated surface per workbench page (`surface` fill, `focusRadius = 16pt`, `1pt` `border` stroke, subtle shadow `opacity: 0.025, radius: 4`), default `padding: 22`.
4. **`DietFuelBar`**: Horizontal progress bar (`progress: Double`, `tint: Color`, `height: CGFloat = 8`, `hasUncertainTail: Bool = false`):
   - Clamps visual bar width to `0...1`; **never turns red when `progress > 1.0`**.
   - When `hasUncertainTail == true`, renders a `Canvas`-drawn `45°` `warning`-tinted hatched/striped segment at the end of the filled track so uncertainty is distinguishable without color alone (`pattern-texture`).
   - Respects `@Environment(\.accessibilityReduceMotion)`: disables animated width transitions when Reduce Motion is enabled.
5. **`DietPageHeader`**: Optional `subtitle: String? = nil` (renders zero extra vertical spacing when `nil`, eliminating preachy subtitles).
6. **`DietCard`** (legacy pages): Softened shadow (`opacity: 0.02, radius: 2`) and `12pt` corner radius.
7. **`DietButtons`**: `controlHeight = 32pt`, `controlRadius = 8pt`; `DietSecondaryButtonStyle` and `DietTextButtonStyle` provide macOS pointer hover background tint without layout-shifting scale/translation.

---

## 6. Product Principles & `ui-ux-pro-max` Accessibility Checklist

### Product Guardrails (Non-Negotiable)
- **Unknown nutrition != 0:** Incomplete items must trigger `hasUncertainTail = true` on `DietFuelBar` and surface an explicit `"部分合计 / 含未知项"` notice naming the item(s) and offering a `"去补全"` action.
- **No red calorie penalty:** Exceeding daily calorie target uses neutral wording (`已超出目标`) and `primary`/`ink` styling. `danger` is strictly for delete actions and error states.
- **Zero data fabrication & single-day isolation:** Never fabricate body metrics or confirmed meals; single-day target edits apply only to that date (`"单日修改"` pill) without mutating the phase plan.

### Verified `ui-ux-pro-max` SwiftUI & UX Rules
- [ ] **WCAG AA Contrast (`color-contrast`, `color-dark-mode`):** Text >= 4.5:1, graphics/stripes/borders >= 3.0:1 verified independently in Light and Dark modes.
- [ ] **Not Color Alone (`color-not-only`, `pattern-texture`):** Hatched `DietFuelBar` tail, SF Symbol icons, status dots paired with text labels, and direct numeric readouts.
- [ ] **VoiceOver & Semantic Views (`voiceover-sr`, `aria-labels`, `icon-context`):** Meaningful `.accessibilityLabel` on all icon-only controls (`+ 记一餐`, photo button, delete/dismiss actions) and combined summaries for macro dashboard, timeline rows, and 7-day rhythm; decorative icons hidden via `.accessibilityHidden(true)`.
- [ ] **Reduced Motion (`reduced-motion`):** Every non-trivial transition and bar update checks `@Environment(\.accessibilityReduceMotion)`—no spatial displacement or scale bounce when enabled.
- [ ] **Dynamic Type (`dynamic-type`):** Use semantic font styles and flexible wrapping layouts; avoid clipping or fixed-height text truncation under larger text settings.
- [ ] **Keyboard Navigation (`keyboard-nav`, `keyboard-shortcuts`, `focus-states`):** Full Tab order, visible system focus rings, `Escape` sheet dismissal (`@Environment(\.dismiss)`), `⌘1`–`⌘5`, `⌘N`, `⌘↩`, and type-safe `.navigationDestination(for:)`.
- [ ] **Multi-State Previews (`Create multiple previews`):** Include `#Preview("Light")` and `#Preview("Dark")` (plus populated/incomplete/narrow states) without changing view identity across state branches.
