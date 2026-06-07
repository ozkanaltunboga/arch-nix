import QtQuick 2.15
import QtQuick.Controls 2.15
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

                TextField {
                    id: passwordField
                    width: 280
                    height: 48
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    color: root.text
                    background: Rectangle {
                        radius: 12
                        color: root.surface
                        border.color: passwordField.focus ? root.primary : "#45475a"
                        border.width: passwordField.focus ? 2 : 1
                    }
                    Keys.onReturnPressed: sddm.login(userModel.lastUser, passwordField.text, sessionModel.lastIndex)
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    height: 40
                    text: "Login"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: root.base
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 10
                        color: root.primary
                    }
                    onClicked: sddm.login(userModel.lastUser, passwordField.text, sessionModel.lastIndex)
                }
            }
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}
