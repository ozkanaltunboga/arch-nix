import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QtCore
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }
    
    focus: true

    Shortcut {
        sequence: "Tab"
        onActivated: {
            window.playSfx("switch.wav");
            window.activeMode = window.activeMode === "ethernet" ? "bt" : "ethernet";
        }
    }

    Settings {
        id: cache
        category: "QS_NetworkWidget_Alt"
        property string lastBtJson: ""
    }

    property bool ignoreNextModeFileUpdate: false
    Process {
        id: modeReader
        command: ["bash", "-c", "cat /tmp/qs_network_mode 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let mode = this.text.trim();
                if ((mode === "ethernet" || mode === "bt") && window.activeMode !== mode) {
                    window.ignoreNextModeFileUpdate = true;
                    window.activeMode = mode;
                }
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: modeReader.running = true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "if [ ! -f /tmp/qs_network_mode ]; then echo '" + activeMode + "' > /tmp/qs_network_mode; fi"]);
        if (cache.lastBtJson !== "") processBtJson(cache.lastBtJson);
        introState = 1.0;
    }

    function playSfx(filename) {
        try {
            let rawUrl = Qt.resolvedUrl("sounds/" + filename).toString();
            let cleanPath = rawUrl;
            if (cleanPath.indexOf("file://") === 0) cleanPath = cleanPath.substring(7); 
            let cmd = "pw-play '" + cleanPath + "' 2>/dev/null || paplay '" + cleanPath + "' 2>/dev/null";
            Quickshell.execDetached(["sh", "-c", cmd]);
        } catch(e) {}
    }

    MatugenColors { id: _theme }

    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color green: _theme.green

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/network"
    
    readonly property color ethAccent: window.green
    readonly property color btAccent: window.mauve

    property string activeMode: "bt"
    readonly property color activeColor: activeMode === "ethernet" ? window.ethAccent : window.btAccent
    readonly property color activeGradientSecondary: Qt.darker(window.activeColor, 1.25)

    property var busyTasks: ({})
    property var disconnectingDevices: ({})
    property string connectingId: ""
    property string failedId: ""
    
    Timer { 
        id: busyTimeout; interval: 15000; 
        onTriggered: { window.busyTasks = ({}); window.disconnectingDevices = ({}); window.connectingId = ""; } 
    }
    Timer { id: failClearTimer; interval: 4000; onTriggered: window.failedId = "" }

    Timer { id: btPendingReset; interval: 8000; onTriggered: { window.btPowerPending = false; window.expectedBtPower = ""; } }

    property bool showInfoView: false

    function connectDevice(mode, id, macOrSsid, password) {
        window.connectingId = id;
        window.failedId = "";
        let bt = window.busyTasks;
        bt[id] = true;
        window.busyTasks = Object.assign({}, bt);
        busyTimeout.restart();
    }

    property var currentCores: [null, null, null, null, null]
    property var coreVisualIndices: [0, 0, 0, 0, 0]
    property int activeCoreCount: 0
    property real smoothedActiveCoreCount: activeCoreCount
    Behavior on smoothedActiveCoreCount { NumberAnimation { duration: 1000; easing.type: Easing.InOutExpo } }

    function syncCores() {
        let list = activeMode === "ethernet" ? (window.ethConnected ? [window.ethData] : []) : window.btConnected;
        if (!currentPower) list = [];
        else if (!Array.isArray(list)) list = [list];

        let newCores = [null, null, null, null, null];
        for (let i = 0; i < list.length && i < 5; i++) {
            newCores[i] = list[i];
        }

        window.currentCores = [...newCores];
        let activeCount = 0;
        let newVis = [0, 0, 0, 0, 0];
        for (let c = 0; c < 5; c++) {
            if (newCores[c]) {
                newVis[c] = activeCount;
                activeCount++;
            }
        }
        window.coreVisualIndices = newVis;
        window.activeCoreCount = activeCount;
    }

    onActiveModeChanged: {
        if (!window.ignoreNextModeFileUpdate) {
            Quickshell.execDetached(["bash", "-c", "echo '" + window.activeMode + "' > /tmp/qs_network_mode"]);
        }
        window.ignoreNextModeFileUpdate = false;
        window.currentCores = [null, null, null, null, null];
        window.coreVisualIndices = [0, 0, 0, 0, 0];
        window.activeCoreCount = 0;
        syncCores();
    }

    ListModel { id: btListModel }

    property string ethStatus: "disconnected"
    property string ethInterface: ""
    property string ethIp: ""
    property string ethSpeed: ""
    property var ethData: null
    property bool ethConnected: false

    property bool btPowerPending: false
    property string expectedBtPower: ""
    property string btPower: "off"
    property var btConnected: []
    property var btList: []
    readonly property bool isBtConn: window.btConnected.length > 0
    
    onBtConnectedChanged: { 
        syncCores();
    }

    readonly property bool currentPower: activeMode === "ethernet" ? window.ethConnected : window.btPower === "on"
    onCurrentPowerChanged: { syncCores(); }

    readonly property bool currentPowerPending: activeMode === "ethernet" ? false : window.btPowerPending
    readonly property bool currentConn: activeMode === "ethernet" ? window.ethConnected : window.isBtConn

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 200000; loops: Animation.Infinite; running: true
    }

    property real introState: 0.0
    Behavior on introState { NumberAnimation { duration: 1500; easing.type: Easing.OutCubic } }

    Process {
        id: ethPoller
        command: ["bash", "-c", 
            "IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1); " +
            "if [ -n \"$IFACE\" ]; then " +
            "  IP=$(ip -4 addr show $IFACE 2>/dev/null | grep inet | awk '{print $2}' | head -1); " +
            "  SPEED=$(cat /sys/class/net/$IFACE/speed 2>/dev/null || echo 'N/A'); " +
            "  STATE=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null || echo 'down'); " +
            "  echo \"{\\\"interface\\\":\\\"$IFACE\\\",\\\"ip\\\":\\\"$IP\\\",\\\"speed\\\":\\\"$SPEED\\\",\\\"state\\\":\\\"$STATE\\\"}\"; " +
            "else " +
            "  echo '{\"interface\":\"\",\"ip\":\"\",\"speed\":\"\",\"state\":\"down\"}'; " +
            "fi"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    window.ethInterface = data.interface || "";
                    window.ethIp = data.ip || "";
                    window.ethSpeed = data.speed || "";
                    window.ethStatus = data.state || "down";
                    window.ethConnected = (data.state === "up");
                    if (window.ethConnected) {
                        window.ethData = {
                            name: window.ethInterface,
                            ip: window.ethIp,
                            speed: window.ethSpeed + " Mbps",
                            icon: "󰈀",
                            mac: window.ethInterface
                        };
                    } else {
                        window.ethData = null;
                    }
                    syncCores();
                } catch(e) {}
            }
        }
    }

    Process {
        id: btPoller
        command: ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastBtJson = this.text.trim();
                processBtJson(cache.lastBtJson);
            }
        }
    }
    
    Timer {
        interval: 3000
        running: true; repeat: true
        onTriggered: { 
            if (!ethPoller.running) ethPoller.running = true; 
            if (!btPoller.running) btPoller.running = true; 
        }
    }

    function processBtJson(textData) {
        if (textData === "") return;
        try {
            let data = JSON.parse(textData);
            let fetchedPower = data.power || "off";
            
            if (window.btPowerPending) {
                window.btPower = window.expectedBtPower; 
                if (fetchedPower === window.expectedBtPower) {
                    window.btPowerPending = false; 
                    btPendingReset.stop();
                }
            } else {
                window.btPower = fetchedPower;
                window.expectedBtPower = "";
            }

            let newBtConnected = data.connected || [];
            if (!Array.isArray(newBtConnected)) newBtConnected = [newBtConnected];

            if (JSON.stringify(window.btConnected) !== JSON.stringify(newBtConnected)) {
                window.btConnected = newBtConnected;
            }

            let newDevices = data.devices ? data.devices : [];
            newDevices.sort((a, b) => a.id.localeCompare(b.id));

            if (JSON.stringify(window.btList) !== JSON.stringify(newDevices)) {
                btListModel.clear();
                for (let i = 0; i < newDevices.length && i < 30; i++) {
                    btListModel.append({
                        id: newDevices[i].id || "",
                        name: newDevices[i].name || newDevices[i].id || "",
                        icon: newDevices[i].icon || "󰂯",
                        mac: newDevices[i].mac || "",
                        action: newDevices[i].action || ""
                    });
                }
                window.btList = newDevices;
            }
        } catch(e) {}
    }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true
            
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
                opacity: window.currentPower ? 0.08 : 0.02
                color: window.currentConn ? window.activeColor : window.surface2
                Behavior on color { ColorAnimation { duration: 1000 } }
                Behavior on opacity { NumberAnimation { duration: 1000 } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
                opacity: window.currentPower ? 0.06 : 0.01
                color: window.currentConn ? window.activeGradientSecondary : window.surface1
                Behavior on color { ColorAnimation { duration: 1000 } }
                Behavior on opacity { NumberAnimation { duration: 1000 } }
            }

            Item {
                id: radarItem
                anchors.fill: parent
                anchors.bottomMargin: window.s(80) 
                opacity: window.currentPower ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                
                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: window.s(280) + (index * window.s(170))
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: window.activeColor
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        opacity: window.currentConn ? 0.08 - (index * 0.02) : 0.03
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            Item {
                id: orbitContainer
                anchors.fill: parent
                anchors.bottomMargin: window.s(80) 
                z: 1

                Repeater {
                    id: coreRepeater
                    model: 5

                    delegate: Item {
                        id: coreContainer
                        
                        property var myDevice: window.currentCores[index]
                        property bool isPrimary: index === 0
                        property bool hasDevice: myDevice !== null
                        property bool isReallyActive: hasDevice || (isPrimary && window.activeCoreCount === 0)

                        property real activeTransition: isReallyActive ? 1.0 : 0.0
                        Behavior on activeTransition { 
                            enabled: window.introState >= 1.0; 
                            NumberAnimation { duration: 1400; easing.type: Easing.OutExpo } 
                        }

                        width: window.currentPower ? window.s(200) : window.s(160)
                        height: width
                        
                        property real myBaseAngle: (window.coreVisualIndices[index] / Math.max(1, window.activeCoreCount)) * Math.PI * 2
                        property real coreOrbitAngle: window.globalOrbitAngle * 1.5 + myBaseAngle
                        
                        property real myOrbitRadiusX: window.s(180)
                        property real myOrbitRadiusY: window.s(110)

                        x: (orbitContainer.width / 2 - width / 2) + (Math.cos(coreOrbitAngle) * myOrbitRadiusX * activeTransition)
                        y: (orbitContainer.height / 2 - height / 2) + (Math.sin(coreOrbitAngle) * myOrbitRadiusY * activeTransition)
                        
                        opacity: activeTransition
                        scale: 0.8 + 0.2 * activeTransition
                        visible: opacity > 0.01

                        Rectangle {
                            id: centralCore
                            anchors.fill: parent
                            radius: width / 2
                            
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.0
                                    color: {
                                        if (!window.currentPower) return window.mantle;
                                        return window.currentConn ? Qt.lighter(window.activeColor, 1.15) : window.surface0;
                                    }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                GradientStop {
                                    position: 1.0
                                    color: {
                                        if (!window.currentPower) return window.crust;
                                        return window.currentConn ? window.activeColor : window.base;
                                    }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }

                            border.color: {
                                if (!window.currentPower) return window.crust;
                                return window.currentConn ? Qt.lighter(window.activeColor, 1.1) : window.surface1;
                            }
                            border.width: window.s(2)
                            Behavior on border.color { ColorAnimation { duration: 300 } }
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + window.s(40)
                                height: width
                                radius: width / 2
                                color: window.activeColor
                                opacity: window.currentConn ? 0.15 : 0.0
                                z: -1
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite; running: window.currentConn
                                    NumberAnimation { to: 1.1; duration: 2000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: window.s(4)
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(36)
                                    color: window.currentConn ? window.crust : window.overlay0
                                    text: {
                                        if (!window.currentPower) return "󰌺";
                                        if (window.activeMode === "ethernet") return "󰈀";
                                        return myDevice ? (myDevice.icon || "󰂯") : "󰂯";
                                    }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(12)
                                    color: window.currentConn ? window.crust : window.overlay0
                                    text: {
                                        if (!window.currentPower) return "OFFLINE";
                                        if (window.activeMode === "ethernet") return window.ethInterface || "ETH";
                                        return myDevice ? (myDevice.name || "BT") : "BT";
                                    }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: window.s(20)
                spacing: window.s(12)

                Repeater {
                    model: ListModel {
                        ListElement { mode: "ethernet"; icon: "󰈀"; label: "Ethernet" }
                        ListElement { mode: "bt"; icon: "󰂯"; label: "Bluetooth" }
                    }
                    
                    delegate: Rectangle {
                        width: modeMa.containsMouse ? window.s(160) : window.s(56)
                        height: window.s(48)
                        radius: window.s(14)
                        color: window.activeMode === mode ? Qt.rgba(window.activeColor.r, window.activeColor.g, window.activeColor.b, 0.2) : "#0dffffff"
                        border.color: window.activeMode === mode ? window.activeColor : "#1affffff"
                        border.width: window.activeMode === mode ? 2 : 1
                        clip: true
                        
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        
                        scale: modeMa.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        Row {
                            anchors.centerIn: parent
                            spacing: window.s(8)
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(20)
                                color: window.activeMode === mode ? window.activeColor : window.subtext0
                                text: icon
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(13)
                                color: window.activeMode === mode ? window.activeColor : window.subtext0
                                text: label
                                opacity: modeMa.containsMouse || window.activeMode === mode ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        MouseArea {
                            id: modeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.playSfx("switch.wav");
                                window.activeMode = mode;
                            }
                        }
                    }
                }
            }

            Column {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: window.s(20)
                spacing: window.s(8)
                
                Rectangle {
                    width: window.s(44); height: window.s(44)
                    radius: window.s(12)
                    color: closeMa.containsMouse ? "#1affffff" : "transparent"
                    border.color: closeMa.containsMouse ? "#33ffffff" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: closeMa.containsMouse ? window.red : window.overlay0
                        text: "󰅖"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", "-c", "echo 'close' > /tmp/qs_widget_state"])
                    }
                }
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: window.s(20)
                spacing: window.s(4)
                
                Text {
                    font.family: "JetBrains Mono"
                    font.weight: Font.Black
                    font.pixelSize: window.s(22)
                    color: window.text
                    text: "Network"
                }
                
                Text {
                    font.family: "JetBrains Mono"
                    font.weight: Font.Medium
                    font.pixelSize: window.s(12)
                    color: window.subtext0
                    text: activeMode === "ethernet" ? "Ethernet Connection" : "Bluetooth Devices"
                }
            }
        }
    }
}
