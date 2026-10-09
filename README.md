# omarchy-qemu-plugin

![Preview](preview.png)

QEMU/libvirt VM manager widget for Omarchy. Monitor and control your virtual machines directly from the bar.

## Features

- Lists all VMs registered in libvirt
- Discovers the current user's running standalone `qemu-system-*` processes
- Shows state, host RSS, configured guest RAM, and disk statistics
- Shows standalone VM names, process IDs, and host port forwarding
- Starts and stops libvirt VMs with one click and opens the console when starting
- Reports libvirt connection failures while continuing to show standalone VMs

## Requirements

- Omarchy and Python 3.9 or newer (standard library only)
- QEMU for standalone VMs; libvirt is optional
- For libvirt inventory and controls: libvirt configured for `qemu:///system`,
  access to that connection (usually membership in the `libvirt` group), and
  `virt-manager` for console access

## Installation

```bash
omarchy plugin add https://github.com/pacman-vzla/omarchy-qemu-plugin.git --enable
```

## Usage

Click the VM icon in the bar to open the panel. Libvirt VMs have "Start" and
"Shutdown" buttons. Starting a VM also opens its console.

Standalone VMs appear while their QEMU process exists. Start and stop them with
their existing launchers or guest tools; the panel provides status only for
these VMs. Open disk descriptors identify daemonized VMs even when QEMU has
changed its working directory to `/`.

For a `-monitor unix:...` HMP socket, the helper queries only `info status` with
a short timeout. Relative sockets are resolved beside the first open disk image.
If the monitor is absent, busy, or inaccessible, the VM appears as `process
running`; this fallback does not establish whether the guest is paused.

Host RSS and configured guest RAM are shown in MiB. Standalone disk allocation
is measured on the host filesystem in GiB. These values are not guest RAM usage
or guest filesystem free space. Recognized standalone disk image suffixes are
`qcow2`, `qcow`, `raw`, and `img`; other formats can appear but may lack a friendly
directory name or disk statistics. Only the current user's processes are read,
and libvirt process signatures are excluded to avoid duplicate entries.

Status queries use a read-only libvirt connection with subprocess timeouts.
Libvirt connection errors appear in the panel. Standalone discovery requires
neither libvirt nor membership in the `libvirt` group.

## Localization

Common panel labels are in English by default. To switch them between English
and Spanish, use the included script. Backend status and the new standalone
metadata labels remain in English.

```bash
# Switch to Spanish
~/.config/omarchy/plugins/dix.qemu/scripts/set-language es

# Switch back to English
~/.config/omarchy/plugins/dix.qemu/scripts/set-language en
```

> Note: if you update the plugin with `omarchy plugin update`, the language will reset to English and you will need to run the script again.


## Sudoers

No sudo required — uses `qemu:///system` via libvirt directly.

## Removal

```bash
omarchy plugin disable dix.qemu
omarchy plugin remove dix.qemu
```

## Development

Run the status-helper tests without starting or changing any VM:

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/vm-status-libvirt scripts/set-language
```
