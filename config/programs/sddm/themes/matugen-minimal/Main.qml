import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as Controls
import QtQuick.Window 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#11111b"
    focus: true

    property color primary: "#cba6f7"
    property color text: "#cdd6f4"
    property color subtext: "#a6adc8"
    property color surface: "#313244"
    property color base: "#1e1e2e"
    property color red: "#f38ba8"

    property int edgePadding: Math.max(20, Math.min(width, height) * 0.04)
    property int cardWidth: Math.min(380, Math.max(280, width - edgePadding * 2))
    property int selectedSession: (typeof sessionModel.lastIndex === "number" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property bool hasUsers: typeof userModel.count === "number" && userModel.count > 0

    function selectedUser() {
        if (hasUsers && userCombo.currentText && userCombo.currentText.length > 0)
            return userCombo.currentText;

        if (userModel.lastUser && userModel.lastUser.length > 0)
            return userModel.lastUser;

        if (userInput.text.trim().length > 0)
            return userInput.text.trim();

        return "";
    }

    function submitLogin() {
        var userName = selectedUser();
        if (userName.length === 0) {
            statusText.text = "Enter your username";
            userInput.forceActiveFocus();
            return;
        }

        statusText.text = "";
        sddm.login(userName, passwordInput.text, selectedSession);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordInput.text = "";
            statusText.text = "Login failed";
            passwordInput.forceActiveFocus();
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: root.cardWidth
        spacing: Math.max(16, root.height * 0.025)

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Welcome"
            font.family: "JetBrains Mono"
            font.pixelSize: Math.max(26, Math.min(36, root.height * 0.055))
            font.weight: Font.Bold
            color: root.primary
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hasUsers ? 305 : 345
            radius: 16
            color: root.base
            border.color: root.surface
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: hasUsers ? "User" : "Username"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: root.text
                }

                Controls.ComboBox {
                    id: userCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    visible: hasUsers
                    model: userModel
                    textRole: "name"
                    currentIndex: (typeof userModel.lastIndex === "number" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                    leftPadding: 16
                    rightPadding: 42

                    background: Rectangle {
                        radius: 12
                        color: root.surface
                        border.color: userCombo.activeFocus ? root.primary : "#45475a"
                        border.width: userCombo.activeFocus ? 2 : 1
                    }

                    contentItem: Text {
                        leftPadding: 0
                        rightPadding: 0
                        text: userCombo.displayText
                        font: userCombo.font
                        color: root.text
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: Text {
                        x: userCombo.width - width - 14
                        y: (userCombo.height - height) / 2
                        text: "⌄"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 18
                        color: root.primary
                    }

                    popup: Controls.Popup {
                        y: userCombo.height + 6
                        width: userCombo.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 4

                        background: Rectangle {
                            radius: 12
                            color: root.base
                            border.color: root.primary
                            border.width: 1
                        }

                        contentItem: ListView {
                            clip: true
                            implicitHeight: Math.min(contentHeight, 180)
                            model: userCombo.popup.visible ? userCombo.delegateModel : null
                            currentIndex: userCombo.highlightedIndex
                        }
                    }

                    delegate: Controls.ItemDelegate {
                        width: userCombo.width - 8
                        height: 38
                        highlighted: userCombo.highlightedIndex === index

                        background: Rectangle {
                            radius: 8
                            color: highlighted ? root.surface : "transparent"
                        }

                        contentItem: Text {
                            text: model.name
                            font: userCombo.font
                            color: highlighted ? root.primary : root.text
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    id: userField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    visible: !hasUsers
                    radius: 12
                    color: root.surface
                    border.color: userInput.activeFocus ? root.primary : "#45475a"
                    border.width: userInput.activeFocus ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: userInput.forceActiveFocus()
                    }

                    TextInput {
                        id: userInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        color: root.text
                        clip: true
                        Keys.onReturnPressed: passwordInput.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 12
                    color: root.surface
                    border.color: passwordInput.activeFocus ? root.primary : "#45475a"
                    border.width: passwordInput.activeFocus ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: passwordInput.forceActiveFocus()
                    }

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
                        Keys.onReturnPressed: root.submitLogin()
                    }
                }

                Text {
                    id: statusText
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: ""
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: root.red
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
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
                        onClicked: root.submitLogin()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (hasUsers)
            passwordInput.forceActiveFocus();
        else
            userInput.forceActiveFocus();
    }
}
