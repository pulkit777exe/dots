# Quickshell Design System — macOS-Native Shell

> **Not a website in a window. A system tool that lives where you need it.**
> Derived from macOS native app principles, adapted to a Wayland layer-shell — KISS, event-driven, low-spec portable.

Applies to: `shell.qml` (Bar/Island + wallpaper + overlay), `surfaces/*`, `components/*`, `services/*`. Targets **Quickshell v0.3.0** + Qt 6.

---

## 1. Core Philosophy

A shell is not a destination — it **appears when needed, gets out of the way immediately after**. Every pixel is user content (windows, wallpaper); shell chrome is minimal, translucent, and interruptible.

**KISS rule:** simplest solution that works wins. No clever one-liners, no nested ternaries for layout. Junior-dev readable in 30s, `Behavior` over custom spring math where possible, `RowLayout` over manual x.

---

## 2. Layout — Shell Formula (adapted from Apple Layout Formula)

```
┌─────────────────────────────────────────────────┐
│ [Island/Notch 23:46]  ← ~34-135px, draggable, centered │  ← Top layer (exclusiveZone = collapsed only)
├─────────────────────────────────────────────────┤
│  Wallpaper (Background layer, crossfade 380ms)  │  ← Behind tiling, per-screen Variants
│  Tiled windows (Hyprland)                       │
│                                                 │
│  [Control Center / Launcher / Clipboard]        │  ← Island morph, not separate overlay
│  [Notifications top-right 380px stack]          │
│  [OSD bottom-center] [Auth scrim]               │
└─────────────────────────────────────────────────┘
```

**Island vs Notch** (`services/BarConfig.qml` → `Island.qml`):
- **Notch (`notchMode:true`)**: `y=0` flush, `topRadius=0` square top, no shadow when pill — like MacBook cutout (Image 1). For users who want maximal vertical space.
- **Island (`notchMode:false`)**: `y=gapFromScreenEdge 11px` floating pill, all corners `22-24`, `shadow 7 layers, 28px` — iPhone Dynamic Island (Image 2). Setting in `Bar & Island` page (sliders for `barHeight 34`, `collapsedWidth 190`, `expandedHeight 135`, `minExpandedWidth 619`, live via `BarConfig` singleton).

**Why single Island?** Container-transform: one `Surface` (`mainSurface`) morphs `width/height/radius/y` via `Spring 5.2/0.88`, content crossfades `110ms`. Same physical pill becomes Launcher (550px), Control Center (380px), etc. — shared-element, not new window.

**Wallpaper**: `WlrLayer.Background` per-screen `PanelWindow` + two `Image { opacity: 1-progress / progress }` crossfade 380ms `InOutCubic` + subtle scale `0.015`. Colors come from the active theme's static palette in `colors/themes/<name>/colors.json`, not hardcoded.

**When to skip sidebar:** Shell has no persistent sidebar — popovers (Control Center, Launcher) are transient. Settings app (`surfaces/SettingsApp.qml`) *does* use sidebar (200-260px, `Bar & Island | Media | Appearance | Motion...`) inside its own `Surface` — follows Apple formula only there.

---

## 3. Visual Design — System-Driven, Not Hardcoded

