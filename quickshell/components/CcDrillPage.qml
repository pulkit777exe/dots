import QtQuick
import "../services"


// CcDrillPage.qml -- the frame a control-centre drill page scrolls in.
//
// All four pages were siblings in ControlCenter.qml and each one restated the
// same eleven lines: a width derived from the panel minus an inset, a height
// taken from the panel, the slide-in offset, the fade, and the two Behaviours
// on them. They differed only in the inset (22 for sound and display, 10 for
// bluetooth and wifi) and in what was inside. That is this file.
//
// It stops short of being a base class on purpose: `contentHeight` is left to
// each page to bind to its own column, because that binding is what the panel
// reads to decide how tall to be, and a frame that supplied it would have to
// guess which child to measure.

Flickable {
    id: page

    // Which page is showing. ControlCenter owns this; nothing here reads the
    // view name.
    property bool open: false

    // Where the panel puts this page. `panelX` is the panel's own x, which is
    // not zero -- the panel is anchored inside the island's right dot wrapper.
    property real panelX: 0
    property real panelWidth: 0

    // How far down the panel the drill area starts, and how tall it is. Both
    // come from ControlCenter, which needs the other pages' contentHeight to
    // work the panel height out.
    //
    // `top` would be the natural name and is not available: QQuickItem has a
    // final member called `top` in this Qt, so declaring one here is a
    // property-override error rather than a shadow.
    property real pageTop: 0
    property real pageHeight: 0

    property real inset: 22

    readonly property real baseX: page.panelX + page.inset
    readonly property real baseY: page.pageTop

    width: page.panelWidth - page.inset * 2
    height: page.pageHeight

    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Keep the page alive until its exit fade completes. `visible: open`
    // discarded the page as soon as Back was pressed, so the intended close
    // animation could never be seen.
    interactive: page.open && contentHeight > height
    flickableDirection: Flickable.VerticalFlick

    visible: page.open || opacity > 0.01

    x: page.baseX
    y: page.baseY + (page.open ? 0 : -BarConfig.panelSlideIn)
    opacity: page.open ? 1 : 0
    scale: page.open ? 1 : 0.985
    transformOrigin: Item.Top

    Behavior on y {
        enabled: !MotionConfig.reduceMotion
        NumberAnimation { duration: MotionConfig.slideInMs; easing.type: Easing.OutCubic }
    }
    Behavior on opacity { NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic } }
    Behavior on scale {
        enabled: !MotionConfig.reduceMotion
        NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic }
    }
}
