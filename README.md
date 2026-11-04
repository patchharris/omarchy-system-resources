# Omarchy System Resources

A system resources popup for the Omarchy Quickshell bar. Click the memory-chip icon to see CPU, RAM and disk usage, plus the ten processes using the most RAM.

## Features

- CPU utilization, sampled over 200 ms.
- RAM usage calculated from total minus available memory.
- Used and total disk space for `/`.
- Top ten processes by resident memory (RSS), with process names, PIDs and memory in MiB.
- A Kill button beside each eligible process, followed by confirmation.
- Updates every two seconds while the popup is open.
- Uses your Omarchy theme; closes with Escape or a click outside the popup.

## Requirements

Omarchy with the Quickshell plugin system (`omarchy plugin`), Python 3.9 or newer, and Linux with pidfd support. The plugin uses Omarchy's shared QML components and is not a standalone Quickshell application.

## Install

```bash
omarchy plugin add https://github.com/patchharris/omarchy-system-resources.git
omarchy plugin enable patchharris.resources --section right
```

To put it beside Bluetooth and Wi-Fi, move the `patchharris.resources` entry in `~/.config/omarchy/shell.json` between `omarchy.bluetooth` and `omarchy.network` in `bar.layout.right`. The shell reloads layout changes automatically.

If you already have a manually installed `patchharris.resources` plugin, back up that directory before installing this repository; the plugin ID is the same.

## Process termination

Click **Kill**, then **Terminate** to send SIGTERM. Applications can handle or ignore this signal; the plugin does not force-kill them. Unsaved work may be lost.

Termination is limited to processes owned by the current user. PID 1, the collection helper and its parent shell process are protected. The helper checks the process start time and sends the signal through a pidfd to avoid terminating an unrelated process after PID reuse. Errors appear in the popup.

## Update or disable

```bash
omarchy plugin update patchharris.resources
omarchy plugin disable patchharris.resources
```

## Files

- `manifest.json`: Omarchy plugin metadata.
- `Panel.qml`: bar button and popup interface.
- `resources.py`: Linux resource collection and process termination helper; uses only Python's standard library.
