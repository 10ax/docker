# ODROID-HC4 Boot Notes

## Host identity

- board: `Hardkernel ODROID-HC4`
- OS: `DietPi` on Debian 12
- kernel observed during investigation: `6.18.5-current-meson64`

## Boot faults seen after the outage

The current boot logs show host-level faults that are separate from AdGuard itself:

- `meson-pcie fc000000.pcie: error: wait linkup timeout`
- `ahci 0000:01:00.0: Unable to change power state from D3cold to D0, device inaccessible`
- `Internal error: Oops` in `ahci_save_initial_config` from `libahci`
- `rtc-pcf8563 0-0051: pcf8563_probe: write error`

## What this means

- The DHCP outage was fixed by hardening the AdGuard startup path.
- The remaining resilience risk is at the ODROID hardware or kernel level.
- The SATA or PCIe initialization fault can still make boot behavior fragile after power loss.
- The RTC error means the board cannot rely on hardware time across a power cut.

## Low-risk changes already applied

- AdGuard now waits for `eth0` to have an IPv4 address before start.
- A timer restarts AdGuard if DNS `53` or DHCP `67` is missing after boot.
- `systemd-timesyncd` is enabled so the host regains correct time quickly after a power cut even though RTC time is unavailable.

## Changes not applied automatically

These were intentionally left manual because they affect hardware features or boot behavior:

1. Disable the HC4 SATA or PCIe path if SATA is truly unused.
2. Change kernel family or pin a different meson64 kernel for testing.
3. Remove or override the RTC node if the board does not have a working RTC path.

## Practical next steps

1. If this host does not need SATA at all, disable the SATA or PCIe controller in the boot device-tree path during a maintenance window.
2. If SATA is required, test a kernel downgrade or upgrade with local console access before making it the default boot kernel.
3. Check the RTC battery or wiring if RTC should exist on this HC4; otherwise treat the RTC error as non-critical noise and rely on network time sync.
4. Keep DHCP on the router rather than this host if you want the LAN to survive ODROID boot faults cleanly.