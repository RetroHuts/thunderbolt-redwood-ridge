# Changelog

## 0.1.0 - 2026-10-31

* Kernel patch: Redwood Ridge 2C/4C NHI ids, placeholder root switch, device
  tracking with `rr_devices` / `rr_policy` / `rr_approve` sysfs attributes and
  uevents, `thunderbolt.rr_policy=` module parameter.
* `tbt-rr` CLI: list / approve / allowlist / policy / apply / monitor.
* udev rule and systemd units for allowlist auto-approval and the
  pre-reboot controller power-off hook.
* DKMS packaging, install/uninstall scripts, CI build against Ubuntu headers.
