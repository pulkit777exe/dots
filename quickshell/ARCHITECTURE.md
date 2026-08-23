# Island System Architecture — Fedora + Hyprland + Quickshell

Status: draft v1, based on reference screenshots + owner decisions below.
Tagging convention: CONFIRMED (owner decided) / INFERRED (my recommendation, not yet confirmed) / UNKNOWN (needs a decision before implementation).

---

## 1. Core principle: two singletons, not one

State splits into two orthogonal concerns. Don't merge them.

```
Theme.qml        → WHAT COLORS + METRICS (palette, font size, bar height)
IslandState.qml  → WHAT SHAPE + WHICH PANEL (idle, expanded, wifi panel, ...)
```

`IslandState` reads `Theme` but never writes it. `Theme` never knows about panels.
This is the "single source of truth" split — every QML view binds to these two
singletons and nothing else holds its own copy of color or shape state.

---

## 2. Theme system

**CONFIRMED (owner):** Each theme is a *fixed palette* tied to a *curated set of
wallpapers with a similar feel*. Switching wallpaper within a theme does **not**
change colors. Switching theme swaps both palette and available wallpaper set.
Use standard/published color specs where they already exist rather than
reinventing them.

### 2.1 Data shape

```json
// themes/catppuccin.json
{
  "name": "catppuccin",
  "variant": "mocha",           // INFERRED: most named themes have light/dark or accent variants — decide per-theme
  "colors": {
    "bg": "#1e1e2e",
    "surface": "#313244",
    "surfaceHover": "#45475a",
    "accent": "#89b4fa",
    "text": "#cdd6f4",
    "textMuted": "#a6adc8",
    "danger": "#f38ba8",
    "success": "#a6e3a1",
    "warning": "#f9e2af"
  },
  "wallpapers": [
    "catppuccin/swirl.png",
    "catppuccin/city-dusk.png",
    "catppuccin/cave.png",
    "catppuccin/rose.png",
    "catppuccin/kaleidoscope.png"
  ]
}
```

`Theme.qml` loads all `themes/*.json` at startup, exposes `Theme.active` (current
theme object) and `Theme.colors` (shorthand into `active.colors`). Switching
theme = swap `Theme.active`; every bound `color:` property updates via QML's
property binding, no manual repaint logic needed.

### 2.2 Which themes have a real spec vs. need defining

From the picker (Image 9), sorted:

| Theme | Status |
|---|---|
| catppuccin-mocha | CONFIRMED spec exists (official Catppuccin Mocha palette) |
| catppuccin-macchiato | CONFIRMED spec exists (official Catppuccin Macchiato palette) |
| catppuccin-frappe | CONFIRMED spec exists (official Catppuccin Frappé palette) |
| catppuccin-latte | CONFIRMED spec exists (official Catppuccin Latte palette) |
| gruvbox | CONFIRMED spec exists (official Gruvbox palette) |
| gruvbox-material | CONFIRMED spec exists (community fork, published hex) |
| everforest | CONFIRMED spec exists (official palette) |
| horizon | CONFIRMED spec exists (published Horizon theme palette) |
| anime | UNKNOWN — not a standard spec, needs a custom palette + you supply/curate wallpapers |
| ariadne | UNKNOWN — not a recognized standard name, needs a custom palette definition |
| e-ink | CONFIRMED direction: near monochrome, extremely high contrast — palette drafted below |
| industrial | CONFIRMED direction: charcoal/steel/warning-accent — palette drafted below |

### 2.2a Drafted palettes for the four custom themes

Direction given: anime = vivid accent + deep cinematic bg. ariadne = restrained
dark/editorial. e-ink = near-monochrome, extreme contrast. industrial =
charcoal/steel/warning-accent. Review these hexes before they go in as
`themes/*.json` — easy to tweak now, annoying once wired everywhere.

