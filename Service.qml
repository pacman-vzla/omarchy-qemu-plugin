import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var vms: []
  property string warning: ""
  property bool busy: false
  readonly property string script: Quickshell.env("HOME") + "/.config/omarchy/plugins/dix.qemu/scripts/vm-status"
  readonly property int runningCount: vms.filter(vm => vm.active).length

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }
  function managed(name) {
    return vms.some(vm => vm.name === name && vm.backend === "libvirt")
  }
  function start(name) {
    if (busy || !managed(name)) return
    busy = true
    actionProcess.command = ["virsh", "-c", "qemu:///system", "start", name]
    actionProcess.running = true
  }
  function stop(name) {
    if (busy || !managed(name)) return
    busy = true
    actionProcess.command = ["virsh", "-c", "qemu:///system", "shutdown", name]
    actionProcess.running = true
  }
  function forceStop(name) {
    if (busy || !managed(name)) return
    busy = true
    actionProcess.command = ["virsh", "-c", "qemu:///system", "destroy", name]
    actionProcess.running = true
  }
  function open(name) {
    if (managed(name)) Quickshell.execDetached(["virt-manager", "--connect", "qemu:///system", "--show-domain-console", name])
  }
  Process {
    id: statusProcess
    command: ["python3", root.script]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const status = JSON.parse(text)
          root.vms = status.vms
          root.warning = status.warning
        } catch (error) {
          root.vms = []
          root.warning = "Could not read VM status."
        }
      }
    }
  }
  Process {
    id: actionProcess
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      root.refresh()
      if (exitCode !== 0) console.warn("VM action failed: " + actionError.text)
    }
  }
  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
