import QtQml

// The two row lists the island's pickers render: one entry per discovered
// theme, one per wallpaper of the current theme.
//
// These are the pickers' data contract, so they live apart from the state they
// are built from. Both functions are pure: presets, the current key, the
// saved indices and the fallback palette go in, rows come out. Nothing is
// read back out, so nothing here has to know that Theme.qml is the one asking.
//
// The swatch order is fixed: ThemePicker renders swatchColors with a
// Repeater, which is positional, so reordering this list changes which
// colour lands in which dot and nothing downstream would notice.

QtObject {
    id: rows

    // A wallpaper path as a URL an Image can load. Absolute paths and
    // already-qualified URLs pass through; a bare filename is taken as
    // relative to colors/. list-themes.py resolves every wallpaper it
    // reports, so the last branch is a fallback for a hand-written index
    // rather than a path anything reaches today.
    function fileUrl(path, colorsRoot) {
        if (!path) return "";
        const s = path.toString();
        if (s.startsWith("file://")) return s;
        if (s.startsWith("/")) return "file://" + s;
        return "file://" + colorsRoot + "/" + s;
    }

    // One row per theme, in Object.keys order, with the colours the picker
    // paints each card from. A theme missing an optional key falls back to
    // the degraded-mode palette (`fallback`, passed in by Theme) rather than
    // to undefined, which is what a card would render as. Note the pairs that
    // fall through each other first -- danger through error, textMuted
    // through muted: both spellings are in the palettes, and a theme carrying
    // one of the pair should still get a colour.
    function themeRows(presets, currentName, fallback) {
        let out = [];
        for (let key in presets) {
            const t = presets[key];
            const accent = (t.colors && t.colors.accent) ? t.colors.accent : fallback.accent;
            const bg = (t.colors && t.colors.background) ? t.colors.background : fallback.background;
            out.push({
                key: key,
                name: t.name ? t.name : key,
                accent: accent,
                cardColor: bg,
                selected: key === currentName,
                swatchColors: [
                    (t.colors && (t.colors.danger || t.colors.error)) ? (t.colors.danger || t.colors.error) : accent,
                    (t.colors && t.colors.success) ? t.colors.success : accent,
                    (t.colors && t.colors.warning) ? t.colors.warning : accent,
                    (t.colors && (t.colors.muted || t.colors.textMuted)) ? (t.colors.muted || t.colors.textMuted) : accent,
                    (t.colors && t.colors.accentVariant) ? t.colors.accentVariant : ((t.colors && t.colors.error) ? t.colors.error : accent),
                    (t.colors && t.colors.accent) ? t.colors.accent : accent
                ],
            });
        }
        return out;
    }

    // One row per wallpaper of the current theme. `savedIndex` is the whole
    // per-theme map, not one number, because the index is stored per theme
    // key: switching themes has to come back to the wallpaper that theme was
    // left on, and the picker has to mark it selected.
    //
    // The selected index is clamped to the list, so a saved index from a
    // wallpaper that has since been deleted marks the last row rather than
    // nothing at all.
    function wallpaperRows(presets, currentName, savedIndex, colorsRoot) {
        const theme = presets[currentName];
        const wallpapers = (theme && theme.wallpapers) ? theme.wallpapers : [];
        const saved = Number(savedIndex[currentName] !== undefined ? savedIndex[currentName] : 0);
        const selectedIndex = wallpapers.length > 0
            ? Math.min(saved, wallpapers.length - 1)
            : -1;

        const out = [];
        for (let index = 0; index < wallpapers.length; index++) {
            const path = wallpapers[index];
            out.push({
                themeKey: currentName,
                source: fileUrl(path, colorsRoot),
                fileName: String(path).split("/").pop(),
                selected: index === selectedIndex
            });
        }
        return out;
    }
}
