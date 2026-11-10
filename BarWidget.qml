import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "io.github.matrix-node.klicky"

  property bool running: false
  property bool popupOpen: false
  property string soundPack: setting("soundPack", "cherrymx-brown-pbt")
  property string audioPolicy: setting("audioPolicy", "system")
  property var soundPackOptions: [
    "cherrymx-black-abs",
    "cherrymx-black-pbt",
    "cherrymx-blue-abs",
    "cherrymx-blue-pbt",
    "cherrymx-brown-abs",
    "cherrymx-brown-pbt",
    "cherrymx-red-abs",
    "cherrymx-red-pbt",
    "eg-crystal-purple",
    "eg-oreo"
  ]
  property var sinkOptions: [
    { value: "system", label: strings.t("audio.system") },
    { value: "builtin", label: strings.t("audio.builtin") },
    { value: "bluetooth", label: strings.t("audio.bluetooth") }
  ]
  property var sinks: []

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function saveSetting(name, value) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) {
      if (key !== "id") entry[key] = root.settings[key]
    }
    entry[name] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setSoundPack(value) {
    if (!/^[a-z0-9][a-z0-9-]*$/.test(value) || soundProcess.running) return
    root.soundPack = value
    root.saveSetting("soundPack", value)
    soundProcess.command = ["klicky", "switch", value]
    soundProcess.running = true
  }

  function refreshSinks() {
    if (!sinksProcess.running) sinksProcess.running = true
  }

  function applySinks(output) {
    var listed
    try {
      listed = JSON.parse(String(output || ""))
    } catch (error) {
      console.warn("klicky: unable to parse pactl sink list:", error)
      return
    }

    if (!Array.isArray(listed)) {
      console.warn("klicky: pactl returned an unexpected sink list")
      return
    }

    root.sinks = listed.filter(function(sink) {
      return sink && typeof sink.name === "string" && sink.name.length > 0
    })

    if (root.audioPolicy === "bluetooth") root.applyAudioPolicy()
  }

  function applyAudioPolicy() {
    if (root.audioPolicy === "system") return

    var target = null
    if (root.audioPolicy === "bluetooth") {
      target = root.sinks.find(function(sink) {
        return sink.name.indexOf("bluez_output.") === 0
      })
    }

    if (!target && root.audioPolicy === "builtin") {
      target = root.sinks.find(function(sink) {
        return sink.name.indexOf("alsa_output.") === 0
      })
    }

    if (!target && root.audioPolicy === "bluetooth") {
      target = root.sinks.find(function(sink) {
        return sink.name.indexOf("alsa_output.") === 0
      })
    }

    if (!target || target.name === root.appliedSink) return
    root.appliedSink = target.name
    defaultSinkProcess.command = ["pactl", "set-default-sink", target.name]
    defaultSinkProcess.running = true
  }

  property string appliedSink: ""

  function setAudioPolicy(value) {
    if (value !== "system" && value !== "builtin" && value !== "bluetooth") return
    root.audioPolicy = value
    root.appliedSink = ""
    root.saveSetting("audioPolicy", value)
    if (value !== "system") root.refreshSinks()
  }

  function close() {
    root.popupOpen = false
  }

  function toggle() {
    root.popupOpen = !root.popupOpen
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  Component.onCompleted: {
    refresh()
    soundListProcess.running = true
    refreshSinks()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      root.refresh()
      if (root.audioPolicy === "bluetooth") root.refreshSinks()
    }
  }

  Process {
    id: statusProcess
    command: ["systemctl", "--user", "is-active", "--quiet", "klicky.service"]

    onExited: function(exitCode) {
      root.running = exitCode === 0
    }
  }

  Process {
    id: soundListProcess
    command: ["klicky", "list"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var packs = []
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var pack = lines[i].replace(/\s+\(active\)\s*$/, "").trim()
          if (/^[a-z0-9][a-z0-9-]*$/.test(pack)) packs.push(pack)
        }
        if (packs.length > 0) root.soundPackOptions = packs
      }
    }
  }

  Process {
    id: soundProcess

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("klicky sound pack:", text.trim())
    }
  }

  Process {
    id: sinksProcess
    command: ["pactl", "-f", "json", "list", "sinks"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySinks(text)
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("klicky audio sinks:", text.trim())
    }
  }

  Process {
    id: defaultSinkProcess

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.appliedSink = ""
        return
      }
      if (root.running && !rerouteRestartProcess.running) {
        rerouteRestartProcess.command = ["systemctl", "--user", "restart", "klicky.service"]
        rerouteRestartProcess.running = true
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("klicky audio output:", text.trim())
    }
  }

  Process {
    id: rerouteRestartProcess

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("klicky audio restart:", text.trim())
    }

    onExited: root.refresh()
  }

  Process {
    id: toggleProcess

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("klicky service:", text.trim())
    }

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
    tooltipText: root.running
      ? strings.t("tooltip.running")
      : strings.t("tooltip.stopped")

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.toggle()
        return
      }
      if (buttonCode !== Qt.LeftButton || toggleProcess.running) return
      toggleProcess.command = ["systemctl", "--user", root.running ? "stop" : "start", "klicky.service"]
      toggleProcess.running = true
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(400))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      BorderSurface {
        id: statusCard
        width: parent.width
        implicitHeight: statusRow.implicitHeight + Style.space(20)
        color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
        borderSpec: Border.flat(Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16), Style.normalBorderWidth)
        radius: Style.cornerRadius

        Row {
          id: statusRow
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(10)

          Text {
            textFormat: Text.PlainText
            text: "󰌌"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - statusBadge.width - Style.space(10) - Style.font.display
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.title")
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.description")
              color: Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }

          BorderSurface {
            id: statusBadge
            implicitWidth: statusLabel.implicitWidth + Style.space(16)
            implicitHeight: statusLabel.implicitHeight + Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.cornerRadius
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
            borderSpec: Border.flat(root.running ? Commons.Color.accent : Qt.darker(root.bar.foreground, 1.5), Style.normalBorderWidth)

            Text {
              id: statusLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.running ? strings.t("panel.running") : strings.t("panel.stopped")
              color: root.running ? Commons.Color.accent : Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }

      ChoiceField {
        width: parent.width
        label: strings.t("panel.outputSection")
        description: strings.t("panel.outputDescription")
        value: root.audioPolicy
        options: root.sinkOptions
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        onChanged: root.setAudioPolicy(value)
      }

      ChoiceField {
        width: parent.width
        label: strings.t("panel.soundSection")
        description: strings.t("panel.soundDescription")
        value: root.soundPack
        options: root.soundPackOptions
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        onChanged: root.setSoundPack(value)
      }
    }
  }
}
