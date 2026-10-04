import QtQuick
import "../services"


StyledText {

    CcTokens { id: cc }

    font.pixelSize: 12
    font.weight: Font.Medium
    color: cc.textSub
}
