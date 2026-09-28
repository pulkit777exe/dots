import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// SettingsCard
// The panel that groups a page's settings rows. Pages put rows in as direct
// children; they stack in a ColumnLayout with no gap, and separate them with
// SettingsDivider, which is how the reference groups them -- one card holding
// several rows with hairline rules between, not a column of floating rows.
Surface {
    id: root

    // Rows go in here and stack in order.
    default property alias content: col.data

    // Asymmetric on purpose. Measured off 2026-09-20_22-30-18:
    //   horizontal -- 14. The card's fill starts at x 545 and its first
    //     divider at x 559, and the row labels start at 560 -- flush with the
    //     divider. A uniform 18 inset pushed the content 4px further in.
    //   vertical   -- 0. The card's top edge and its first row's top edge are
    //     the same y: the reference's Notch mode label centre (312) is exactly
    //     half a 44px toggle row below the card's top (291). With 18 of
    //     vertical padding every card ran 36px past the reference -- the
    //     Notifications card came out 328 tall against the reference's 310.
    property int paddingH: 14
    // 2 rather than 0: at 0 the Notifications cards came out 292 and 123 tall
    // against the reference's 298 and 127. 2 spreads that 4-6px shortfall
    // across both edges (296 / 127) instead of dumping it all on one.
    property int paddingV: 2

    implicitHeight: col.implicitHeight + paddingV * 2
    Layout.fillWidth: true
    cornerRadius: 16
    // (16,14,12) -- measured off 2026-09-20_22-30-18. A warm white at 6.3%,
    // not a neutral one: the reference's cast is r16 g14 b12, and a flat
    // rgba(1,1,1,a) gives r=g=b and reads greyer than the reference.
    backgroundColor: Qt.rgba(1, 0.875, 0.75, 0.063)
    borderWidth: 0
    shadow: false

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.leftMargin: root.paddingH
        anchors.rightMargin: root.paddingH
        anchors.topMargin: root.paddingV
        anchors.bottomMargin: root.paddingV
        spacing: 0
    }
}
