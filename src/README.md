# src/

Copy of `drivers/thunderbolt/` from the Ubuntu 24.04 kernel source
(`linux-source-6.8.0`, 6.8.12) with `patches/0001-*.patch` applied.
Only `nhi.c` and `icm.c` differ from upstream. Licensed GPL-2.0 like the kernel.

Build out of tree against the running kernel:

    make -C /lib/modules/$(uname -r)/build M=$PWD modules