### Color — static themes
- **Source:** `colors/themes/<name>/colors.json` — hand-authored, `{background,surface,surfaceAlt,border,text,textMuted,accent,accentText,danger,warning,success,...}`. Wallpapers are *generated from* these palettes (`scripts/generate-theme-wallpapers.py`), never the other way around; wallpapers are discovered by `scripts/list-themes.py` from each theme's `wallpaperDir` (no sampling, no generator at runtime). `current` in `colors/index.json` names the active theme.
- **Runtime:** `Theme.qml` `colors = displayedColors` lerped `220ms OutCubic` toward `targetColors` (the active theme's `colors`). `pickerModel` accent/cardColor derived live. No dynamic/wallpaper-derived override exists.
- **Published outward:** `scripts/publish-colors.py <theme>` writes the same palette to `colors/{current.json,colors.css,colors.sh,hyprland.conf,gtk.css,kitty.conf}` and pushes Hyprland's border colours live. Run on startup and on every theme switch. Kitty is recorded but deliberately never applied.
- **Light/Dark:** Not inverted — `isDarkPreset()` on the static background (lightness <0.5). `border` carries alpha, `accentText` by luminance.

### Typography
- Stack: `-apple-system, "SF Pro Display/Text", Inter` (bundled `Inter`/`Inter Display` via `Appearance` page).
- Scale: Clock `20px` + date `11px mediaSubtitle` center, `mediaTitle 13px`, `dayLetter 11px`. Small like macOS 13px body.
- Pill clock `variant:"clock"` centered, never moves on expand (both pill + expanded `anchors.centerIn` with `horizontalCenterOffset` only when music on other workspace).

### Blur / Vibrancy
- Island `Surface` `backgroundColor: Theme.background 0.94` + `backdrop via translucency` (no `Qt5Compat.GraphicalEffects` — 7 stacked `Rectangle` shadows instead, `DeviceProfile.lowSpec ? 4 : 7` layers for low-spec).
- Top bar & popovers `0.94-0.97` alpha, `280ms` color `OutCubic`.

### Shadows — Natural (Image 2)
- `Surface.qml` layered: `shadowColor 0.32, radius 28, 7 layers, exp falloff 1.8, verticalOffset 10` → soft `0.5px border-shadow + 8px + 30px` Apple stack. Much softer than single heavy drop.

### Iconography — SF Symbols style
- `components/Icon.qml` monoline 1.5px, `16-20px` (bar `13px`, media `20px`), `currentColor`.

### Spacing — 8px grid
- Island `margins 12`, gap `8-16px`, `card 8px, button 6px, pill 14px`. `Bar & Island` sliders control `gapFromScreenEdge` live.

---

## 4. Interaction — Keyboard First, Feedback Always

**Every primary action has a shortcut + handler (both paths for portability):**
- `services/UiState.qml` `IpcHandler` (`qs -p ... ipc call shell toggleLauncher/D/N/L/S/V`) — any compositor.
- `services/CustomShortcut.qml` → `Quickshell.Hyprland GlobalShortcut` (`global, quickshell:toggleLauncher`) — Hyprland `bind = SUPER,D` etc. Also `brightnessUp/Down`, `mediaToggle/Next/Prev/Stop`, `bluetoothToggle`, `nightLightToggle`, `clearNotifs`. `onPressed: UiState.toggleX()`.

**Visual feedback:**
- Island `bounceAnim` 70ms→1.03 →130ms `OutBack` on `islandModeChanged` / new notification / media skip.
- Hover: `HoverHandler` on `shape` → `expanded` (media+calendar) `opacity 110ms`, spring `5.2/0.88`.
- Panels: `opacity 110ms` + `scale 0.96→1 130-160ms`.
- Scrim dim `0.22` `140ms` behind island when popup, click → `UiState.closeAll()`, `Esc` → close.

**Search:** Launcher is **Command Palette** (`⌘D` / `SUPER+D`) — centered `550px`, `SearchField` focused via `Qt.callLater` after `UiState` toggle, `Keys.onDown/Up` navigate, `Enter` launch, `Esc` dismiss. Results `ListRow` stagger `appearDelay 60+22*index`.

**Drag & drop:** Not needed for shell chrome, but wallpaper picker accepts drops (future): highlight `0.5px dashed accent`.

**Optimistic UI:** `Volume.setVolume` / `Brightness` immediately updates `level` + `osdRequested`, `Process` in background; toast `OSD` slides bottom-center.

---

## 5. Components — KISS Primitives (`components/`)

| Component | Role | Key props |
|---|---|---|
| `Surface.qml` | Themed card/pill/island body | `backgroundColor`, `cornerRadius` per-corner, `shadow` bool (low-spec aware) |
| `Island.qml` | Shape-morphing pill | `islandMode`, `notchMode`, `targetWidth/Height`, `wallpaperProgress` (380ms) |
| `Pill.qml` | Chip for today | `pillColor`, `childrenRect` avoided via `implicitWidth` |
| `Slider.qml` / `SettingsSliderRow` | Volume/brightness | `value 0-100`, `accentColor: Theme.accent` |
| `Toggle.qml` | Switch | `checked`, `accentColor` |
| `ListRow.qml` | Launcher/ControlCenter row | `icon, title, subtitle, selected` |
| `Cava` (`services/Cava.qml`) | 3-bar visualizer | `levels[3] 0-1`, `available`, `framerate 15/30` via `DeviceProfile` |

All components `Theme.colors.*` reactive, no polling, `Behavior` disabled when `MotionConfig.reduceMotion` or `DeviceProfile.lowSpec`.

---

## 6. Motion — Respects System

`services/MotionConfig.qml` (`reduceMotion`, `movement 400ms`, `fades 200ms`, `hover 150ms`, `bounce 40% → springDamping 0.25-0.7`) drives `Island`/`Bar` springs. `DeviceProfile.qml` probes `/proc/meminfo` + `nproc` → `lowSpec` (<4GB or ≤2 cores) halves `cava framerate`, `Surface` layers `7→4`, disables `ddcutil` detect (`bash -c "command -v ddcutil && ddcutil..."`) to avoid `Process failed to start` warn (now silent). `shouldReduceMotion = lowSpec`.

---

## 7. Portability — Event-Driven

- **Wayland:** `WlrLayershell` `Top/Overlay/Background`, `Region` mask, `IdleInhibitor` etc; **X11 fallback** via `PanelWindow` `screen: modelData` (no `layer` needed).
- **Compositor:** Hyprland `GlobalShortcut` + generic `IpcHandler` (works on Sway/Mutter).
- **Files:** `Quickshell.statePath` (`~/.local/state/...`) not `shellDir + "/state"`; `FileView printErrors:false` for first-run missing `bar/motion-config.json` (no WARN), `watchChanges` + `inotifywait -m -q -r` with `sleep 10` poll fallback, debounced 400ms.
- **Dependencies:** `command -v` checks for `ddcutil/asdbctl`, `brightnessctl` fallback poll `0.5s`, `nmcli monitor` `200ms` debounce, `bluetoothctl` persistent `SplitParser`.

---

## 8. Checklist for New Surfaces

1. Use `Surface` + `Theme.colors`, not raw `Rectangle` + hex.
2. Drive via `UiState`/`service` prop, not polling; add `IpcHandler` + `CustomShortcut` if user-triggered.
3. Animate `opacity + scale` `110-160ms OutCubic`, `width/height` spring `5.2/0.88` if morphing, respect `reduceMotion`.
4. Provide empty state (`Search Settings` placeholder) and `Esc` to dismiss.
5. Test `notchMode` toggle + `collapsedWidth` live, and `DeviceProfile.lowSpec` (force `QUICKSHELL_LOW_SPEC=1`).

*No hardcoding: wallpapers from the filesystem, colors from each theme's hand-authored `colors.json`, everything reloads on `themes/` change.*
