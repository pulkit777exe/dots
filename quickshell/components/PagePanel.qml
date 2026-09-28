import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root
    required property int pageIndex
    required property int currentPage
    readonly property bool isCurrent: pageIndex === currentPage
    // fillWidth, not a plain `width: parent.width`. The pages are hosted in a
    // ColumnLayout (SettingsApp's flickCol), and a layout assigns widths to
    // the items it manages -- so the binding here was being fought over by
    // the layout, and a page whose content asked for less width than its
    // siblings got 72px instead of the content column. fillWidth is the
    // supported way to say "take the whole column".
    Layout.fillWidth: true
    Layout.preferredWidth: 0
    width: parent ? parent.width : 0
    y: 0
    implicitHeight: childrenRect.height
    height: implicitHeight
    opacity: isCurrent ? 1 : 0
    x: isCurrent ? 0 : 8
    enabled: isCurrent
    visible: opacity > 0.01
    function showPage() { root.opacity = 1; root.x = 0 }
    function hidePage() { root.opacity = 0; root.x = 8 }
    onIsCurrentChanged: isCurrent ? showPage() : hidePage()
    Behavior on opacity {
        enabled: !MotionConfig.reduceMotion
        NumberAnimation { duration: MotionConfig.fadeMs; easing.type: Easing.OutCubic }
    }
    Behavior on x {
        enabled: !MotionConfig.reduceMotion
        NumberAnimation { duration: MotionConfig.fadeMs; easing.type: Easing.OutCubic }
    }
}
