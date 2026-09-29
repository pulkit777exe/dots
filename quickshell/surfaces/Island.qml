import QtQuick
import "../components"
import "../services"
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // Geometry from BarConfig
    property bool notchMode: BarConfig.notchMode
    property real notchFlare: BarConfig.notchFlare
    property real barHeight: BarConfig.barHeight
    property real collapsedWidth: BarConfig.collapsedWidth
    property real expandedHeight: BarConfig.expandedHeight
    property real gapFromEdge: BarConfig.gapFromScreenEdge

    // Expose surface items for shell.qml click-masking
    property alias leftSurfaceItem: leftDotWrap
    property alias centerSurfaceItem: centerNotchWrap
    property alias rightSurfaceItem: rightDotWrap

    implicitHeight: Math.max(leftDotWrap.height + leftDotWrap.y, Math.max(centerNotchWrap.height + centerNotchWrap.y, rightDotWrap.height + rightDotWrap.y)) + 20

    // Clock
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "hh:mm")
    }

    // Top offset based on notch mode
    readonly property real topOffset: notchMode ? 0 : gapFromEdge
    readonly property real dotSpacing: 10

    // ============================================================
    // LEFT DOT / MEDIA PLAYER
    // ============================================================
    Item {
        id: leftDotWrap
        y: root.topOffset
        // Album-art circle. Not gated on Media.hasPlayer: the collapsed dot
        // already handles the no-player case (it falls back to a music_note
        // glyph when Media.artUrl is empty), and MediaPlayerSurface has a
        // real empty state — "No media playing" with transport disabled.
        // Gating on hasPlayer hid the dot whenever nothing was playing,
        // which left the media surface unreachable by mouse.
        visible: BarConfig.albumArtCircleEnabled

        // Media Player: 406 x 214, measured off 2026-09-20_22-25-23.
        // The old 440 x 160 was 34px too wide and 54px too short, which is
        // why the panel read as a squashed rectangle with the album art
        // spilling out beside it rather than a card.
        // When collapsed: circular dot (barHeight × barHeight)
        readonly property bool isExpanded: UiState.mediaOpen
        property real targetW: isExpanded ? 406 : root.barHeight
        property real targetH: isExpanded ? 214 : root.barHeight

        width: targetW
        height: targetH

        // Where this dot sits when collapsed, and the centre of that spot.
        // Derived from barHeight rather than `width`, so it stays the
        // collapsed position even while the dot is mid-expansion.
        readonly property real collapsedX: centerNotchWrap.x - root.barHeight - root.dotSpacing
        readonly property real collapsedCentre: collapsedX + root.barHeight / 2

        // Position: collapsed, immediately left of the centre notch.
        //
        // Expanded, the panel is RIGHT-ALIGNED to this dot -- its right edge
        // stays at the dot's right edge, so the panel grows leftward out of
        // the dot and ends up hugging the notch. It used to be centred on the
        // dot, and then (for a while) centred on the island root; both put
        // the panel under or across the notch, which the reference does not
        // do.
        //
        // Measured off 2026-09-20_22-25-23, which unlike the other media
        // captures still contains the notch ("00:47") and the Wi-Fi dot, so
        // the crop's offset from the screen's centre is recoverable. The
        // notch is screen-centred, and in the crop the panel's black frame
        // spans x 40..448 while the notch begins at x 468: the panel ends
        // ~20px to the LEFT of the notch. Centred-on-root put it at 757..1163
        // and centred-on-dot at ~688..1094 -- both wrong, and both overlapping
        // the notch. Right-aligning the dot reproduces the reference's
        // relationship, which is the part that is actually pinned by it.
        // targetW, not width.
        //
        // `width` is the *animated* property -- it springs from barHeight to
        // 406 -- so binding x to it makes x a moving target for its own
        // Behavior: the two animations stack and the panel drifts before it
        // settles, which reads as the panel first appearing to the right and
        // then jumping left. targetW is the settled value, so x has one
        // target and one animation, and `Behavior on x` carries the panel
        // straight from the dot to its final place.
        x: isExpanded
            ? Math.max(root.gapFromEdge,
                Math.min(collapsedX + root.barHeight - targetW,
                         root.width - targetW - root.gapFromEdge))
            : collapsedX

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        // Stiffer than the notch's 4.8 on purpose. This x is a *chained*
        // binding: it depends on the notch's x and width, both of which are
        // themselves animating. With the same soft spring on both links the
        // dot chases a target that is still moving, which is what made the
        // dots trail and then visibly catch up whenever the island grew.
        // Tracking stiffer removes that lag. width/height stay soft, because
        // those are the dot's own expansion.
        //
        // Off entirely while the OSD is up. A volume or brightness change
        // morphs the notch from ~131px to the 275px OSD bar, and because the
        // dots are placed off the notch's edges they are dragged along with
        // it. A spring on x as well means two animations chasing one value, so
        // the dot visibly trails the OSD and then catches up after it has
        // already arrived -- a stumble rather than a move. With no behaviour,
        // x is assigned the binding's value every frame, so the dot travels
        // with the OSD in exact lockstep.
        //
        // Measured by capturing frames through a volume change and reading the
        // dot's left edge against the notch's. The gap from the notch is 39px
        // at every frame with this on. With the spring left on it the dot's
        // left edge runs 852 -> 843 -> 827 -> 791 -> 785, i.e. it arrives four
        // frames late; with it off it is 852 -> 799 -> 787 -> 785, in step
        // with the bar.
        Behavior on x {
            enabled: !MotionConfig.reduceMotion && !centerNotchWrap.isOsd
            SpringAnimation { spring: 9; damping: MotionConfig.springDamping; mass: 0.6 }
        }

        // Surface Card
        Surface {
            id: leftSurface
            anchors.fill: parent
            cornerRadius: leftDotWrap.isExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius
            topLeftRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !leftDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            // Pure black when expanded, like the control centre. Sampling
            // 2026-09-20_22-25-23 -- the media panel reference -- gives
            // (0,0,0) for the panel body, so #141414 here was lifting the
            // media panel off the desktop and out of step with its twin.
            backgroundColor: "#000000"
            shadow: leftDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Dot Content (Reference 1) ----
            Item {
                anchors.fill: parent
                visible: !leftDotWrap.isExpanded
                opacity: leftDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: dotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 2 * BarConfig.innerPadding
                    height: width
                    // Centred arithmetically rather than with anchors.centerIn:
                    // an explicit `y` on an anchored item silently wins over the
                    // anchor, which put the artwork at the dot's top edge instead of
                    // its middle. Doing the arithmetic inside the binding leaves no
                    // anchor for the hover lift to fight.
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 - (leftDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                    scale: leftDotHover.containsMouse ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    // Circular mask via native clipping — no Qt5Compat
                    // dependency (see ARCHITECTURE.md: GraphicalEffects
                    // isn't installed on the target machine and already
                    // crashed once; Surface.qml's shadow was rewritten
                    // to avoid it, this should follow the same rule).
                    Rectangle {
                        id: dotArtClip
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        clip: true
                        visible: Media.artUrl.length > 0

                        Image {
                            id: dotRawArt
                            anchors.fill: parent
                            source: Media.artUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 16
                        iconColor: Qt.rgba(1, 1, 1, 0.8)
                        visible: Media.artUrl.length === 0
                    }
                }

                MouseArea {
                    id: leftDotHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleMedia()
                }
            }

            // ---- Expanded Media Player Content (Reference 3) ----
            //
            // Slides down into place rather than scaling out of the dot.
            // The slide lives on a wrapper Item, not on MediaPlayerSurface
            // itself: that one is anchors.fill, and an explicit y on an
            // anchored item silently overrides the anchor, which would drop
            // the panel out of its Surface entirely.
            Item {
                id: mediaSlide
                anchors.fill: parent
                visible: leftDotWrap.isExpanded
                y: leftDotWrap.isExpanded ? 0 : -BarConfig.panelSlideIn
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
                }

                MediaPlayerSurface {
                    anchors.fill: parent
                    opacity: leftDotWrap.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // ============================================================
    // CENTER NOTCH / CALENDAR / SETTINGS / POPUPS
    // ============================================================
    Item {
        id: centerNotchWrap
        // Settings drops below the bar. The reference's window spans y 75..1045
        // on a 1080 screen; flush with the 11px bar gap it would start at y 11
        // and run off the bottom.
        y: isSettings ? 76 : root.topOffset
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property bool isCalendar: UiState.calendarOpen
        readonly property bool isSettings: UiState.settingsOpen
        readonly property bool isLauncher: UiState.launcherOpen
        readonly property bool isClipboard: UiState.clipboardOpen
        readonly property bool isPowerMenu: UiState.powerMenuOpen
        readonly property bool isThemePicker: UiState.themePickerOpen
        readonly property bool isWallpaperPicker: UiState.wallpaperPickerOpen
        // Volume/brightness OSD. The reference shows it as this notch
        // morphed into a 275x43 bar (2026-09-20_22-28-44.png), not as a
        // separate window floating over the desktop.
        readonly property bool isOsd: UiState.osdVisible

        // Deliberately does NOT include isOsd. This flag means "a real
        // surface is open". The OSD is a transient readout, not a surface: it
        // takes no focus, dismisses nothing, and must not cost the notch its
        // click target. Its geometry and visuals are wired up separately.
        readonly property bool isCenterExpanded: isCalendar || isSettings || isLauncher || isClipboard || isPowerMenu || isThemePicker || isWallpaperPicker

        property real targetW: {
            if (isOsd) return 275
            if (isCalendar) return UiState.calendarMonth ? 341 : 259
            if (isSettings) return 1320
            if (isLauncher) return 550
            if (isClipboard) return 480
            if (isPowerMenu) return powerInner.implicitWidth + 24
            if (isThemePicker) return themePickerContent.width + 24
            if (isWallpaperPicker) return wallpaperPickerContent.width + 24
            return root.collapsedWidth
        }

        property real targetH: {
            if (isOsd) return 43
            if (isCalendar) return UiState.calendarMonth ? 281 : 117
            if (isSettings) return 969
            if (isLauncher) return launcherContent.implicitHeight + 24
            if (isClipboard) return clipboardInner.implicitHeight + 24
            if (isPowerMenu) return powerInner.implicitHeight + 24
            if (isThemePicker) return themePickerContent.implicitHeight + 24
            if (isWallpaperPicker) return wallpaperPickerContent.implicitHeight + 24
            return root.barHeight
        }

        width: targetW
        height: targetH

        // The OSD is the one transient state: it is gone again in
        // ConfigStore.osdOnScreenTimeMs (1500ms). The shared spring 4.8 is
        // tuned for states that stay open until dismissed, and at that
        // stiffness the notch would still be visibly travelling when the OSD
        // expires. Snappier while the OSD drives the geometry.
        //
        // `isOsd` must be qualified as centerNotchWrap.isOsd: a Behavior
        // block evaluates in the animation's scope, not the item's, so the
        // bare name raises ReferenceError and the animation silently fails.
        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation {
                spring: centerNotchWrap.isOsd ? 11 : 4.8
                damping: MotionConfig.springDamping
                mass: centerNotchWrap.isOsd ? 0.6 : 0.8
            }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation {
                spring: centerNotchWrap.isOsd ? 11 : 4.8
                damping: MotionConfig.springDamping
                mass: centerNotchWrap.isOsd ? 0.6 : 0.8
            }
        }

        Surface {
            id: centerSurface
            anchors.fill: parent
            // The OSD is a fully-rounded pill -- its caps are semicircular in
            // 2026-09-20_22-28-44.png, so radius is half its 43px height. The
            // other expanded states keep the panel's 27, which is a different
            // shape (a rounded rect, not a capsule).
            cornerRadius: centerNotchWrap.isOsd
                ? centerNotchWrap.height / 2
                : (centerNotchWrap.isCenterExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius)
            topLeftRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !centerNotchWrap.isCenterExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            backgroundColor: "#000000"
            shadow: centerNotchWrap.isCenterExpanded || centerNotchWrap.isOsd

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Pill Content (Reference 1) ----
            Item {
                anchors.fill: parent
                // Original click design, unchanged: the notch's click target
                // exists only while no surface is open, so clicking it cannot
                // re-toggle or fight a surface that is already up. The OSD is
                // deliberately absent from isCenterExpanded, so a volume
                // change no longer costs the notch this target -- that was
                // the regression.
                visible: !centerNotchWrap.isCenterExpanded
                opacity: centerNotchWrap.isCenterExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                MouseArea {
                    id: notchHover
                    anchors.fill: parent
                    // The notch was the one interactive element on the bar with
                    // no hover feedback: this MouseArea had no hoverEnabled and
                    // nothing anywhere read containsMouse, so the clock gave no
                    // sign it was a target while the two dots beside it both
                    // lifted. Added to match them.
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleCalendar()
                }

                // The clock is the one thing the OSD hides, and it is gated on
                // isOsd alone rather than on this Item's visibility, so the
                // OSD can take over the notch without taking the click
                // target with it.
                //
                // Wrapped in a hover stage with the same lift and scale the
                // dots use on dotArtContainer, so all three of the bar's
                // targets behave alike.
                //
                // The stage is a sibling of the MouseArea rather than its
                // parent, for the same reason the dots lift the artwork and
                // not the hit area: lifting the MouseArea would move the
                // target out from under the cursor and flicker at the edges.
                // It is parent-sized so the default centre transform origin
                // lands on the pill's centre, which is also where the clock
                // already sits via anchors.centerIn.
                Item {
                    width: parent.width
                    height: parent.height
                    // Half the dots' stageLiftOnHover. At the full 7px the
                    // clock's top row lands on row 7, which is exactly the
                    // pill's own top row, so the glyph rides the edge and
                    // reads as clipped -- measured on a grim capture with the
                    // cursor parked on the notch. The dots can afford the
                    // full lift because their art is a 24px disc in a 30px
                    // dot that reads as rising out of the pill; the clock is
                    // ~10px of text with only ~10px of slack above it.
                    y: -(notchHover.containsMouse ? BarConfig.stageLiftOnHover / 2 : 0)
                    scale: notchHover.containsMouse ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.currentTime
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#F7EFE1"
                        visible: !centerNotchWrap.isOsd
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                    }
                }
            }

            // ---- OSD Content (Reference: 2026-09-20_22-28-44.png) ----
            // The notch morphs into this rather than a separate window
            // appearing over the desktop. Its own surface chrome is off:
            // centerSurface above is the black pill.
            OSD {
                id: osdContent
                anchors.fill: parent
                visible: centerNotchWrap.isOsd
                shadow: false
            }

            // ---- Expanded Calendar Content (Reference 4) ----
            Calendar {
                anchors.fill: parent
                visible: centerNotchWrap.isCalendar && !UiState.calendarMonth
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }

            // ---- Expanded Month Grid (Reference 2026-09-20_22-25-42) ----
            MonthCalendar {
                anchors.fill: parent
                visible: centerNotchWrap.isCalendar && UiState.calendarMonth
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
            }

            // ---- Expanded Settings Content (Reference 5) ----
            SettingsApp {
                id: settingsInner
                anchors.fill: parent
                visible: centerNotchWrap.isSettings
                opacity: centerNotchWrap.isSettings ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                borderWidth: 0
            }

            // ---- Expanded Launcher Content ----
            Launcher {
                id: launcherContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isLauncher
                opacity: centerNotchWrap.isLauncher ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                results: AppLauncher.results
                onActivated: (res) => { AppLauncher.launch(res); UiState.close(); }
            }

            // ---- Expanded Clipboard Content ----
            Item {
                id: clipboardContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isClipboard
                opacity: centerNotchWrap.isClipboard ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                ClipboardHistory {
                    id: clipboardInner
                    width: parent.width
                    shadow: false
                    backgroundColor: "transparent"
                    borderWidth: 0
                    onCloseRequested: UiState.close()
                }
            }

            // ---- Expanded PowerMenu Content ----
            Item {
                id: powerMenuContent
                anchors.fill: parent
                anchors.margins: 12
                visible: centerNotchWrap.isPowerMenu
                opacity: centerNotchWrap.isPowerMenu ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                PowerMenu {
                    id: powerInner
                    width: parent.width
                    shadow: false
                    backgroundColor: "transparent"
                    borderWidth: 0
                    onActionTaken: UiState.close()
                }
            }

            // ---- Expanded Theme Picker Content ----
            ThemePicker {
                id: themePickerContent
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12
                themes: Theme.pickerModel
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                visible: centerNotchWrap.isThemePicker
                opacity: centerNotchWrap.isThemePicker ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                onThemeSelected: (index) => { Theme.selectByPickerIndex(index); UiState.close(); }
            }

            // ---- Expanded Wallpaper Picker Content ----
            WallpaperPicker {
                id: wallpaperPickerContent
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12
                themeName: Theme.displayName
                themeKey: Theme.currentName
                wallpapers: Theme.wallpaperPickerModel
                shadow: false
                backgroundColor: "transparent"
                borderWidth: 0
                visible: centerNotchWrap.isWallpaperPicker
                opacity: centerNotchWrap.isWallpaperPicker ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                onWallpaperSelected: (idx) => { Theme.setWallpaper(idx); UiState.close(); }
            }
        }
    }

    // ============================================================
    // RIGHT DOT / CONTROL CENTER
    // ============================================================
    Item {
        id: rightDotWrap
        y: root.topOffset
        // "Status circle (battery and Wi-Fi)" toggle. Unlike the
        // album-art dot this has no "only when relevant" condition —
        // battery/Wi-Fi status is always relevant — so it's a plain
        // on/off, no Media-style gate.
        visible: BarConfig.statusCircleEnabled

        readonly property bool isExpanded: UiState.controlCenterOpen
        // 514, measured off the native 1920x1077 reference capture
        // (2026-09-20_22-27-14.png). The panel's own extent is x 703..1216
        // and y 53..566 -- 514 x 514, exactly square. What sits inside it is
        // inset 14px on every side, so the first pill starts at y 67 and the
        // last card ends at y 551; the card run x 717..1202 is 486 wide, and
        // an earlier measurement of "484 x 484 square" was reading the card
        // on both axes, which is why the two agreed and looked deliberate.
        //
        // Height is not set here: it comes from
        // controlCenterContent.implicitHeight, i.e. ControlCenter's
        // panelHeight, which is 514 to match.
        property real targetW: isExpanded ? 514 : root.barHeight
        property real targetH: isExpanded ? controlCenterContent.implicitHeight : root.barHeight

        width: targetW
        height: targetH

        // Where this dot sits when collapsed, and the centre of that spot.
        readonly property real collapsedX: centerNotchWrap.x + centerNotchWrap.width + root.dotSpacing
        readonly property real collapsedCentre: collapsedX + root.barHeight / 2

        // Position: collapsed, immediately right of the centre notch.
        // Expanded, the panel is centred on the NOTCH, not on this dot.
        //
        // Measured off 2026-09-20_22-27-14, a 1920x1077 full-screen capture
        // with the control centre open: the panel's margins sit at x ~706 and
        // ~1214, so it spans 509px centred on 960 -- the screen's centre
        // exactly, and the notch's. Dot-anchoring put it at 1041..1551,
        // 336px right of the reference.
        //
        // The notch is used rather than `root.width / 2` so the panel tracks
        // the notch if it is ever off-centre, and is clamped so a panel wider
        // than the screen still stays on it.
        // Expanded: LEFT-ALIGNED to this dot, so the panel grows rightward out
        // of the dot and stays on the right-hand side of the screen.
        //
        // This was centred on the island root, which put the panel across the
        // middle with the dot flying to meet it -- the dot visibly left the bar
        // and the panel opened somewhere it had no relationship to. It is now
        // the mirror of the left dot, which is right-aligned to its own dot so
        // it grows leftward: each panel expands outward, away from the notch,
        // and neither one crosses the centre.
        //
        // NOTE: this departs from 2026-09-20_22-27-14, which shows the control
        // centre spanning x ~706..1214, i.e. genuinely screen-centred (it was
        // the only full-screen capture with a dot panel expanded, which is why
        // it was followed until now). Centring is what the reference shows;
        // dot-anchoring is what was asked for, because the dot should not
        // appear to jump. Revert to `(root.width - width) / 2` to go back.
        // targetW, not width, for the same reason as the left dot: `width` is
        // the animated property, so binding x to it makes x a moving target
        // for its own Behavior and the two animations stack. Here the clamp is
        // not even reached (the panel fits well inside the screen), but the
        // same form keeps the two dots consistent.
        x: isExpanded
            ? Math.max(root.gapFromEdge,
                Math.min(collapsedX, root.width - targetW - root.gapFromEdge))
            : collapsedX

        Behavior on width {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        Behavior on height {
            enabled: !MotionConfig.reduceMotion
            SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
        }
        // Stiffer than the notch's 4.8 on purpose. This x is a *chained*
        // binding: it depends on the notch's x and width, both of which are
        // themselves animating. With the same soft spring on both links the
        // dot chases a target that is still moving, which is what made the
        // dots trail and then visibly catch up whenever the island grew.
        // Tracking stiffer removes that lag. width/height stay soft, because
        // those are the dot's own expansion.
        //
        // Off entirely while the OSD is up. A volume or brightness change
        // morphs the notch from ~131px to the 275px OSD bar, and because the
        // dots are placed off the notch's edges they are dragged along with
        // it. A spring on x as well means two animations chasing one value, so
        // the dot visibly trails the OSD and then catches up after it has
        // already arrived -- a stumble rather than a move. With no behaviour,
        // x is assigned the binding's value every frame, so the dot travels
        // with the OSD in exact lockstep.
        //
        // Measured by capturing frames through a volume change and reading the
        // dot's left edge against the notch's. The gap from the notch is 39px
        // at every frame with this on. With the spring left on it the dot's
        // left edge runs 852 -> 843 -> 827 -> 791 -> 785, i.e. it arrives four
        // frames late; with it off it is 852 -> 799 -> 787 -> 785, in step
        // with the bar.
        Behavior on x {
            enabled: !MotionConfig.reduceMotion && !centerNotchWrap.isOsd
            SpringAnimation { spring: 9; damping: MotionConfig.springDamping; mass: 0.6 }
        }

        Surface {
            id: rightSurface
            anchors.fill: parent
            cornerRadius: rightDotWrap.isExpanded ? BarConfig.expandedCornerRadius : BarConfig.effectiveCollapsedRadius
            topLeftRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            topRightRadius: (root.notchMode && !rightDotWrap.isExpanded) ? 0 : cornerRadius
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            // Pure black behind the expanded panel, matching the reference:
            // sampling its panel background gives (0,0,0), while the cards on
            // top are (24,22,20). #141414 was close enough to read as "dark"
            // but it lifted the whole panel off the desktop and flattened the
            // contrast against the cards. The collapsed dot was already black.
            backgroundColor: "#000000"

            shadow: rightDotWrap.isExpanded

            Behavior on cornerRadius {
                enabled: !MotionConfig.reduceMotion
                SpringAnimation { spring: 4.8; damping: MotionConfig.springDamping; mass: 0.8 }
            }

            // ---- Collapsed Dot Content (Reference 1) ----
            Item {
                anchors.fill: parent
                visible: !rightDotWrap.isExpanded
                opacity: rightDotWrap.isExpanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }

                Item {
                    id: rightDotArtContainer
                    anchors.centerIn: parent
                    width: root.barHeight - 2 * BarConfig.innerPadding
                    height: width
                    // Centred arithmetically rather than with anchors.centerIn:
                    // an explicit `y` on an anchored item silently wins over the
                    // anchor, which put the artwork at the dot's top edge instead of
                    // its middle. Doing the arithmetic inside the binding leaves no
                    // anchor for the hover lift to fight.
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 - (rightDotHover.containsMouse ? BarConfig.stageLiftOnHover : 0)
                    scale: rightDotHover.containsMouse ? 1.05 : 1.0

                    Behavior on scale {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }
                    Behavior on y {
                        enabled: !MotionConfig.reduceMotion
                        SpringAnimation { spring: 5.2; damping: MotionConfig.springDamping; mass: 0.6 }
                    }

                    // Circular Battery Ring
                    BatteryRing {
                        anchors.fill: parent
                        percentage: Battery.percentage
                        charging: Battery.charging
                        strokeWidth: 2.2
                    }

                    // Centered Wi-Fi / Status Icon
                    Icon {
                        anchors.centerIn: parent
                        icon: !Wifi.enabled ? "wifi_off" : (Wifi.connected ? "wifi" : "wifi_find")
                        size: 15
                        iconColor: Qt.rgba(1, 1, 1, 0.92)
                    }
                }

                MouseArea {
                    id: rightDotHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UiState.toggleControlCenter()
                }
            }

            // ---- Expanded Control Center Content (Reference 2) ----
            //
            // Slides down into place. The slide lives on this wrapper, not on
            // the ControlCenter itself: that one is anchors.fill, and an
            // explicit y on an anchored item silently overrides the anchor,
            // which would drop the content out of its Surface.
            Item {
                id: controlCenterSlide
                anchors.fill: parent
                visible: rightDotWrap.isExpanded

                y: rightDotWrap.isExpanded ? 0 : -BarConfig.panelSlideIn
                Behavior on y {
                    enabled: !MotionConfig.reduceMotion
                    NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
                }

                ControlCenter {
                    id: controlCenterContent
                    anchors.fill: parent
                    opacity: rightDotWrap.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
                    shadow: false
                    borderWidth: 0
                    backgroundColor: "transparent"
                }
            }
        }
    }

    // Keyboard dismiss
    Keys.onEscapePressed: UiState.closeAll()
    focus: UiState.anyOpen
    Keys.enabled: UiState.anyOpen
}