```json
// themes/anime.json — deep cinematic bg, vivid magenta accent
{
  "name": "anime",
  "colors": {
    "bg": "#0d0b14", "surface": "#1a1625", "surfaceHover": "#2a2338",
    "accent": "#ff2e88", "text": "#f1eaff", "textMuted": "#a99bc4",
    "danger": "#ff4d6d", "success": "#4ade80", "warning": "#ffb703"
  }
}

// themes/ariadne.json — restrained, warm editorial dark
{
  "name": "ariadne",
  "colors": {
    "bg": "#14120f", "surface": "#1f1c18", "surfaceHover": "#2a2620",
    "accent": "#8c3b3b", "text": "#e8e2d6", "textMuted": "#948a7a",
    "danger": "#a63d40", "success": "#6b8f71", "warning": "#c9a227"
  }
}

// themes/e-ink.json — near-monochrome, max contrast
{
  "name": "e-ink",
  "colors": {
    "bg": "#f5f5f0", "surface": "#e8e8e3", "surfaceHover": "#d8d8d2",
    "accent": "#111111", "text": "#111111", "textMuted": "#555550",
    "danger": "#111111", "success": "#111111", "warning": "#111111"
  }
}
// Note: danger/success/warning are true mono (#111111). Toggle ON vs OFF
// is carried by icon/shape changes rather than color distinction.

// themes/industrial.json — charcoal/steel, hazard-amber accent
{
  "name": "industrial",
  "colors": {
    "bg": "#1c1e1f", "surface": "#26292b", "surfaceHover": "#34383a",
    "accent": "#f4a300", "text": "#d8dadb", "textMuted": "#8b9194",
    "danger": "#d64545", "success": "#4c9a6a", "warning": "#f4a300"
  }
}
// Note: warning === accent here on purpose — the theme's whole identity is
// the hazard-amber color, so a "warning" state doesn't stand out from the
// chrome the way it does in other themes. Fine for a themed toggle grid,
// worth double-checking once actual warning banners (e.g. low battery) exist.
```

Action item resolved: all 9 theme palettes now have hex values, real or
drafted for review.

### 2.3 Metrics (separate from color)

