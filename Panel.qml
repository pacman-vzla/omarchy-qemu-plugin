import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dix.qemu"
  ipcTarget: "dix.qemu"
  manageIpc: false

  Translations { id: tr; directory: Qt.resolvedUrl("i18n") }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool anyRunning: service.runningCount > 0

  readonly property color cardFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045)
  readonly property color cardBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)

  function fmtMem(mb) {
    return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
  }
  function fmtGb(gb) {
    return gb >= 100 ? Math.round(gb) + "" : gb.toFixed(1)
  }
  function meterColor(frac) {
    return frac >= 0.9 ? root.urgent : root.accent
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: service
    fast: root.opened
  }
  // Inline components below can't see document ids; they go through root.svc.
  readonly property alias svc: service

  // IPC takes a VM name for convenience; resolve it to the UUID from the last
  // poll (exact match) so the action targets exactly that domain.
  function _ipcAct(name, fn) {
    var uuid = service.uuidForName(name)
    if (!uuid) return "unknown vm"
    fn(uuid)
    return "ok"
  }

  IpcHandler {
    target: root.ipcTarget
    function refresh(): string { service.refresh(); return "ok" }
    function start(name: string): string { return root._ipcAct(name, service.start) }
    function shutdown(name: string): string { return root._ipcAct(name, service.stop) }
  }

  // ------------------------------------------------------------------ bar
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰟀"
    tooltipText: ""
    // Accent color while any VM is running, dimmed when all are off.
    foreground: root.anyRunning
      ? root.accent
      : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
    Behavior on foreground { ColorAnimation { duration: 250 } }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) service.openManager()
    }
  }

  // ---------------------------------------------------------------- panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(col.implicitHeight, Style.space(560))

    Flickable {
      anchors.fill: parent
      contentHeight: col.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: col
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: tr.t("title")
          meta: !service.loaded ? tr.t("loading")
            : service.error ? tr.t("noLibvirt")
            : root.anyRunning
              ? tr.tn("header.running", service.runningCount).arg(I18n.formatNumber(service.runningCount)).arg(I18n.formatNumber(service.vms.length))
              : tr.t("allStopped")
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Rectangle {
              implicitWidth: Style.space(42)
              implicitHeight: Style.space(42)
              radius: Style.cornerRadius > 0 ? Style.space(10) : 0
              color: root.anyRunning
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                : root.cardFill
              border.width: 1
              border.color: root.anyRunning
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                : root.cardBorder
              Behavior on color { ColorAnimation { duration: 250 } }
              Text {
                anchors.centerIn: parent
                text: "󰟀"
                textFormat: Text.PlainText
                color: root.anyRunning ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge + Style.space(4)
              }
            }
          }
          trailingControl: Component {
            Row {
              spacing: Style.space(2)
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: tr.t("refresh")
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: service.refresh()
              }
              PanelActionButton {
                iconText: "󰙵"
                tooltipText: tr.t("manager")
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: { service.openManager(); root.close() }
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // Empty / error state
        Text {
          visible: service.loaded && (service.error || service.vms.length === 0)
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(10)
          bottomPadding: Style.space(10)
          text: service.error ? tr.t("noLibvirt") : tr.t("none")
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // Active VMs
        Column {
          visible: service.activeVms.length > 0
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: tr.t("active")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          Repeater {
            model: service.activeVms
            VmCard {
              required property var modelData
              width: parent.width
              vm: modelData
            }
          }
        }

        // Stopped VMs
        Column {
          visible: service.stoppedVms.length > 0
          width: parent.width
          spacing: Style.space(4)

          PanelSectionHeader {
            text: tr.t("stopped")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          Repeater {
            model: service.stoppedVms
            StoppedRow {
              required property var modelData
              width: parent.width
              vm: modelData
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------------- components

  // Pulsing status dot.
  component StatusDot: Item {
    id: dot
    property color color: root.accent
    property bool live: true
    property bool hollow: false
    implicitWidth: Style.space(10)
    implicitHeight: Style.space(10)

    Rectangle {
      anchors.centerIn: parent
      width: parent.width; height: width; radius: width / 2
      color: dot.color
      visible: dot.live
      SequentialAnimation on opacity {
        running: dot.live && root.opened
        loops: Animation.Infinite
        NumberAnimation { from: 0.45; to: 0; duration: 1400; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 300 }
      }
      SequentialAnimation on scale {
        running: dot.live && root.opened
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 2.2; duration: 1400; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 300 }
      }
    }
    Rectangle {
      anchors.centerIn: parent
      width: Style.space(7); height: width; radius: width / 2
      color: dot.hollow ? "transparent" : dot.color
      border.width: dot.hollow ? 1 : 0
      border.color: dot.color
    }
  }

  // Labeled progress bar.
  component Meter: Item {
    id: meter
    property string icon: ""
    property string label: ""
    property string value: ""
    property real frac: 0
    // Optional secondary segment drawn after `frac` (e.g. reclaimable cache).
    property real extraFrac: 0
    property bool known: true
    width: parent ? parent.width : 0
    implicitHeight: meterLabels.implicitHeight + Style.space(4) + meterTrack.height

    RowLayout {
      id: meterLabels
      width: parent.width
      spacing: Style.space(6)
      Text {
        text: meter.icon
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        text: meter.label
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Item { Layout.fillWidth: true }
      Text {
        text: meter.known ? meter.value : "—"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    Rectangle {
      id: meterTrack
      anchors.top: meterLabels.bottom
      anchors.topMargin: Style.space(4)
      width: parent.width
      height: Style.space(4)
      radius: height / 2
      color: root.trackColor
      Rectangle {
        height: parent.height
        radius: parent.radius
        width: meter.known && meter.extraFrac > 0
          ? parent.width * Math.max(0, Math.min(1, meter.frac + meter.extraFrac)) : 0
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
      }
      Rectangle {
        height: parent.height
        radius: parent.radius
        width: meter.known ? Math.max(height, parent.width * Math.max(0, Math.min(1, meter.frac))) : 0
        color: root.meterColor(meter.frac)
        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }
      }
    }
  }

  // Card for running / paused / transitioning VMs.
  component VmCard: Rectangle {
    id: card
    property var vm
    readonly property bool running: vm.state === "running"
    readonly property bool paused: vm.state === "paused"
    readonly property bool busy: vm.pending !== ""
    readonly property string statusText: vm.pending === "starting" ? tr.t("starting")
      : vm.pending === "stopping" ? tr.t("stopping")
      : vm.pending === "resuming" ? tr.t("resuming")
      : paused ? tr.t("stPaused")
      : running ? tr.t("stRunning") : vm.state
    property bool ipCopied: false

    radius: Style.cornerRadius > 0 ? Style.space(10) : 0
    color: root.cardFill
    border.width: 1
    border.color: cardMouse.containsMouse
      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
      : root.cardBorder
    Behavior on border.color { ColorAnimation { duration: 150 } }
    implicitHeight: cardCol.implicitHeight + Style.space(24)

    MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

    Timer { id: copiedTimer; interval: 1500; onTriggered: card.ipCopied = false }

    Column {
      id: cardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

      // Header: dot, name, status, actions
      RowLayout {
        width: parent.width
        spacing: Style.space(10)

        StatusDot {
          Layout.alignment: Qt.AlignVCenter
          color: card.paused ? root.dim : root.accent
          live: card.running && !card.busy
          hollow: card.busy || card.paused
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(1)
          Text {
            width: parent.width
            text: card.vm.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Text {
            text: card.statusText + (card.running && card.vm.vcpus > 0 && !card.busy ? " · " + card.vm.vcpus + " vCPU" : "")
            textFormat: Text.PlainText
            color: card.busy || card.paused ? root.dim : root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelActionButton {
          visible: card.running
          iconText: "󰍹"
          tooltipText: tr.t("console")
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: { root.svc.openConsole(card.vm.uuid); root.close() }
        }
        PanelActionButton {
          visible: card.paused
          iconText: "󰐊"
          tooltipText: tr.t("resume")
          foreground: root.foreground
          fontFamily: root.fontFamily
          enabled: !card.busy
          onClicked: root.svc.resume(card.vm.uuid)
        }
        PanelActionButton {
          // Graceful shutdown; while it is in progress, offer force-off instead.
          visible: card.vm.pending !== "starting"
          iconText: card.vm.pending === "stopping" ? "󰅙" : "󰐥"
          tooltipText: card.vm.pending === "stopping" ? tr.t("force") : tr.t("shutdown")
          foreground: root.foreground
          hoverColor: root.urgent
          fontFamily: root.fontFamily
          onClicked: card.vm.pending === "stopping"
            ? root.svc.forceStop(card.vm.uuid)
            : root.svc.stop(card.vm.uuid)
        }
      }

      // IP chip
      Rectangle {
        visible: card.running
        height: ipRow.implicitHeight + Style.space(8)
        width: ipRow.implicitWidth + Style.space(16)
        radius: Style.cornerRadius > 0 ? height / 2 : 0
        color: ipMouse.containsMouse
          ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
          id: ipRow
          anchors.centerIn: parent
          spacing: Style.space(6)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.ipCopied ? "󰄬" : "󰩟"
            textFormat: Text.PlainText
            color: card.ipCopied ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.ipCopied ? tr.t("copied") : (card.vm.ip !== "" ? card.vm.ip : tr.t("waitingIp"))
            textFormat: Text.PlainText
            color: card.vm.ip !== "" ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        MouseArea {
          id: ipMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: card.vm.ip !== ""
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.svc.copy(card.vm.ip); card.ipCopied = true; copiedTimer.restart() }
        }
        PanelToolTip {
          visible: ipMouse.containsMouse && !card.ipCopied
          text: tr.t("copyIp")
          fontFamily: root.fontFamily
        }
      }

      // Metrics
      Column {
        visible: card.running
        width: parent.width
        spacing: Style.space(8)

        Meter {
          icon: "󰻠"
          label: tr.t("cpu")
          known: card.vm.cpu >= 0
          frac: card.vm.cpu / 100
          value: Math.round(card.vm.cpu) + "%"
        }
        Meter {
          icon: "󰍛"
          label: tr.t("ram")
          known: card.vm.ramTotal > 0
          frac: card.vm.ramTotal > 0 ? card.vm.ramUsed / card.vm.ramTotal : 0
          extraFrac: card.vm.ramTotal > 0 ? card.vm.ramCache / card.vm.ramTotal : 0
          value: root.fmtMem(card.vm.ramUsed)
            + (card.vm.ramCache > 0 ? " + " + root.fmtMem(card.vm.ramCache) + " " + tr.t("cache") : "")
            + " / " + root.fmtMem(card.vm.ramTotal)
        }
        Meter {
          icon: "󰋊"
          label: tr.t("disk")
          known: card.vm.diskTotal > 0
          frac: card.vm.diskTotal > 0 ? card.vm.diskUsed / card.vm.diskTotal : 0
          value: root.fmtGb(card.vm.diskUsed) + " / " + root.fmtGb(card.vm.diskTotal) + " GB"
        }
      }
    }
  }

  // Compact row for stopped VMs.
  component StoppedRow: CursorSurface {
    id: row
    property var vm
    readonly property bool crashed: vm.state === "crashed"
    readonly property string errorText: root.svc.errors[vm.uuid] ? root.svc.errors[vm.uuid].message : ""
    foreground: root.foreground
    hasCursor: rowMouse.containsMouse
    implicitHeight: Style.space(40)

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.svc.start(row.vm.uuid)
    }

    PanelToolTip {
      visible: rowMouse.containsMouse && row.errorText !== ""
      text: row.errorText
      fontFamily: root.fontFamily
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(10)

      StatusDot {
        Layout.alignment: Qt.AlignVCenter
        color: row.crashed ? root.urgent : root.dim
        live: false
        hollow: true
      }
      Text {
        Layout.fillWidth: true
        text: row.vm.name
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: rowMouse.containsMouse ? root.foreground : Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        visible: !rowMouse.containsMouse
        Layout.maximumWidth: row.width * 0.5
        elide: Text.ElideRight
        text: row.errorText !== "" ? "󰀦 " + tr.t("failed")
          : row.crashed ? tr.t("stCrashed") : tr.t("stOff")
        textFormat: Text.PlainText
        color: row.crashed || row.errorText !== "" ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Row {
        visible: rowMouse.containsMouse
        spacing: Style.space(6)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: tr.t("start")
          textFormat: Text.PlainText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰐊"
          textFormat: Text.PlainText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
