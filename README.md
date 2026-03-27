# xv6e

![Platform](https://img.shields.io/badge/platform-x86-lightgrey)
![Language](https://img.shields.io/badge/language-C%20%2F%20Assembly-blue)
![Build](https://img.shields.io/badge/build-Makefile-informational)
![Status](https://img.shields.io/badge/status-active-success)

This repository is my attempt at extending the xv6 operating system by modernizing its systems and pushing it toward as much maturity as possible while keeping the codebase educational, understandable, and hackable.

## Project Goals

- Keep xv6's teaching value and simplicity.
- Modernize repository organization into clearer subsystems.
- Improve build ergonomics with out-of-tree artifacts.
- Make iterative kernel experimentation easier and safer.
- Keep compatibility with x86 + QEMU workflows.

## What Has Been Modernized

- Reorganized source tree into architecture and subsystem folders.
- Split kernel implementation by domain (core, fs, dev, proc, sync, mm, etc.).
- Moved headers into subsystem-specific include paths.
- Upgraded build pipeline to use dedicated output folders under `build/`.

## Repository Structure

```text
.
|-- arch/
|   `-- x86/
|       |-- boot/            # bootstrap code
|       `-- kernel/          # arch-specific kernel asm/entry code
|-- include/
|   |-- arch/x86/            # arch headers
|   |-- core/                # core system headers
|   |-- dev/                 # device headers
|   |-- fs/                  # filesystem headers
|   |-- mm/                  # memory-management headers
|   |-- proc/                # process headers
|   |-- sync/                # locking/sync headers
|   `-- user/                # user ABI headers
|-- kernel/
|   |-- core/                # traps/syscalls/exec/main
|   |-- dev/                 # console, ide, uart, apic, etc.
|   |-- fs/                  # filesystem + log + file layer
|   |-- ipc/                 # pipe
|   |-- lib/                 # kernel string/runtime helpers
|   |-- mm/                  # kalloc, vm, heap allocators
|   |-- proc/                # process scheduler and state
|   |-- smp/                 # multiprocessor init
|   `-- sync/                # spinlock/sleeplock
|-- linker/                  # linker scripts
|-- scripts/                 # build helper scripts
|-- tools/                   # host-side build tools (mkfs)
|-- user/                    # user-space programs and user libs
`-- Makefile
```

## Build System

The build is fully out-of-tree.

- Objects: `build/obj/`
- Binaries and images: `build/bin/`
- Generated sources: `build/gen/`
- Disassembly: `build/asm/`
- Symbol dumps: `build/sym/`

## Prerequisites

- GNU Make
- QEMU (`qemu`, `qemu-system-i386`, or `qemu-system-x86_64`)
- 32-bit x86 ELF cross toolchain (`i686-elf-gcc`, `i686-elf-ld`, etc.)

By default, this Makefile expects:

```text
/home/sirjanh/i686-elf-tools-linux/bin/i686-elf-*
```

You can override this at build time:

```sh
make TOOLCHAIN_ROOT=/path/to/toolchain
# or
make TOOLPREFIX=/path/to/bin/i686-elf-
```

## Quick Start

Build the bootable xv6 image:

```sh
make clean && make -j2 build/bin/xv6.img
```

Run with QEMU:

```sh
make qemu
```

Run headless:

```sh
make qemu-nox
```

Run memory-fs variant:

```sh
make qemu-memfs
```

## Common Make Targets

- `make` or `make all`: build default xv6 image
- `make qemu`: run with graphical QEMU
- `make qemu-nox`: run in terminal mode
- `make qemu-gdb`: start QEMU waiting for gdb
- `make qemu-nox-gdb`: headless + gdb wait
- `make clean`: remove build outputs

## Development Notes

- This is an actively evolving fork with structural modernization work in progress.
- The intent is to increase maturity without sacrificing readability.
- Directory and build conventions are designed to support continued subsystem-level refactoring.

## Roadmap (High Level)

- Continue improving subsystem boundaries.
- Introduce stricter kernel coding and testing conventions.
- Improve diagnostics and debugging workflows.
- Expand documentation for architecture and memory internals.

## Upstream Lineage and Credits

This project is built on top of xv6, a re-implementation of UNIX v6 for teaching operating systems.

Original xv6 acknowledgments apply, including inspiration and contributions from the MIT PDOS community and related open-source systems work (JOS, Plan 9, FreeBSD, NetBSD).

For original xv6 learning resources, see:

- https://pdos.csail.mit.edu/6.828/
- https://github.com/mit-pdos/xv6-riscv

## License

See [LICENSE](LICENSE).