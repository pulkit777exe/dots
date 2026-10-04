import QtQml

// Colour arithmetic for Theme.qml: parse a hex string, blend two of them,
// measure one, fade one.
//
// Nothing here reads Theme and nothing here touches I/O. Every function is a
// pure map from hex strings (and one palette object) to another, which is
// what lets Theme delegate to it without a circular import -- and it is why
// the degraded-mode palette stays in Theme: this file has no opinion about
// what the colours are, only about what arithmetic on them means.
//
// The literals are all in Theme.qml. The thresholds here are the ones
// Theme.qml used before this moved: 0.5 for the dark/light midpoint, and
// nothing else.

QtObject {
    id: math

    // "#abc" and "#aabbcc" both parse; the short form is expanded first.
    function hexToRgb(hex) {
        let h = hex.replace("#", "");
        if (h.length === 3) h = h.split("").map(ch => ch + ch).join("");
        const num = parseInt(h, 16);
        return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 };
    }

    function toHex(r, g, b) {
        const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
        const pad = (v) => clamp(v).toString(16).padStart(2, "0");
        return "#" + pad(r) + pad(g) + pad(b);
    }

    // (max + min) / 2 of the three channels, unweighted. This is the only
    // brightness measurement in the tree, and its one caller is a midpoint
    // test, so there is nothing here to gain from a perceptual weighting.
    function hexLightness(hex) {
        const c = math.hexToRgb(hex);
        const r = c.r / 255, g = c.g / 255, b = c.b / 255;
        return (Math.max(r, g, b) + Math.min(r, g, b)) / 2;
    }

    // One colour at parameter t between a and b.
    //
    // Qt hands colours back as #AARRGGBB and a palette entry may carry that
    // form, so a 9-character hex is alpha FIRST. If either side has one the
    // blend keeps an alpha byte and interpolates it alongside the channels;
    // if neither does the result stays 6 characters. Treating a 9-character
    // hex as #RRGGBBAA would shift every channel by a byte.
    function lerpHex(a, b, t) {
        let hasAlpha = a.length === 9 || b.length === 9;
        let ah = a, bh = b;
        let aAlpha = 1, bAlpha = 1;
        if (ah.length === 9) { aAlpha = parseInt(ah.slice(1,3),16)/255; ah = "#" + ah.slice(3); }
        if (bh.length === 9) { bAlpha = parseInt(bh.slice(1,3),16)/255; bh = "#" + bh.slice(3); }
        const ca = math.hexToRgb(ah), cb = math.hexToRgb(bh);
        const r = Math.round(ca.r + (cb.r - ca.r) * t);
        const g = Math.round(ca.g + (cb.g - ca.g) * t);
        const b_ = Math.round(ca.b + (cb.b - ca.b) * t);
        const hex = math.toHex(r,g,b_);
        if (hasAlpha) {
            const alpha = Math.round((aAlpha + (bAlpha - aAlpha)*t)*255);
            return "#" + alpha.toString(16).padStart(2,"0") + hex.slice(1);
        }
        return hex;
    }

    // A whole palette at parameter t. Keys are the union of both sides, so a
    // key one palette has and the other lacks does not vanish mid-transition;
    // a non-colour value snaps at the halfway point rather than blending into
    // something neither palette ever had.
    //
    // `fallback` is Theme's degraded-mode palette, passed in rather than
    // read: reading it here would make this file depend on Theme, which is
    // the circular import this split exists to avoid.
    function interpolate(from, to, t, fallback) {
        if (!from || !to) return to ? to : (from ? from : fallback);
        let out = {};
        const keys = new Set([...Object.keys(from), ...Object.keys(to)]);
        for (const k of keys) {
            const fv = from[k], tv = to[k];
            if (typeof fv === "string" && typeof tv === "string" && fv.startsWith("#") && tv.startsWith("#")) {
                out[k] = math.lerpHex(fv, tv, t);
            } else out[k] = t < 0.5 ? fv : tv;
        }
        return out;
    }

    // The production idiom for a translucent colour, and the reason Theme.qml
    // keeps a withAlpha() of its own: 134 call sites across the tree say
    // Theme.withAlpha(Theme.colors.text, 0.12) rather than reaching for
    // Qt.alpha() themselves, so this is where the shape of the answer is
    // decided -- alpha first, "#aarrggbb", which is the form Qt parses back
    // as a colour. An 8-character input is already in that form and keeps its
    // six hex digits; a 6-character one is "#rrggbb" and gets the alpha in
    // front of it.
    function withAlpha(c, alpha01) {
        let h = String(c).replace("#", "");
        if (h.length === 8) h = h.slice(2);
        const a = Math.max(0, Math.min(255, Math.round(alpha01 * 255)));
        return "#" + a.toString(16).padStart(2, "0") + h;
    }

    // Dark enough to want a light foreground. `fallbackBackground` answers the
    // palette-has-no-background case: Theme passes fallbackColors.background,
    // which is the same value the inline default was before this moved.
    function isDark(palette, fallbackBackground) {
        const bg = (palette && palette.background) ? palette.background : fallbackBackground;
        return math.hexLightness(bg) < 0.5;
    }
}
