import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
  id: root
  moduleName: "patchharris.resources"
  ipcTarget: "patchharris.resources"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  component ResourceButton: Controls.Button {
    id: control
    padding: 7
    leftPadding: 14
    rightPadding: 14
    contentItem: Text { text: control.text; color: Commons.Color.foreground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: control.enabled ? 1 : 0.35 }
    background: Rectangle {
      implicitWidth: 64; implicitHeight: 32; radius: 5
      color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, control.down ? 0.2 : control.hovered ? 0.13 : 0.06)
      border.color: control.activeFocus ? Commons.Color.accent : Commons.Color.muted
      border.width: control.activeFocus ? 2 : 0
    }
  }
  property var report: null
  property var pending: null
  property string message: ""
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("resources.py").toString().replace(/^file:\/\//, ""))
  function size(bytes) { return (bytes / 1073741824).toFixed(1) + " GiB" }
  function refresh() { if (!stats.running) stats.running = true }
  onOpenedChanged: { pending = null; if (opened) refresh() }
  Timer { interval: 2000; repeat: true; running: root.opened; onTriggered: root.refresh() }
  Process {
    id: stats
    command: ["python3", root.helper]
    stdout: StdioCollector {
      onStreamFinished: {
        try { var result = JSON.parse(text); if (result.error) root.message = result.error; else root.report = result }
        catch (e) { root.message = "Could not read system resources" }
      }
    }
  }
  Process {
    id: terminateProc
    stdout: StdioCollector {
      onStreamFinished: {
        try { var result = JSON.parse(text); root.message = result.error || result.message }
        catch (e) { root.message = "Could not terminate process" }
        root.pending = null
        root.refresh()
      }
    }
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    tooltipText: "System resources"
    onPressed: root.toggle()
  }
  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(480))
    contentHeight: popup.fittedContentHeight(Style.space(650), Style.space(650))
    focusTarget: content
    FocusScope {
      id: content
      anchors.fill: parent
      Keys.onEscapePressed: root.close()
      ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
          Layout.fillWidth: true
          Text { text: "System resources"; font.pixelSize: 22; font.bold: true; color: Commons.Color.foreground; Layout.fillWidth: true }
          ResourceButton { text: "×"; onClicked: root.close() }
        }
        Text { text: "Live · updates every 2 seconds"; color: Commons.Color.muted; font.pixelSize: 12 }
        Repeater {
          model: root.report ? [
            {label: "CPU", detail: root.report.cpu + "%", percent: root.report.cpu},
            {label: "RAM", detail: root.size(root.report.ramUsed) + " / " + root.size(root.report.ramTotal), percent: 100 * root.report.ramUsed / root.report.ramTotal}
          ].concat(root.report.disks.map(function(d) { return {label: "Disk " + d.path, detail: root.size(d.used) + " / " + root.size(d.total) + " · " + d.percent + "%", percent: d.percent} })) : []
          ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
              Layout.fillWidth: true
              Text { text: modelData.label; color: Commons.Color.foreground; Layout.fillWidth: true }
              Text { text: modelData.detail; color: Commons.Color.muted }
            }
            Controls.ProgressBar {
              id: meter
              Layout.fillWidth: true; from: 0; to: 100; value: modelData.percent
              background: Rectangle { implicitHeight: 6; radius: 3; color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.10) }
              contentItem: Item { implicitHeight: 6; Rectangle { width: parent.width * meter.visualPosition; height: parent.height; radius: 3; color: Commons.Color.accent } }
            }
          }
        }
        Text { text: "TOP 10 PROCESSES BY RAM"; color: Commons.Color.muted; font.pixelSize: 12; font.letterSpacing: 1 }
        Controls.ScrollView {
          id: scroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: availableWidth
          ColumnLayout {
            width: scroll.availableWidth
            spacing: 2
            Repeater {
              model: root.report ? root.report.processes : []
              RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { text: modelData.name; textFormat: Text.PlainText; color: Commons.Color.foreground; Layout.fillWidth: true; elide: Text.ElideRight }
                  Text { text: "PID " + modelData.pid; color: Commons.Color.muted; font.pixelSize: 11 }
                }
                Text { text: (modelData.rss / 1048576).toFixed(0) + " MiB"; color: Commons.Color.foreground }
                ResourceButton {
                  text: "Kill"
                  enabled: modelData.killable && !terminateProc.running
                  onClicked: { root.pending = modelData; root.message = "" }
                }
              }
            }
          }
        }
        ColumnLayout {
          visible: root.pending !== null
          Layout.fillWidth: true
          Text { text: root.pending ? "Stop " + root.pending.name + " (PID " + root.pending.pid + ")? Unsaved work may be lost." : ""; textFormat: Text.PlainText; color: Commons.Color.foreground; wrapMode: Text.Wrap; Layout.fillWidth: true }
          RowLayout {
            ResourceButton { text: "Terminate"; enabled: !terminateProc.running; onClicked: { terminateProc.command = ["python3", root.helper, "terminate", String(root.pending.pid), root.pending.start]; terminateProc.running = true } }
            ResourceButton { text: "Cancel"; onClicked: root.pending = null }
          }
        }
        Text { visible: text !== ""; text: root.message; textFormat: Text.PlainText; color: Commons.Color.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: 12 }
      }
    }
  }
}
