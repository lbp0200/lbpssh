# lbpSSH Linear Design System Redesign

## Date: 2026-04-05

## 1. Concept & Vision

将 lbpSSH 打造成一款具有 Linear 产品美学的 SSH 终端管理器。整体感受：极致精密的工程感 —— 每一个元素都存在于精心校准的亮度层级中，从几乎不可见的边框（`rgba(255,255,255,0.05)`）到柔和的发光文本（`#f7f8f8`）。这不是简单地将暗色主题应用到浅色设计上，而是将黑暗作为原生媒介，通过白色透明度的微妙渐变来管理信息密度。

## 2. Design Language

### 2.1 Color Palette

#### Background Surfaces
| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#08090a` | 页面背景（最深） |
| `panel` | `#0f1011` | 侧边栏、面板背景 |
| `surface` | `#191a1b` | 悬浮层、卡片、Dropdown |
| `surfaceElevated` | `#28282c` | 最浅悬浮层、hover 状态 |

#### Text Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `textPrimary` | `#f7f8f8` | 主要文本（近白，非纯白） |
| `textSecondary` | `#d0d6e0` | 正文、描述 |
| `textTertiary` | `#8a8f98` | 占位符、元数据 |
| `textQuaternary` | `#62666d` | 时间戳、禁用状态 |

#### Brand & Accent
| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#5e6ad2` | 品牌紫（CTA 背景） |
| `accentInteractive` | `#7170ff` | 交互元素（链接、活跃状态） |
| `accentHover` | `#828fff` | hover 状态 |

#### Border System
| Token | Value | Usage |
|-------|-------|-------|
| `borderSubtle` | `rgba(255,255,255,0.05)` | 默认边框 |
| `borderStandard` | `rgba(255,255,255,0.08)` | 卡片、输入框边框 |
| `borderSolid` | `#23252a` | 实体边框 |

#### Status (Unchanged - Functional Colors)
保留功能色：绿色=成功、红色=错误、黄色=警告（终端用户习惯）

### 2.2 Typography

#### Font Stack (User Customizable)
- **Primary**: Inter Variable with OpenType features `"cv01", "ss03"` globally
- **Fallback**: `SF Pro Display, -apple-system, system-ui, Segoe UI, Roboto, Oxygen, Ubuntu, Cantarell, Open Sans, Helvetica Neue`
- **Monospace**: JetBrains Mono, with fallbacks: `ui-monospace, SF Mono, Menlo`

#### Weight System
- `400` (Regular) — 阅读文本
- `510` (Medium) — 强调/UI（Linear 签名权重）
- `590` (Semibold) — 强强调

#### Type Scale
| Role | Size | Weight | Line Height | Letter Spacing |
|------|------|--------|-------------|----------------|
| Display | 48px | 510 | 1.00 | -1.056px |
| Heading 1 | 32px | 400 | 1.13 | -0.704px |
| Heading 2 | 24px | 400 | 1.33 | -0.288px |
| Heading 3 | 20px | 590 | 1.33 | -0.24px |
| Body Large | 18px | 400 | 1.60 | -0.165px |
| Body | 16px | 400 | 1.50 | normal |
| Body Medium | 16px | 510 | 1.50 | normal |
| Small | 15px | 400 | 1.60 | -0.165px |
| Caption | 13px | 400-510 | 1.50 | -0.13px |
| Label | 12px | 400-590 | 1.40 | normal |

### 2.3 Spacing System

Base unit: 8px
Scale: 1px, 4px, 7px, 8px, 11px, 12px, 16px, 19px, 20px, 22px, 24px, 28px, 32px, 35px

Primary rhythm: 8px, 16px, 24px, 32px

### 2.4 Border Radius
| Token | Value | Usage |
|-------|-------|-------|
| `micro` | 2px | 徽章、工具栏按钮 |
| `small` | 4px | 小容器 |
| `standard` | 6px | 按钮、输入框 |
| `card` | 8px | 卡片、Dropdown |
| `panel` | 12px | 面板、特性卡片 |
| `large` | 22px | 大面板元素 |
| `pill` | 9999px | 标签、过滤器 |

### 2.5 Shadows & Elevation

