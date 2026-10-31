#!/bin/bash
# Remove the Redwood Ridge driver and tooling, restoring the stock module.
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
for v in $(dkms status 2>/dev/null | grep -oE 'thunderbolt-rr/[0-9.]+' | sort -u); do dkms remove "$v" --all; done
rm -rf /usr/src/thunderbolt-rr-*
systemctl disable --now tbt-slot-off.service tbt-rr-apply.service 2>/dev/null
rm -f /etc/systemd/system/tbt-slot-off.service /etc/systemd/system/tbt-rr-apply.service
systemctl daemon-reload
rm -f /etc/udev/rules.d/90-thunderbolt-rr.rules; udevadm control --reload
rm -f /usr/local/bin/tbt-rr /usr/local/sbin/tbt-slot-off.sh /etc/modprobe.d/thunderbolt-rr.conf
rm -f /etc/X11/xorg.conf.d/20-intel-primary.conf
depmod -a; update-initramfs -u
echo "removed. Stock thunderbolt module: $(modinfo -n thunderbolt 2>/dev/null). Allowlist kept in /etc/thunderbolt-rr (delete manually)."
