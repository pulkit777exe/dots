# Themed Polkit Agent -- separate subproject, not a QML file

Confirmed decision: build a themed agent rather than leaving the native one.
Being upfront about scope before you wire this into your workflow: **this is
not something that lives inside the Quickshell shell as another QML
component.** It's a standalone background service that races to register
`org.freedesktop.PolicyKit1.AuthenticationAgent1` on D-Bus before any other
agent does, and it must keep running independently of whether the Island
itself is up.

## Why this can't just be `PolkitDialog.qml`

- Polkit expects exactly one agent registered per session. If
  `polkit-gnome-authentication-agent-1` (or KDE's equivalent) is already
  autostarting in your Hyprland session, it'll grab the registration first --
  check your current autostart list and remove/disable it before this can
  take over.
- The agent needs to implement the `Identity`, `BeginAuthentication`,
  `CancelAuthentication` D-Bus methods -- this is most commonly done via
  `polkit-qt6` (C++ bindings) with a thin QML front-end for the dialog itself,
  not pure QML/JS talking to D-Bus directly. Pure-QML D-Bus servers for this
  specific interface are not a well-trodden path; expect to write or vendor a
  small C++ shim.
- Password entry in this dialog is a genuine trust boundary -- restyle
  colors/chrome freely against `Theme.colors`, but don't change *what
  information is shown* (the action being authorized, the user, the
  password field itself). That's the one place in this whole project I'd
  push back hard on customization for its own sake.

## Suggested path

1. Confirm what's currently registered: `ps aux | grep -i polkit` and check
   Hyprland's `exec-once` lines.
2. Start from an existing polkit-qt6 example agent (there are minimal
   reference implementations in the KDE/LXQt ecosystems) rather than from
   scratch -- the D-Bus interface plumbing is fiddly and well-solved already.
3. Once the agent authenticates and shows *a* dialog, that's the point to
   swap in `Theme.colors` for its background/accent/text -- the same JSON
   files this whole project already reads, so the palette stays in sync
   automatically as long as this agent also reads `themes/<active>.json` (or
   the same `~/.cache/island/hyprlock-colors.conf` hand-off used for
   hyprlock).

This is scoped out of the main Island tree deliberately -- it's a different
language/build story (likely C++ + qmake/CMake) and shouldn't block shipping
the Island itself.
