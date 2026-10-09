import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dix.qemu"
  ipcTarget: "dix.qemu"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: service.runningCount > 0 ? "#50fa7b" : Qt.darker(foreground, 1.55)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: service
  }

  IpcHandler {
    target: root.ipcTarget
    function refresh(): string { service.refresh(); return "ok" }
    function status(): string { return JSON.stringify({vms: service.vms, warning: service.warning}) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        implicitWidth: Style.space(24)
        implicitHeight: Style.space(20)
        Text {
          anchors.centerIn: parent
          text: "󰟀"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.space(13)
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(col.implicitHeight, Style.space(500))

    Column {
      id: col
      width: parent.width
      spacing: Style.space(12)

      PanelHero {
        width: parent.width
        title: "QEMU VMs"
        meta: service.runningCount > 0
          ? service.runningCount + " active"
          : (service.vms.length ? "All stopped" : "No VMs detected")
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: service.runningCount > 0 ? 1.0 : 0.5
        iconComponent: Component {
          Text {
            text: "󰟀"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }
      }

      Text {
        visible: service.warning !== ""
        text: service.warning
        textFormat: Text.PlainText
        color: root.dim
        width: parent.width
        wrapMode: Text.WordWrap
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelSeparator {
        foreground: root.foreground
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        padding: Style.space(4)

        Repeater {
          model: service.vms
          delegate: Item {
            required property var modelData
            width: parent.width - Style.space(8)
            implicitHeight: rowContent.implicitHeight

            readonly property bool isRunning: modelData.active

            Column {
              id: rowContent
              width: parent.width
              spacing: 0

              RowLayout {
                width: parent.width
                height: Style.space(44)
                spacing: Style.space(8)

                Text {
                  text: isRunning ? "󰐊" : "󰓛"
                  color: isRunning ? "#50fa7b" : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(14)
                  leftPadding: Style.space(8)
                }

                Column {
                  Layout.fillWidth: true
                  spacing: Style.space(1)

                  Text {
                    text: modelData.name
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: isRunning
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: modelData.detail + " · " + modelData.state.replace(/_/g, " ")
                    textFormat: Text.PlainText
                    color: isRunning ? "#50fa7b" : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Rectangle {
                  visible: modelData.backend === "libvirt"
                  width: Style.space(64)
                  height: Style.space(28)
                  radius: Style.space(4)
                  color: isRunning
                    ? Qt.rgba(1, 0.2, 0.2, 0.15)
                    : Qt.rgba(0.31, 0.98, 0.48, 0.15)

                  Text {
                    anchors.centerIn: parent
                    text: isRunning ? "Shutdown" : "Start"
                    textFormat: Text.PlainText
                    color: isRunning ? "#ff5555" : "#50fa7b"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !service.busy
                    onClicked: {
                      if (isRunning) service.stop(modelData.name)
                      else {
                        service.start(modelData.name)
                        service.open(modelData.name)
                      }
                    }
                  }
                }
              }

              Column {
                visible: isRunning
                width: parent.width
                spacing: Style.space(2)
                leftPadding: Style.space(30)
                bottomPadding: Style.space(8)

                Text {
                  visible: modelData.network !== ""
                  text: "Forwarding: " + modelData.network
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  width: parent.width - Style.space(30)
                  wrapMode: Text.WrapAnywhere
                }
                Text {
                  visible: modelData.diskLabel !== ""
                  text: modelData.diskLabel
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  visible: modelData.ip !== ""
                  text: "IP: " + modelData.ip
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  visible: modelData.ram !== ""
                  width: parent.width - Style.space(30)
                  wrapMode: Text.WordWrap
                  text: "Host RSS: " + modelData.ram + " MiB" + (modelData.ramTotal !== "" ? " · Guest RAM: " + modelData.ramTotal + " MiB" : "")
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  visible: modelData.disk !== ""
                  text: "Disk: " + modelData.disk + " / " + modelData.diskTotal + " GiB"
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }
  }
}
