#!/bin/bash
# Power off the Thunderbolt controller (ACPI slot 1-1) so no PCIe tunnel is
# left active across a warm reboot; the BIOS then POSTs without the TB device.
S=/sys/bus/pci/slots/1-1/power
[ -w "$S" ] || { echo "tbt-slot-off: $S not writable"; exit 0; }
echo "tbt-slot-off: powering off thunderbolt slot" > /dev/kmsg
timeout 20 bash -c "echo 0 > $S" && echo "tbt-slot-off: done" > /dev/kmsg || echo "tbt-slot-off: FAILED/timeout" > /dev/kmsg
exit 0
