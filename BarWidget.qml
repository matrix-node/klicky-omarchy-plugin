import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.matrix-node.klicky"

  property bool running: false

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: ["systemctl", "--user", "is-active", "--quiet", "klicky.service"]

    onExited: function(exitCode) {
      root.running = exitCode === 0
    }
  }

  Process {
    id: toggleProcess

    onExited: refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 250
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    active: root.running
    useActiveColor: false
    tooltipText: root.running ? "Turn Klicky Off" : "Turn Klicky On"

    onPressed: function(buttonCode) {
      if (buttonCode !== Qt.LeftButton || toggleProcess.running) return
      toggleProcess.command = [
        "systemctl",
        "--user",
        root.running ? "stop" : "start",
        "klicky.service"
      ]
      toggleProcess.running = true
    }
  }
}
