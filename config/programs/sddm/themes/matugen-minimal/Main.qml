import QtQuick 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#11111b"

    property color primary: "#cba6f7"
    property color text: "#cdd6f4"
    property color subtext: "#a6adc8"
    property color surface: "#313244"
    property color base: "#1e1e2e"

    Column {
        anchors.centerIn: parent
        spacing: 24

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Welcome"
            font.family: "JetBrains Mono"
            font.pixelSize: 36
            font.weight: Font.Bold
            color: root.primary
        }

        Rectangle {
            width: 360
            height: 200
            radius: 16
            color: root.base
            border.color: root.surface
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: userModel.lastUser || "User"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: root.text
                }

                Rectangle {
                    id: passwordField
                    width: 280
                    height: 48
                    radius: 12
                    color: root.surface
                    border.color: passwordInput.activeFocus ? root.primary : "#45475a"
                    border.width: passwordInput.activeFocus ? 2 : 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        text: "Password"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        color: root.subtext
                        visible: passwordInput.text.length === 0
                    }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        color: root.text
                        clip: true
                        Keys.onReturnPressed: sddm.login(userModel.lastUser, passwordInput.text, sessionModel.lastIndex)
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    height: 40
                    radius: 10
                    color: loginArea.containsMouse ? Qt.lighter(root.primary, 1.08) : root.primary

                    Text {
                        anchors.centerIn: parent
                        text: "Login"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: root.base
                    }

                    MouseArea {
                        id: loginArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.login(userModel.lastUser, passwordInput.text, sessionModel.lastIndex)
                    }
                }
            }
        }
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
