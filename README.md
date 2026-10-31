# thunderbolt-redwood-ridge

Linux support for **Intel Redwood Ridge** Thunderbolt 1 host controllers
(DSL4410 / DSL4510, PCI `8086:1566` / `8086:1568`), as found in the
ThinkPad W540 / W541 / T440p era machines, plus a small tool to view and
authorize connected Thunderbolt devices.

The mainline `thunderbolt` driver has no entry for these controllers, so on
Linux the firmware never builds a PCIe tunnel and devices such as the Apple
Thunderbolt-to-FireWire adapter (A1463) or Thunderbolt docks stay invisible,
even though they work in Windows with the Intel Thunderbolt software.

This project ships:

| Part | What it does |
|---|---|
| `patches/0001-*.patch` | Kernel patch: adds the Redwood Ridge NHI IDs and a "placeholder root switch" mode for firmware that does not expose the host router config space. Devices reported by the ICM firmware are tracked and approved through sysfs. |
| `src/` | `drivers/thunderbolt` from Ubuntu 24.04 (6.8) with the patch applied, buildable out of tree / via DKMS. |
| `tools/tbt-rr` | CLI to list devices, approve them, keep an allowlist, switch between `auto` and `manual` policy, and prompt interactively (zenity). |
| `udev/`, `systemd/` | Auto-approve allowlisted devices on hot-plug and at boot; optional hook that powers the controller off before reboot. |
| `xorg/` | Optional X.org snippet pinning the screen to the Intel iGPU (see *Known firmware issues*). |

Tested on a ThinkPad W540 (BIOS 2.42, Linux Mint 22 / kernel 6.8.0-106) with an
Apple A1463 Thunderbolt-to-FireWire adapter (LSI FW643).

## How it works

On Redwood Ridge the firmware connection manager (ICM) answers the
`DRIVER_READY` handshake and sends `DEVICE_CONNECTED` events, but every read
of the host router config space times out. The stock driver therefore fails to
allocate the root switch and gives up (or crashes when an event arrives).

The patch:

1. adds `8086:1566` / `8086:1568` to the NHI id table;
2. for those IDs allocates a *safe-mode* (placeholder) root switch instead of
   enumerating the host router, so the control channel stays up;
3. handles `DEVICE_CONNECTED` / `DEVICE_DISCONNECTED` by keeping a per-domain
   device list and, with the default `auto` policy, immediately sends
   `ICM_APPROVE_DEVICE` so the firmware builds the PCIe tunnel;
4. exposes the list on the domain in sysfs and emits uevents.

```
/sys/bus/thunderbolt/devices/domain0/
    rr_devices   # "<uuid> <link>.<depth> <authorized|pending> <present|absent> <name>" per line
    rr_policy    # auto | manual   (module parameter: thunderbolt.rr_policy=)
    rr_approve   # write a uuid to approve it
```

Uevents: `ACTION=change SUBSYSTEM=thunderbolt RR_DEVICE=<uuid> RR_STATE=pending|authorized|disconnected`.

Devices that the firmware already authorized (for example after approving them
once in Windows with "Always connect") are reported as `authorized` at boot.

## Install

Requirements: `dkms`, `build-essential`, kernel headers for the running
kernel, `python3`. Secure Boot must be off or you must sign DKMS modules.

```sh
git clone https://github.com/RetroHuts/thunderbolt-redwood-ridge
cd thunderbolt-redwood-ridge
sudo ./install.sh                 # options: --policy manual  --no-slot-off  --xorg-intel-pin
sudo modprobe -r thunderbolt && sudo modprobe thunderbolt   # or reboot
tbt-rr list
```

`install.sh` builds the module with DKMS (so it survives kernel updates),
updates the initramfs, installs `tbt-rr` to `/usr/local/bin`, the udev rule,
and the systemd units. `sudo ./uninstall.sh` restores the stock module.

## Using `tbt-rr`

```
tbt-rr list                       # devices, state and policy
tbt-rr approve 1                  # approve by index, uuid or uuid prefix
tbt-rr approve a0fe -r            # ...and remember it in the allowlist
tbt-rr policy manual --persist    # stop auto-approving; persisted via modprobe.d
tbt-rr allow <uuid>  /  tbt-rr allow --remove <uuid>  /  tbt-rr allowed
tbt-rr apply                      # approve pending allowlisted devices (udev/boot hook)
tbt-rr monitor --prompt           # watch events; ask (zenity or terminal) before approving
```

Allowlist: `/etc/thunderbolt-rr/allowlist` (one UUID per line).
With `manual` policy a new device stays `pending` until approved by `tbt-rr`,
the udev rule (if allowlisted) or a write to `rr_approve`.

## Security note

The `auto` policy approves **every** Thunderbolt device, which is equivalent
to security level "none": an attached device gets DMA access through the PCIe
tunnel. The W540-class BIOS has no Thunderbolt security level setting at all
and behaves the same way with the Windows software, so this is not a
regression, but use `--policy manual` plus an allowlist if that matters to you.
Firmware-side disapproval is not available on this ICM generation; to cut a
tunnel, unplug the device or power the controller off
(`echo 0 > /sys/bus/pci/slots/<slot>/power`).

## Known firmware issues (W540)

* **NVIDIA BARs left unassigned.** When a Thunderbolt device is present at
  POST, the BIOS fails to assign the discrete GPU's 256 MB BAR in roughly 60 %
  of boots. The kernel then marks the NVIDIA as boot VGA and X.org's
  autoconfiguration picks it, crashing in a loop (blinking cursor). If you run
  on the Intel iGPU (`prime-select intel`), install with `--xorg-intel-pin`
  to pin X to the iGPU. `pci=realloc` does **not** help; it starves the
  Thunderbolt NHI of resources instead.
* **Slow / stuck warm reboot.** Could not be reproduced in automated testing
  (11 cycles, kernel always reached `reboot: Restarting system`). The
  `tbt-slot-off.service` hook powers the controller off right before reboot so
  no tunnel is active during the firmware reset; disable with `--no-slot-off`.
  `printk.always_kmsg_dump=1` on the kernel command line records the final
  kernel messages in EFI pstore if you need to debug this further.

See `docs/TESTING.md` for the measurements.

## Rollback

```sh
sudo ./uninstall.sh
```

## License

GPL-2.0 (kernel code), see `LICENSE`. Kernel sources are
Copyright (C) Intel Corporation and other kernel contributors.

---

### 中文简介

本项目为 Intel Redwood Ridge（DSL4410/DSL4510，PCI ID `8086:1566`/`1568`）
雷电 1 控制器提供 Linux 驱动补丁：主线驱动没有这颗控制器的 ID，固件也不开放
主控路由器配置空间，补丁用占位根交换机维持控制通道，并在收到设备连接事件时
向固件发送批准请求建立 PCIe 隧道。`tbt-rr` 工具可查看设备、手动批准、维护白名单，
`auto` 策略等同于 Windows 下"始终连接"所有设备。安装：`sudo ./install.sh`，
卸载：`sudo ./uninstall.sh`。已在 ThinkPad W540 + Apple A1463 雷电转 FireWire
转换器上验证。
