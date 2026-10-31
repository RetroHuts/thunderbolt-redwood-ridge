# Test notes (ThinkPad W540, BIOS GNET94WW 2.42, Linux Mint 22, kernel 6.8.0-106)

Device under test: Apple A1463 Thunderbolt-to-FireWire adapter (LSI FW643, `11c1:5901`),
plugged into the Thunderbolt port on the laptop body, laptop on the Ultra Dock.

## Driver

| Step | Result |
|---|---|
| stock `thunderbolt` module | no id match; forced bind -> `timeout reading config space 2 from 0x0`, probe fails |
| ids added only | NULL dereference in `icm_fr_device_connected` -> `switch_find_xdomain` (root switch has no ports) |
| placeholder root + direct approve | firmware builds tunnel within 1 s, `0b:00.0 FireWire ... FW643` appears, `firewire_ohci` binds |
| cold boot with device attached | device reported `authorized=1` by firmware (approval persisted), tunnel present at POST |
| `rmmod` / `modprobe` cycles | clean; sysfs attributes created and removed |
| probing host router config at start | adds 20 s to every boot (4 x 5 s timeout) -> skipped for Redwood Ridge |

## Automated warm-reboot cycles

Metric per cycle: time until ping is lost after `systemctl reboot`, time until SSH
is back, firmware/kernel time from `systemd-analyze`, whether the BIOS left the
NVIDIA BARs unassigned (`nvidia-assign-fail`), whether X.org crashed.

| Configuration | Cycles | NVIDIA BAR unassigned | X crash loop | kernel time | ping lost after |
|---|---|---|---|---|---|
| before any fix (from journal) | 2 failed boots | 2/2 | 2/2 | 22 s | - |
| + X pinned to Intel | 3 | 2/3 | 0 | 22 s | 8-10 s |
| + `pci=realloc=on` | 4 | 4/4 | 0 | 3 s | 6-10 s, **NHI lost its BAR, FireWire gone** (reverted) |
| + skip host-router probe, slot-off hook | 4 | 3/4 | 0 | 2-3 s | 6-12 s |

In every cycle the EFI pstore dump contained `reboot: Restarting system`, i.e. the
kernel side of the reboot completed. The reported occasional hang at "rebooting"
was not reproduced; if it recurs the pstore dump will show whether the kernel got
that far.

## BIOS resource allocation failure

Bad boot (`journalctl -b`):

```
pci 0000:00:02.0: BAR 2 [mem 0x00000000-0x1fffffff 64bit pref]      <- iGPU, unassigned by BIOS
pci 0000:01:00.0: BAR 1 [mem 0x00000000-0x0fffffff 64bit pref]      <- NVIDIA, unassigned by BIOS
pci 0000:00:01.0: bridge window [mem size 0x18000000 64bit pref]: can't assign; no space
pci 0000:01:00.0: vgaarb: setting as boot VGA device (overriding previous)
```

X.org then logs `(--) PCI:*(1@0:0:0) 10de:11fc` as primary, fails to open
`/dev/dri/card0` and exits; lightdm restarts it until it gives up.
Good boots have `BAR 1 [mem 0xa0000000-0xafffffff 64bit pref]` for the NVIDIA.
The failure only happens when the Thunderbolt-attached device is enumerated
by the BIOS at POST and is independent of the OS (it also happened on the first
Linux boot after authorizing the device in Windows 7).
