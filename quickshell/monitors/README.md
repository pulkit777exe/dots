# Per-monitor bar overrides

A monitor can have its own bar geometry without touching the global settings.

Drop a JSON file named after the monitor in this directory:

```
~/.config/quickshell/monitors/eDP-1.json
```

The name is exactly what Hyprland reports, which is also what
`hyprctl monitors` prints. Unplug the monitor, delete or ignore the file,
and the bar is back to the global values — nothing is copied out of the
global settings, so the two can never disagree.

## Example

```json
{
    "barHeight": 34,
    "gapFromScreenEdge": 11
}
```

Only the keys you list change. Everything else keeps the value from
`bar-config.json`.

## What may be overridden

Geometry only:

| key | |
|---|---|
| `barHeight` | height of the resting bar |
| `collapsedWidth` | width of the resting dot pills |
| `expandedHeight` | height budget for an expanded panel |
| `minimumExpandedWidth` | width a panel must reach before it is usable |
| `gapFromScreenEdge` | distance from the top edge |
| `expandedCornerRadius` | corner radius of an open panel |
| `collapsedCornerRadius` | corner radius of a resting pill |
| `notchFlare` | how far the notch flares |

All values must be finite numbers. A string, `null`, or a non-number is
rejected.

## What may not, and why

These stay global on purpose. A per-monitor copy of any of them would be a
second source of truth for something that is not a property of the monitor:

- `notchMode`, `statusCircleEnabled`, `albumArtCircleEnabled` — which parts
  of the bar exist at all. Two monitors with different sets of parts reads
  as a bug rather than a preference.
- `panelSlideIn`, `stageLiftOnHover`, `innerPadding` — motion and padding,
  tuned as one set against the global bar height. Splitting them per monitor
  means a height override silently changes how the animation feels.

Anything else in the file is ignored, and the shell says so on startup:

```
BarConfigMonitors: eDP-1.json ignored notchMode, bogusKey, collapsedWidth
(not a finite number) -- only geometry may be overridden per monitor
```

That is deliberate. A typo should not quietly do nothing.

## Verifying

`./scripts/lint.sh` does not check these files, since they are optional and
per-machine. To confirm one is being read, the shell logs a warning naming
any key it rejected; a file with no rejected keys logs nothing, which means
it was accepted.

The simplest check is to compare the bar's height with and without the file.
A wrong `barHeight` is obvious immediately.
