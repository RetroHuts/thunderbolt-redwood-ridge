#!/bin/bash
# Install the Redwood Ridge thunderbolt driver (DKMS) plus the tbt-rr tooling.
set -euo pipefail
cd "$(dirname "$0")"
VER=$(cat VERSION)
SLOT_OFF=1; XORG_PIN=0; POLICY=""
usage() { echo "usage: $0 [--no-slot-off] [--xorg-intel-pin] [--policy auto|manual]"; exit 1; }
while [ $# -gt 0 ]; do
  case $1 in
    --no-slot-off) SLOT_OFF=0;;
    --xorg-intel-pin) XORG_PIN=1;;
    --policy) POLICY=${2:-}; shift; [ "$POLICY" = auto ] || [ "$POLICY" = manual ] || usage;;
    -h|--help) usage;;
    *) usage;;
  esac; shift
done
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
for c in dkms make gcc python3; do command -v $c >/dev/null || { echo "missing: $c (apt install dkms build-essential python3)"; exit 1; }; done
[ -d "/lib/modules/$(uname -r)/build" ] || { echo "missing kernel headers for $(uname -r) (apt install linux-headers-$(uname -r))"; exit 1; }
if ! lspci -n 2>/dev/null | grep -qE '8086:(1566|1568)'; then
  echo "warning: no Intel Redwood Ridge NHI (8086:1566/1568) found on this machine; installing anyway"
fi

echo "== DKMS module thunderbolt-rr/$VER"
for old in $(dkms status 2>/dev/null | grep -oE 'thunderbolt-rr/[0-9.]+' | sort -u); do dkms remove "$old" --all || true; done
rm -rf "/usr/src/thunderbolt-rr-$VER"; mkdir -p "/usr/src/thunderbolt-rr-$VER"
cp src/*.c src/*.h src/Makefile "/usr/src/thunderbolt-rr-$VER/"
sed "s/@VERSION@/$VER/" dkms.conf.in > "/usr/src/thunderbolt-rr-$VER/dkms.conf"
dkms add "thunderbolt-rr/$VER"
dkms build "thunderbolt-rr/$VER"
dkms install "thunderbolt-rr/$VER"
depmod -a
update-initramfs -u

echo "== tools"
install -m 0755 tools/tbt-rr /usr/local/bin/tbt-rr
install -m 0755 tools/tbt-slot-off.sh /usr/local/sbin/tbt-slot-off.sh
install -m 0644 udev/90-thunderbolt-rr.rules /etc/udev/rules.d/
udevadm control --reload
install -m 0644 systemd/tbt-rr-apply.service systemd/tbt-slot-off.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable tbt-rr-apply.service >/dev/null
if [ $SLOT_OFF = 1 ]; then systemctl enable --now tbt-slot-off.service >/dev/null; else systemctl disable --now tbt-slot-off.service >/dev/null 2>&1 || true; fi
if [ $XORG_PIN = 1 ]; then install -D -m 0644 xorg/20-intel-primary.conf /etc/X11/xorg.conf.d/20-intel-primary.conf; fi
if [ -n "$POLICY" ]; then printf '# written by thunderbolt-redwood-ridge install.sh\noptions thunderbolt rr_policy=%s\n' "$POLICY" > /etc/modprobe.d/thunderbolt-rr.conf; fi

echo
echo "installed. Load the new driver now with:"
echo "    modprobe -r thunderbolt && modprobe thunderbolt     (or reboot)"
echo "then run:  tbt-rr list"