On dark surfaces, shadows are nearly invisible. Linear uses:
1. **Background luminance stepping** — each level increases white opacity (0.02 → 0.04 → 0.05)
2. **Semi-transparent white borders** — primary depth indicator
3. **Inset shadows** — `rgba(0,0,0,0.2) 0px 0px 12px 0px inset` for recessed panels

### 2.6 Motion Philosophy

- **Duration**: 200-300ms for transitions
- **Easing**: `Curves.easeInOut` for most animations
- **Hover effects**: Subtle background opacity increase
- **Focus**: Multi-layer shadow stack for keyboard focus

## 3. Layout & Structure

### 3.1 Main Layout

```
┌─────────────────────────────────────────────────────────────┐
│  CollapsibleSidebar (280px expanded / 60px collapsed)     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Header: Logo + Search + Settings                    │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  Connection List                                    │   │
│  │  - Floating cards with hover glow                   │   │
│  │  - Translucent backgrounds                          │   │
│  │                                                     │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │  Bottom Bar: Collapse toggle                        │   │
│  └─────────────────────────────────────────────────────┘   │
│  │  VerticalDivider                                    │
│  │  TerminalTabsView (Expanded)                        │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  TabBar: 12px radius pills + purple indicator       │ │
│  ├───────────────────────────────────────────────────────┤ │
│  │                                                       │ │
│  │  Terminal Content (kterm)                            │ │
│  │                                                       │ │
│  ├───────────────────────────────────────────────────────┤ │
│  │  StatusBar: Translucent + compact                    │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Component Layouts

#### CollapsibleSidebar
- Width: 280px (expanded) / 60px (collapsed)
- Background: `#0f1011`
- Border: none (use luminance difference)
- Header: icon buttons with hover glow
- Bottom bar: collapse/expand toggle

#### Connection Card (Floating Style)
- Background: `rgba(255,255,255,0.03)` default, `rgba(255,255,255,0.06)` hover
- Border: `1px solid rgba(255,255,255,0.08)` on hover
- Border-radius: 8px
- Padding: 12px 16px
- Icon: 36x36 with `rgba(255,255,255,0.08)` background
- Hover: subtle purple glow using accent color

#### Terminal Tab Bar
- Height: 48px
- Background: `#0f1011`
- Tab: pill-shaped (12px radius), transparent default
- Active indicator: 2px bottom border in accent color
- Add button: ghost style with accent icon

#### Settings Page
- Left sidebar: 200px fixed, icon + text navigation
- Active item: translucent background + left accent border
- Content area: scrollable with max-width 800px

## 4. Features & Interactions

### 4.1 Sidebar Interactions
- **Collapse**: 200ms slide animation, content fades
- **Expand**: 200ms slide, search field animates in
- **Connection hover**: Background opacity 0.03 → 0.06, border appears
- **Icon button hover**: Subtle glow with accent color at 10% opacity

### 4.2 Connection List Interactions
- **Card hover**: Border becomes visible (`rgba(255,255,255,0.08)`), slight scale (1.01)
- **Card active**: Purple left border (2px)
- **Delete confirmation**: Centered modal with blur backdrop
- **Empty state**: Centered icon (64px, 20% opacity) + message

### 4.3 Terminal Tab Interactions
- **Tab hover**: Background opacity increases
- **Tab active**: 2px bottom border in accent, brighter text
- **Tab close**: X icon appears on hover
- **Add dropdown**: Ghost button style, accent color icon

### 4.4 Settings Interactions
- **Nav item hover**: Translucent background
- **Nav item active**: Left 2px accent border + translucent bg
- **Input focus**: Multi-layer shadow stack
- **Save button**: Primary accent style

## 5. Component Inventory

### 5.1 AppTheme
```dart
// Linear Color Palette
background: #08090a
panel: #0f1011
surface: #191a1b
surfaceElevated: #28282c

textPrimary: #f7f8f8
textSecondary: #d0d6e0
textTertiary: #8a8f98
textQuaternary: #62666d

accent: #5e6ad2
accentInteractive: #7170ff
accentHover: #828fff

borderSubtle: rgba(255,255,255,0.05)
borderStandard: rgba(255,255,255,0.08)
borderSolid: #23252a
```

### 5.2 LinearButton Variants

**Ghost Button**
- Background: `rgba(255,255,255,0.02)`
- Border: `1px solid #24282c`
- Text: `#e2e4e7`
- Hover: `rgba(255,255,255,0.04)` bg
- Radius: 6px

