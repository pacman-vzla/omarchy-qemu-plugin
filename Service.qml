import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // [{ name, state, ip, ramUsed, ramTotal, ramCache (MiB), diskUsed, diskTotal (GiB),
  //    cpu (0-100, or -1 until two samples exist), vcpus,
  //    pending ("" | "starting" | "stopping" | "resuming") }]
  property var vms: []
  property bool error: false
  property bool loaded: false
  // Poll faster while the panel is open.
  property bool fast: false

  readonly property string script: Quickshell.env("HOME") +
    "/.config/omarchy/plugins/dix.qemu/scripts/vm-status"
  readonly property string uri: "qemu:///system"

  function isActive(v) {
    return (v.state !== "shut_off" && v.state !== "crashed") || v.pending === "starting"
  }

  readonly property var activeVms: vms.filter(function(v) { return root.isActive(v) })
  readonly property var stoppedVms: vms.filter(function(v) { return !root.isActive(v) })
  readonly property int runningCount: vms.filter(function(v) { return v.state === "running" }).length
  readonly property real totalRamMb: {
    var t = 0
    for (var i = 0; i < vms.length; i++)
      if (vms[i].state === "running") t += vms[i].ramUsed || 0
    return t
  }

  // name -> { action, since }
  property var _pending: ({})
  // name -> { cpu: ns, at: ms }
  property var _cpuPrev: ({})
  property var _cpuPct: ({})
  property var _lastRaw: []

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function _setPending(name, action) {
    var p = Object.assign({}, _pending)
    if (action) p[name] = { action: action, since: Date.now() }
    else delete p[name]
    _pending = p
    _rebuild(_lastRaw)
  }

  // name -> { message, at } for the last failed action; cleared after a while.
  property var errors: ({})

  // Runs a virsh action and reports failures instead of leaving the VM stuck
  // in a pending state. stderr is merged into stdout and the exit code is
  // appended as the last line so one collector sees everything.
  Component {
    id: actionComponent
    Process {
      id: proc
      property string vmName: ""
      property bool openConsoleOnSuccess: false
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          root._actionDone(proc.vmName, text, proc.openConsoleOnSuccess)
          proc.destroy()
        }
      }
    }
  }

  function _run(name, args, openConsoleOnSuccess) {
    _clearError(name)
    var p = actionComponent.createObject(root, {
      vmName: name,
      openConsoleOnSuccess: !!openConsoleOnSuccess,
      command: ["sh", "-c", '"$@" 2>&1; echo "__rc=$?"', "sh", "virsh", "-c", uri].concat(args)
    })
    p.running = true
  }

  function _actionDone(name, output, openConsoleOnSuccess) {
    var lines = String(output || "").split("\n").map(function(l) { return l.trim() })
      .filter(function(l) { return l !== "" })
    var rcLine = lines.filter(function(l) { return l.indexOf("__rc=") === 0 }).pop() || "__rc=1"
    var rc = parseInt(rcLine.substring(5))
    if (rc === 0) {
      if (openConsoleOnSuccess) openConsole(name)
    } else {
      // virsh prints a generic "error: Failed to ..." line followed by the cause.
      var errs = lines.filter(function(l) { return l.indexOf("__rc=") !== 0 })
        .map(function(l) { return l.replace(/^error:\s*/i, "") })
      var msg = errs.length > 0 ? errs[errs.length - 1] : "virsh exited with " + rc
      _setPending(name, "")
      var e = Object.assign({}, errors)
      e[name] = { message: msg, at: Date.now() }
      errors = e
      Quickshell.execDetached(["notify-send", "-a", "QEMU", "-u", "critical", name, msg])
    }
    refresh()
  }

  function _clearError(name) {
    if (!errors[name]) return
    var e = Object.assign({}, errors)
    delete e[name]
    errors = e
  }

  function start(name)     { _setPending(name, "starting"); _run(name, ["start", name], true) }
  function stop(name)      { _setPending(name, "stopping"); _run(name, ["shutdown", name]) }
  function forceStop(name) { _setPending(name, "stopping"); _run(name, ["destroy", name]) }
  function resume(name)    { _setPending(name, "resuming"); _run(name, ["resume", name]) }

  Timer {
    // Drop error hints after 20 s.
    interval: 5000
    repeat: true
    running: Object.keys(root.errors).length > 0
    onTriggered: {
      var now = Date.now(), e = {}, changed = false
      for (var k in root.errors) {
        if (now - root.errors[k].at < 20000) e[k] = root.errors[k]
        else changed = true
      }
      if (changed) root.errors = e
    }
  }

  function openConsole(name) {
    Quickshell.execDetached(["virt-manager", "--connect", uri, "--show-domain-console", name])
  }

  function openManager() {
    Quickshell.execDetached(["virt-manager", "--connect", uri])
  }

  function copy(text) {
    Quickshell.execDetached(["wl-copy", text])
  }

  // name -> last seen state, to detect VMs that just shut down.
  property var _lastStates: ({})

  function _closeConsolesForStopped(raw) {
    var next = {}, stopped = []
    for (var i = 0; i < raw.length; i++) {
      var v = raw[i]
      next[v.name] = v.state
      var before = _lastStates[v.name]
      var isOff = v.state === "shut_off" || v.state === "crashed"
      if (before !== undefined && before !== "shut_off" && before !== "crashed" && isOff)
        stopped.push(v.name)
    }
    _lastStates = next
    if (stopped.length === 0) return
    var c = consoleCloser.createObject(root, { names: stopped })
    c.running = true
  }

  // Hyprland >= 0.55 takes Lua dispatchers; older versions the classic syntax.
  // Try the Lua form first and fall back if it is rejected.
  function _closeWindow(address) {
    if (!/^0x[0-9a-fA-F]+$/.test(address)) return
    Quickshell.execDetached(["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.window.close({ window = \\"address:$1\\" })" 2>&1); ' +
      'case "$out" in ok*) ;; *) hyprctl dispatch closewindow "address:$1" ;; esac', "sh", address])
  }

  // Closes virt-manager console windows ("<vm> on QEMU/KVM", localized) via Hyprland.
  Component {
    id: consoleCloser
    Process {
      id: closer
      property var names: []
      command: ["hyprctl", "clients", "-j"]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          var clients = []
          try { clients = JSON.parse(text) } catch (e) {}
          for (var i = 0; i < clients.length; i++) {
            var w = clients[i]
            if (String(w.class).toLowerCase() !== "virt-manager") continue
            for (var j = 0; j < closer.names.length; j++) {
              var n = closer.names[j]
              // Title is "<vm> on QEMU/KVM" (localized), optionally prefixed by a
              // "Press Ctrl+Alt to release pointer." hint while input is grabbed.
              var t = String(w.title)
              var esc = n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
              if (new RegExp("(^|\\. )" + esc + " \\S+ QEMU/").test(t))
                root._closeWindow(String(w.address))
            }
          }
          closer.destroy()
        }
      }
    }
  }

  function _rebuild(raw) {
    var now = Date.now()
    var pending = Object.assign({}, _pending)
    var changed = false
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var v = Object.assign({}, raw[i])
      var p = pending[v.name]
      if (p) {
        var done = (p.action === "stopping")
          ? (v.state === "shut_off" || v.state === "crashed")
          : v.state === "running"
        // Graceful shutdown can take a while; drop the hint after 3 minutes.
        if (done || now - p.since > 180000) { delete pending[v.name]; changed = true; p = null }
      }
      v.pending = p ? p.action : ""
      var c = _cpuPct[v.name]
      v.cpu = (v.state === "running" && c !== undefined) ? c : -1
      out.push(v)
    }
    if (changed) _pending = pending
    vms = out
  }

  Process {
    id: statusProcess
    command: [root.script]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.split("\n")
        var map = {}, order = [], err = false
        var now = Date.now()
        var prev = root._cpuPrev, nextPrev = {}, pct = {}
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split("\t")
          var key = f[0]
          if (key === "error") { err = true; continue }
          if (key === "vm" && f.length >= 3) {
            map[f[1]] = { name: f[1], state: f[2], ip: "", ramUsed: 0, ramTotal: 0, ramCache: 0,
                          diskUsed: 0, diskTotal: 0, vcpus: 0 }
            order.push(f[1])
            continue
          }
          var vm = map[f[1]]
          if (!vm) continue
          if (key === "vm_ram" && f.length >= 4) {
            vm.ramTotal = Math.round(parseInt(f[3]) / 1024)
            var used = Math.round(parseInt(f[2]) / 1024)
            vm.ramUsed = vm.ramTotal > 0 ? Math.min(used, vm.ramTotal) : used
            vm.ramCache = f.length >= 5 ? Math.round(parseInt(f[4]) / 1024) : 0
          } else if (key === "vm_disk" && f.length >= 4) {
            vm.diskUsed = parseInt(f[2]) / 1073741824
            vm.diskTotal = parseInt(f[3]) / 1073741824
          } else if (key === "vm_cpu" && f.length >= 4) {
            var t = parseFloat(f[2]), n = Math.max(1, parseInt(f[3]))
            vm.vcpus = n
            nextPrev[vm.name] = { cpu: t, at: now }
            var p = prev[vm.name]
            if (p && now > p.at && t >= p.cpu)
              pct[vm.name] = Math.max(0, Math.min(100, (t - p.cpu) / ((now - p.at) * 1e6) / n * 100))
          } else if (key === "vm_ip" && f.length >= 3) {
            vm.ip = f[2]
          }
        }
        root._cpuPrev = nextPrev
        root._cpuPct = pct
        root.error = err
        root.loaded = true
        var raw = order.map(function(n) { return map[n] })
        root._closeConsolesForStopped(raw)
        root._lastRaw = raw
        root._rebuild(raw)
      }
    }
  }

  Timer {
    interval: root.fast ? 2000 : 8000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onFastChanged: if (fast) refresh()
}
