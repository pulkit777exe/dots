import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// BarIslandPage
// The reference's row set, in its order, with nothing added:
//   Notch mode, Bar height, Collapsed width, Expanded height, Gap from screen
//   edge, Inner padding, Corner radius, Corner radius (expanded), Status
//   circle, Album art circle, Stage lift on hover.
//
// Every row is separated by a SettingsDivider -- that is the reference's own
// rhythm, not a fence around just the toggles.
//
// "Notch flare" used to sit second. It is a real BarConfig setting and still
// one, but the reference has no row for it, so the page no longer shows it.
ColumnLayout {
    id: root
    spacing: 12

    SettingsHeader {
        icon: "crop_landscape"
        title: "Bar & Island"
        subtitle: "Shape and size of the island, the notch, and the Game Mode bar."
    }

    SettingsCard {
        SettingsToggleRow {
            label: "Notch mode"
            checked: BarConfig.notchMode
            onToggled: (v) => BarConfig.setNotchMode(v)
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Bar height"
            value: BarConfig.barHeight
            from: 24; to: 56; suffix: " px"
            onMoved: (v) => BarConfig.setBarHeight(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Collapsed width"
            value: BarConfig.collapsedWidth
            from: 60; to: 240; suffix: " px"
            onMoved: (v) => BarConfig.setCollapsedWidth(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Expanded height"
            value: BarConfig.expandedHeight
            from: 80; to: 220; suffix: " px"
            onMoved: (v) => BarConfig.setExpandedHeight(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Gap from screen edge"
            value: BarConfig.gapFromScreenEdge
            from: 0; to: 40; suffix: " px"
            onMoved: (v) => BarConfig.setGapFromScreenEdge(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Inner padding"
            value: BarConfig.innerPadding
            from: 0; to: 12; suffix: " px"
            onMoved: (v) => BarConfig.setInnerPadding(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            // Clamped to barHeight / 2 downstream (effectiveCollapsedRadius),
            // so the dot can't be given a radius larger than its own half-height.
            label: "Corner radius"
            value: BarConfig.collapsedCornerRadius
            from: 0; to: 40; suffix: " px"
            onMoved: (v) => BarConfig.setCollapsedCornerRadius(Math.round(v))
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Corner radius (expanded)"
            value: BarConfig.expandedCornerRadius
            from: 12; to: 40; suffix: " px"
            onMoved: (v) => BarConfig.setExpandedCornerRadius(Math.round(v))
        }

        SettingsDivider {}

        SettingsToggleRow {
            label: "Status circle (battery and Wi-Fi)"
            checked: BarConfig.statusCircleEnabled
            onToggled: (v) => BarConfig.setStatusCircleEnabled(v)
        }

        SettingsDivider {}

        SettingsToggleRow {
            label: "Album art circle while a player is open"
            checked: BarConfig.albumArtCircleEnabled
            onToggled: (v) => BarConfig.setAlbumArtCircleEnabled(v)
        }

        SettingsDivider {}

        SettingsSliderRow {
            label: "Stage lift on hover"
            value: BarConfig.stageLiftOnHover
            from: 0; to: 20; suffix: " px"
            onMoved: (v) => BarConfig.setStageLiftOnHover(Math.round(v))
        }
    }
}