**Primary Button**
- Background: `#5e6ad2`
- Text: `#ffffff`
- Hover: `#828fff`
- Radius: 6px

**Icon Button (Circle)**
- Background: `rgba(255,255,255,0.03)`
- Border: `1px solid rgba(255,255,255,0.08)`
- Radius: 50%
- Size: 32x32 or 40x40

### 5.3 LinearCard
- Background: `rgba(255,255,255,0.03)`
- Border: `1px solid rgba(255,255,255,0.08)` (visible on hover)
- Border-radius: 8px
- Padding: 12px 16px
- Hover: border opacity increases, subtle accent glow

### 5.4 LinearInput
- Background: `rgba(255,255,255,0.02)`
- Border: `1px solid rgba(255,255,255,0.08)`
- Text: `#d0d6e0`
- Placeholder: `#62666d`
- Focus: accent border color + multi-layer shadow

### 5.5 LinearDialog
- Background: `#191a1b`
- Border: `1px solid rgba(255,255,255,0.08)`
- Border-radius: 12px
- Shadow: Multi-layer stack
- Backdrop: `rgba(0,0,0,0.85)` with blur

### 5.6 LinearTab
- Default: transparent bg, `#8a8f98` text
- Hover: `rgba(255,255,255,0.03)` bg
- Active: `#f7f8f8` text, 2px bottom border `#7170ff`
- Close icon: appears on hover

### 5.7 LinearNavigationRail
- Background: `#0f1011`
- Item default: transparent
- Item hover: `rgba(255,255,255,0.03)`
- Item active: `rgba(255,255,255,0.05)` + left 2px `#7170ff` border
- Icon size: 20px
- Label: 13px 510 weight

## 6. Technical Approach

### 6.1 File Changes

| File | Changes |
|------|---------|
| `lib/core/theme/app_theme.dart` | Complete Linear color palette + theme |
| `lib/presentation/widgets/collapsible_sidebar.dart` | Redesign with floating cards |
| `lib/presentation/widgets/connection_list.dart` | Linear card style |
| `lib/presentation/widgets/terminal_view.dart` | Tab bar + status bar redesign |
| `lib/presentation/screens/app_settings_screen.dart` | Navigation rail redesign |
| `lib/presentation/screens/connection_form.dart` | Linear form styling |
| `lib/presentation/widgets/terminal_status_bar.dart` | Translucent compact style |
| `lib/presentation/dialogs/*.dart` | Linear dialog styling |

### 6.2 Implementation Priority

1. **Phase 1**: `app_theme.dart` — new Linear color system
2. **Phase 2**: `CollapsibleSidebar` + `ConnectionList` — sidebar and cards
3. **Phase 3**: `TerminalTabsView` + `TerminalTab` — tab bar redesign
4. **Phase 4**: `TerminalStatusBar` — translucent compact style
5. **Phase 5**: `AppSettingsScreen` — navigation rail + settings panels
6. **Phase 6**: Dialogs and forms — Linear styling

### 6.3 Key Implementation Details

- Use `Theme.of(context)` extensions for Linear colors
- Create `LinearColors` class for direct color access
- Floating cards use `AnimatedContainer` for smooth hover transitions
- Semi-transparent borders replace solid dark borders
- No drop shadows on dark surfaces — use luminance stepping instead
- Status bar uses `BackdropFilter` for glass effect where appropriate

### 6.4 Spacing Constants

```dart
static const double spacing1 = 1.0;
static const double spacing4 = 4.0;
static const double spacing7 = 7.0;
static const double spacing8 = 8.0;
static const double spacing11 = 11.0;
static const double spacing12 = 12.0;
static const double spacing16 = 16.0;
static const double spacing19 = 19.0;
static const double spacing20 = 20.0;
static const double spacing22 = 22.0;
static const double spacing24 = 24.0;
static const double spacing28 = 28.0;
static const double spacing32 = 32.0;
static const double spacing35 = 35.0;
```

### 6.5 Border Radius Constants

```dart
static const double radiusMicro = 2.0;
static const double radiusSmall = 4.0;
static const double radiusStandard = 6.0;
static const double radiusCard = 8.0;
static const double radiusPanel = 12.0;
static const double radiusLarge = 22.0;
static const double radiusPill = 9999.0;
```
