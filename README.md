# omarchy-qemu-plugin

**[English](#english) · [Español](#español)**

---

## English

![Preview](preview-en.png)

QEMU/libvirt VM manager widget for Omarchy. Monitor and control your virtual machines directly from the bar.

### Features

- Lists all VMs registered in libvirt, grouped into active and stopped
- Live CPU, RAM and disk meters for running VMs. RAM shows guest-reported usage plus reclaimable cache (like `htop`) when the virtio balloon driver is present, host RSS otherwise
- Click-to-copy IP address
- Start, graceful shutdown, force off (while a shutdown is pending) and resume paused VMs
- Shows transitional states ("Starting…", "Shutting down…")
- Opens the VM console when it starts, and closes it automatically when the VM shuts down (also when shut down from inside the guest)
- Failed actions are shown on the VM row and sent as a desktop notification with the reason
- Bar icon turns to the theme accent color while any VM is running; right-click opens virt-manager
- Follows the active Omarchy theme colors and corner style
- Works with any system locale

### Requirements

- QEMU/libvirt installed and running
- User in the `libvirt` group: `sudo usermod -aG libvirt $USER`
- `virt-manager` for console access
- `wl-clipboard` for copying IPs

### Installation

```bash
omarchy plugin add https://github.com/pacman-vzla/omarchy-qemu-plugin.git --enable
```

### Usage

Click the VM icon in the bar to open the panel (right-click opens virt-manager). Click a stopped VM to start it; its console opens once it is up. On a running VM, use the monitor button to open its console and the power button to shut it down gracefully; while it is shutting down the button turns into "Force off".

VMs can also be controlled from the terminal or a keybinding:

```bash
omarchy-shell dix.qemu start <vm>
omarchy-shell dix.qemu shutdown <vm>
omarchy-shell dix.qemu refresh
```

### Language

The plugin displays text in Spanish by default. To change it:

```bash
~/.config/omarchy/plugins/dix.qemu/scripts/set-language en   # English
~/.config/omarchy/plugins/dix.qemu/scripts/set-language es   # Spanish
```

The change applies instantly, no shell restart needed. The choice is stored in `~/.local/state/dix.qemu/lang`, so it survives `omarchy plugin update`.

### Sudo

Not required: uses `qemu:///system` via libvirt directly.

### Removal

```bash
omarchy plugin disable dix.qemu
omarchy plugin remove dix.qemu
```

---

## Español

![Vista previa](preview.png)

Widget de Omarchy para administrar máquinas virtuales de QEMU/libvirt. Monitorea y controla tus VMs directamente desde la barra.

### Funciones

- Lista todas las VMs registradas en libvirt, separadas en activas y apagadas
- Barras en vivo de CPU, RAM y disco para las VMs encendidas. La RAM muestra el uso real dentro de la VM más la caché liberable (como `htop`) si la VM tiene el driver virtio balloon; si no, muestra lo que ocupa en el host
- Copia la IP con un clic
- Iniciar, apagar, forzar apagado (mientras se está apagando) y reanudar VMs en pausa
- Muestra estados intermedios ("Iniciando…", "Apagando…")
- Abre la consola de la VM al iniciarla y la cierra sola cuando la VM se apaga (también si se apaga desde dentro)
- Si una acción falla, se muestra en la fila de la VM y llega una notificación con el motivo
- El ícono de la barra toma el color de acento del tema cuando hay alguna VM encendida; con clic derecho abre virt-manager
- Usa los colores y el estilo de esquinas del tema activo de Omarchy
- Funciona con cualquier idioma del sistema

### Requisitos

- QEMU/libvirt instalados y en ejecución
- Usuario en el grupo `libvirt`: `sudo usermod -aG libvirt $USER`
- `virt-manager` para abrir la consola
- `wl-clipboard` para copiar IPs

### Instalación

```bash
omarchy plugin add https://github.com/pacman-vzla/omarchy-qemu-plugin.git --enable
```

### Uso

Haz clic en el ícono de VM de la barra para abrir el panel (clic derecho abre virt-manager). Haz clic en una VM apagada para iniciarla; su consola se abre cuando arranca. En una VM encendida, el botón del monitor abre la consola y el botón de encendido la apaga de forma ordenada; mientras se apaga, ese botón cambia a "Forzar apagado".

También se pueden controlar desde la terminal o con un atajo de teclado:

```bash
omarchy-shell dix.qemu start <vm>
omarchy-shell dix.qemu shutdown <vm>
omarchy-shell dix.qemu refresh
```

### Idioma

El plugin muestra los textos en español por defecto. Para cambiarlo:

```bash
~/.config/omarchy/plugins/dix.qemu/scripts/set-language en   # inglés
~/.config/omarchy/plugins/dix.qemu/scripts/set-language es   # español
```

El cambio se aplica al instante, sin reiniciar el shell. La elección se guarda en `~/.local/state/dix.qemu/lang`, así que se mantiene después de `omarchy plugin update`.

### Sudo

No hace falta: usa `qemu:///system` directamente a través de libvirt.

### Desinstalación

```bash
omarchy plugin disable dix.qemu
omarchy plugin remove dix.qemu
```
