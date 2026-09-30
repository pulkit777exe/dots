import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root
    required property int pageIndex
    required property int currentPage
    readonly property bool isCurrent: pageIndex === currentPage
    
    
    
    
    
    
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