`Theme.barHeight` and `Theme.fontSize` are flat properties on the singleton
(Image 11: 37px bar height, 15px font size shown) — these are Island chrome
dimensions, user-adjustable via sliders, and are **not** part of a theme's
identity (a theme swap shouldn't silently resize your bar). Persisted
independently of `Theme.active`.

---

## 3. Island state machine

**CONFIRMED (owner):** Idle pill → Control Center is triggered by **hover with
delay** (macOS-style), not click.

### 3.1 States

| State | Enter trigger | Exit trigger | Notes |
|---|---|---|---|
| `idle` | boot, or auto-collapse | hover-intent (delay ~300–500ms), new notif, media change, volume/brightness key | compact pill: art + track + clock + date + wifi + battery |
| `mediaChange` | MPRIS `TrackChanged` while idle | ~2–3s no further change → `idle` | same pill, art/title cross-fade |
| `volumeToast` | wpctl volume/mute change | ~1.2–1.5s no further change → `idle` | Image 3 shape — icon + slider + % |
| `brightnessToast` | brightness key | same timeout pattern | same shape family as volume |
| `notifToast` | D-Bus notification | ~4s, or user clicks to open `expanded` at notification list | Image 4 — queues if multiple arrive; single `NotificationModel` shared with the persistent list in `expanded` |
| `expanded` | **hover-intent on `idle`, OR `Super+Space`**, OR click on any toast | mouse-leave + delay, or Esc | Image 2 — Control Center: toggle grid, sliders, media scrubber, notification list. `Super+Space` also covers the no-mouse-fallback need from earlier. |
| `panel:wifi` / `panel:bluetooth` / `panel:audio` | tap toggle row inside `expanded` | back arrow (pops stack) | pushed onto `IslandState.panelStack`; only one deep in the reference shots but design the stack for N deep |
| `launcher` | **`Alt+Space`** | Esc, or app launched | Image 5 — **CONFIRMED top-level**, entirely separate from `expanded`'s panel stack, its own keybind |
| `settings` | nav row from `expanded` | back arrow | Image 11 |
| `theme` | nav from `settings`, **OR `Super+T` directly** | back arrow, or theme selected | Image 9 — theme cards as shown, grid + live swatch bar per card |
| `wallpaper` | nav from `settings` (scoped to active theme), **OR `Super+W` directly** | back arrow, or wallpaper selected | Image 10 |
| `power` | nav or keybind | any action taken, or Esc | Image 12 — flat row, no further nesting |
| `locked` | Hypridle timeout / manual lock action | successful password entry | **separate top-level surface (Hyprlock), not part of the Island panel stack at all** — see §4 |

### 3.2 Hover-intent details (needs building, not just triggering)

- Enter delay: small delay before expanding, so a mouse merely passing over the
  bar doesn't trigger it. INFERRED default: 350ms.
- Exit delay: separate delay before collapsing back to `idle` on mouse-leave,
  so moving from the pill down into the Control Center grid doesn't
  re-trigger idle mid-motion. INFERRED default: 250ms, cancellable if mouse
  re-enters.
- Sub-panels (`panel:wifi` etc.) should **not** re-run the outer hover-intent
  delay — once expanded, navigation inside should feel instant (click-driven,
  not hover-driven).
- Non-mouse fallback (INFERRED, needs a decision): a keybind should still be
  able to force-open `expanded` for users without a pointer handy, or for
  reduced-motion/accessibility settings.

---

### 3.3 One wrinkle from the direct keybinds

`Super+T` and `Super+W` can now open `theme`/`wallpaper` **without** going
through `settings` first. That means "back arrow" can't just be hardcoded to
"go to settings" — it needs to pop whatever's actually on `panelStack`. If
`theme` was pushed directly (stack = `[theme]`), back arrow should land on
`idle`/closed. If it was pushed via settings (stack = `[settings, theme]`),
back arrow lands on `settings`. This falls out naturally if `panelStack` is a
real stack rather than a fixed hierarchy — worth calling out explicitly to
the coding agent since it's an easy thing to hardcode wrong.

## 4. Hyprlock (separate surface)

**Confirmed by reference (Image 15):** Hyprlock is its own process, launched
independently by Hypridle — it cannot bind directly to the running Quickshell
`Theme` singleton at runtime.

**CONFIRMED (owner):**

```
Theme.colors  ──────────────→ Hyprlock   (flows through)
Theme.metrics ──✕───────────→ Hyprlock   (does NOT flow through)
```

So Hyprlock always mirrors the active theme's palette, but keeps its own fixed
typography/sizing regardless of what the Island's bar-height/font-size
sliders are set to (Image 15's clock size is independent of Image 11's
settings).

Implementation: on every theme change, write the active theme's colors to
`~/.cache/island/hyprlock-colors.conf` (or regenerate `hyprlock.conf` directly
via a template), so Hyprlock always reads the *last written* palette on next
lock — it's a cold process each time, so this has to be a file on disk, not
an in-memory read.

---

## 5. Themed Polkit agent (separate subproject)

**CONFIRMED (owner):** build a themed QML polkit agent rather than leaving it
native.

Scope notes (INFERRED, flagging before work starts):

- This is a background **service**, not a view inside the Island's panel
  stack — it registers as `org.freedesktop.PolicyKit1.AuthenticationAgent1`
  over D-Bus and must be running before any privileged action is requested
  (Image 13's trigger was `pacman -Syu` via `pkexec`/GUI wrapper).
- Typical implementation path: `polkit-qt6` bindings + a small QML window,
  OR a standalone `Quickshell` window reusing `Theme.qml` for color only
  (recommended, since it lets it inherit your palette for free) while keeping
  its own security-critical logic separate from the rest of the Island's
  panel-stack code — auth dialogs shouldn't share a codepath with, e.g., the
  wallpaper picker.
- Needs to replace whatever agent currently auto-registers on your system
  (check for `polkit-gnome-authentication-agent-1` or similar in your
  Hyprland autostart — if one is currently running, it'll fight for the
  D-Bus registration).
- Visual restyling is fine; I'd avoid changing the *information* shown
  (action requested, user, password field) since that's a trust signal users
  rely on to know they're looking at a real auth prompt.

---

## 6. Open items before this goes to a coding agent

Resolved: palette hexes (§2.2a), Hyprlock/metrics split (§4), keybinds (§3.2),
launcher top-level status (§3.2), back-navigation stack behavior (§3.3),
Catppuccin variant handling (separate JSON per flavor).

Still open:

1. Keybind conflicts: confirm `Super+Space`, `Alt+Space`, `Super+T`,
   `Super+W`, `Super+S`, `Super+P` don't collide with anything already
   bound in your Hyprland config for window management.
