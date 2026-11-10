import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Item {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""
  property var options: []
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool expanded: false

  signal changed(string value)

  function optionValue(option) {
    return option && typeof option === "object" ? String(option.value) : String(option)
  }

  function optionLabel(option) {
    return option && typeof option === "object" ? String(option.label) : String(option)
  }

  function currentLabel() {
    for (var i = 0; i < root.options.length; i++) {
      if (root.optionValue(root.options[i]) === root.value)
        return root.optionLabel(root.options[i])
    }
    return root.value
  }

  implicitHeight: card.implicitHeight

  BorderSurface {
    id: card
    width: parent.width
    implicitHeight: content.implicitHeight + Style.space(16)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
    borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.11), Style.normalBorderWidth)
    radius: Style.cornerRadius

    Column {
      id: content
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: Style.space(6)

      Item {
        width: parent.width
        height: headerColumn.implicitHeight

        Column {
          id: headerColumn
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: root.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: root.description
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width
            wrapMode: Text.WordWrap
          }
        }

      }

      BorderSurface {
        width: parent.width
        height: Style.spacing.controlHeight
        clip: true
        color: Style.controlFill(false, false, root.foreground, Commons.Color.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, Commons.Color.accent)
        radius: Style.cornerRadius

        Item {
          anchors.fill: parent

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.right: valueChevron.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.currentLabel()
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            id: valueChevron
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.controlPaddingX
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.expanded ? "󰅀" : "󰅂"
            color: Qt.darker(root.foreground, 1.25)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expanded = !root.expanded
        }
      }

      Flow {
        id: optionGrid
        width: parent.width
        spacing: Style.space(6)
        visible: root.expanded
        height: visible ? childrenRect.height : 0

        Repeater {
          model: root.options

          delegate: BorderSurface {
            required property var modelData
            width: Math.max(1, (optionGrid.width - Style.space(6)) / 2)
            height: Style.space(30)
            radius: Style.cornerRadius
            color: root.optionValue(modelData) === root.value
              ? Style.normalFillFor(root.foreground, Commons.Color.accent)
              : "transparent"
            borderSpec: Border.flat(
              root.optionValue(modelData) === root.value
                ? Commons.Color.accent
                : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14),
              Style.normalBorderWidth)

            Text {
              textFormat: Text.PlainText
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.spacing.controlPaddingX
              text: root.optionLabel(modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.value = root.optionValue(modelData)
                root.changed(root.value)
                root.expanded = false
              }
            }
          }
        }
      }
    }
  }
}
