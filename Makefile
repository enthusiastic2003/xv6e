#--------------------------------------------
# xv6 Makefile (modern out-of-tree build)
#--------------------------------------------

SHELL := /bin/sh
.RECIPEPREFIX := >

# Directories
OUT_DIR ?= build
OBJ_DIR := $(OUT_DIR)/obj
BIN_DIR := $(OUT_DIR)/bin
GEN_DIR := $(OUT_DIR)/gen
ASM_DIR := $(OUT_DIR)/asm
SYM_DIR := $(OUT_DIR)/sym

# Toolchain
TOOLCHAIN_ROOT ?= /home/sirjanh/i686-elf-tools-linux
TOOLPREFIX ?= $(TOOLCHAIN_ROOT)/bin/i686-elf-
CC := $(TOOLPREFIX)gcc
LD := $(TOOLPREFIX)ld
OBJCOPY := $(TOOLPREFIX)objcopy
OBJDUMP := $(TOOLPREFIX)objdump
HOSTCC := gcc

# QEMU detection
ifndef QEMU
QEMU := $(shell if command -v qemu >/dev/null 2>&1; then echo qemu; \
 elif command -v qemu-system-i386 >/dev/null 2>&1; then echo qemu-system-i386; \
 elif command -v qemu-system-x86_64 >/dev/null 2>&1; then echo qemu-system-x86_64; \
 else echo "*** Error: Could not find QEMU"; exit 1; fi)
endif

# Flags
CPPFLAGS := -nostdinc -I. -Iinclude
CFLAGS := -Wno-infinite-recursion -g -fno-pic -static -fno-builtin \
 -Wno-array-bounds -fno-strict-aliasing -Os -Wall -Werror -ggdb -m32 \
 -fno-omit-frame-pointer
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)

# Disable stack protector / PIE when supported
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

ifeq ($(DEEP_VERIFY),1)
CFLAGS += -DDEEP_VERIFY_BOOT
endif

# Sources
KERNEL_C_SRCS := \
 kernel/fs/bio.c \
 kernel/dev/console.c \
 kernel/core/exec.c \
 kernel/fs/file.c \
 kernel/fs/fs.c \
 kernel/dev/ide.c \
 kernel/dev/ioapic.c \
 kernel/dev/kbd.c \
 kernel/dev/lapic.c \
 kernel/fs/log.c \
 kernel/core/main.c \
 kernel/core/mb2.c \
 kernel/smp/mp.c \
 kernel/dev/picirq.c \
 kernel/ipc/pipe.c \
 kernel/proc/proc.c \
 kernel/sync/sleeplock.c \
 kernel/sync/spinlock.c \
 kernel/lib/string.c \
 kernel/core/syscall.c \
 kernel/fs/sysfile.c \
 kernel/core/sysproc.c \
 kernel/core/trap.c \
 kernel/dev/uart.c \
 kernel/mm/kalloc.c \
 kernel/mm/kheap.c \
 kernel/mm/liballoc.c \
 kernel/mm/vm.c

KERNEL_S_SRCS := \
 arch/x86/kernel/segreload.S \
 arch/x86/kernel/swtch.S \
 arch/x86/kernel/trapasm.S

KERNEL_MEMFS_C_SRCS := $(filter-out kernel/dev/ide.c,$(KERNEL_C_SRCS)) kernel/dev/memide.c

USER_PROGS := \
 cat \
 echo \
 forktest \
 grep \
 init \
 kill \
 ln \
 ls \
 mkdir \
 rm \
 sh \
 stressfs \
 usertests \
 wc \
 zombie \
 ps

USER_LIB_SRCS := user/ulib.c user/usys.S user/printf.c user/umalloc.c

# Paths
ENTRY_OBJ := $(OBJ_DIR)/arch/x86/kernel/entry.o
ENTRYOTHER_OBJ := $(OBJ_DIR)/arch/x86/kernel/entryother.o
INITCODE_OBJ := $(OBJ_DIR)/arch/x86/kernel/initcode.o
VECTORS_GEN := $(GEN_DIR)/vectors.S
VECTORS_OBJ := $(OBJ_DIR)/gen/vectors.o

KERNEL_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(KERNEL_C_SRCS)) \
 $(patsubst %.S,$(OBJ_DIR)/%.o,$(KERNEL_S_SRCS)) \
 $(VECTORS_OBJ)

KERNEL_MEMFS_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(KERNEL_MEMFS_C_SRCS)) \
 $(patsubst %.S,$(OBJ_DIR)/%.o,$(KERNEL_S_SRCS)) \
 $(VECTORS_OBJ)

USER_LIB_OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(filter %.c,$(USER_LIB_SRCS))) \
 $(patsubst %.S,$(OBJ_DIR)/%.o,$(filter %.S,$(USER_LIB_SRCS)))
USER_APP_OBJS := $(addprefix $(OBJ_DIR)/user/,$(addsuffix .o,$(USER_PROGS)))
UPROGS := $(addprefix $(BIN_DIR)/_,$(USER_PROGS))

MKFS := $(BIN_DIR)/mkfs
FS_IMG := $(BIN_DIR)/fs.img
ENTRYOTHER := $(BIN_DIR)/entryother
INITCODE := $(BIN_DIR)/initcode
KERNEL := $(BIN_DIR)/kernel
KERNELMEMFS := $(BIN_DIR)/kernelmemfs
ISO_ROOT := $(BIN_DIR)/iso
ISO_BOOT := $(ISO_ROOT)/boot
ISO_GRUB := $(ISO_BOOT)/grub
GRUB_CFG := $(ISO_GRUB)/grub.cfg
XV6_ISO := $(BIN_DIR)/xv6.iso
GRUB_MKRESCUE ?= grub-mkrescue
INITCODE_BLOB_OBJ := $(OBJ_DIR)/blob/initcode.blob.o
ENTRYOTHER_BLOB_OBJ := $(OBJ_DIR)/blob/entryother.blob.o
FSIMG_BLOB_OBJ := $(OBJ_DIR)/blob/fsimg.blob.o

.PHONY: all clean deep qemu qemu-nox qemu-gdb qemu-nox-gdb qemu-deep qemu-nox-deep dirs

all: $(XV6_ISO)

deep:
>$(MAKE) DEEP_VERIFY=1 all

dirs:
>@mkdir -p $(OBJ_DIR) $(BIN_DIR) $(GEN_DIR) $(ASM_DIR) $(SYM_DIR)

$(OBJ_DIR)/%.o: %.c | dirs
>@mkdir -p $(dir $@)
>$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/%.o: %.S | dirs
>@mkdir -p $(dir $@)
>$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(VECTORS_GEN): arch/x86/kernel/vectors.pl | dirs
>./arch/x86/kernel/vectors.pl > $@

$(VECTORS_OBJ): $(VECTORS_GEN) | dirs
>@mkdir -p $(dir $@)
>$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(ENTRYOTHER): $(ENTRYOTHER_OBJ) | dirs
>$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(OBJ_DIR)/entryother.out $(ENTRYOTHER_OBJ)
>$(OBJCOPY) -S -O binary -j .text $(OBJ_DIR)/entryother.out $@
>$(OBJDUMP) -S $(OBJ_DIR)/entryother.out > $(ASM_DIR)/entryother.asm

$(INITCODE): $(INITCODE_OBJ) | dirs
>$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(OBJ_DIR)/initcode.out $(INITCODE_OBJ)
>$(OBJCOPY) -S -O binary $(OBJ_DIR)/initcode.out $@
>$(OBJDUMP) -S $(INITCODE_OBJ) > $(ASM_DIR)/initcode.asm

$(INITCODE_BLOB_OBJ): $(INITCODE) | dirs
>@mkdir -p $(dir $@)
>$(LD) -r -b binary $(INITCODE) -o $@
>$(OBJCOPY) --redefine-sym _binary_build_bin_initcode_start=_binary_initcode_start --redefine-sym _binary_build_bin_initcode_end=_binary_initcode_end --redefine-sym _binary_build_bin_initcode_size=_binary_initcode_size $@

$(ENTRYOTHER_BLOB_OBJ): $(ENTRYOTHER) | dirs
>@mkdir -p $(dir $@)
>$(LD) -r -b binary $(ENTRYOTHER) -o $@
>$(OBJCOPY) --redefine-sym _binary_build_bin_entryother_start=_binary_entryother_start --redefine-sym _binary_build_bin_entryother_end=_binary_entryother_end --redefine-sym _binary_build_bin_entryother_size=_binary_entryother_size $@

$(FSIMG_BLOB_OBJ): $(FS_IMG) | dirs
>@mkdir -p $(dir $@)
>$(LD) -r -b binary $(FS_IMG) -o $@
>$(OBJCOPY) --redefine-sym _binary_build_bin_fs_img_start=_binary_fs_img_start --redefine-sym _binary_build_bin_fs_img_end=_binary_fs_img_end --redefine-sym _binary_build_bin_fs_img_size=_binary_fs_img_size $@

$(KERNEL): $(ENTRY_OBJ) $(KERNEL_OBJS) $(ENTRYOTHER) $(INITCODE) $(ENTRYOTHER_BLOB_OBJ) $(INITCODE_BLOB_OBJ) linker/kernel.ld | dirs
>$(LD) $(LDFLAGS) -T linker/kernel.ld -o $@ $(ENTRY_OBJ) $(KERNEL_OBJS) $(INITCODE_BLOB_OBJ) $(ENTRYOTHER_BLOB_OBJ)
>$(OBJDUMP) -S $@ > $(ASM_DIR)/kernel.asm
>$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(SYM_DIR)/kernel.sym

$(KERNELMEMFS): $(ENTRY_OBJ) $(KERNEL_MEMFS_OBJS) $(ENTRYOTHER) $(INITCODE) $(FS_IMG) $(ENTRYOTHER_BLOB_OBJ) $(INITCODE_BLOB_OBJ) $(FSIMG_BLOB_OBJ) linker/kernel.ld | dirs
>$(LD) $(LDFLAGS) -T linker/kernel.ld -o $@ $(ENTRY_OBJ) $(KERNEL_MEMFS_OBJS) $(INITCODE_BLOB_OBJ) $(ENTRYOTHER_BLOB_OBJ) $(FSIMG_BLOB_OBJ)
>$(OBJDUMP) -S $@ > $(ASM_DIR)/kernelmemfs.asm
>$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(SYM_DIR)/kernelmemfs.sym

$(BIN_DIR)/_%: $(OBJ_DIR)/user/%.o $(USER_LIB_OBJS) | dirs
>$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
>$(OBJDUMP) -S $@ > $(ASM_DIR)/$*.asm
>$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(SYM_DIR)/$*.sym

$(BIN_DIR)/_forktest: $(OBJ_DIR)/user/forktest.o $(OBJ_DIR)/user/ulib.o $(OBJ_DIR)/user/usys.o | dirs
>$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
>$(OBJDUMP) -S $@ > $(ASM_DIR)/forktest.asm

$(MKFS): tools/mkfs.c include/fs/fs.h include/fs/stat.h include/core/param.h | dirs
>$(HOSTCC) -Werror -Wall -iquote include -o $@ tools/mkfs.c

$(FS_IMG): $(MKFS) README.md $(UPROGS) | dirs
>cp README.md $(BIN_DIR)/README
>cd $(BIN_DIR) && ./mkfs fs.img README $(notdir $(UPROGS))

$(XV6_ISO): $(KERNEL) $(FS_IMG) scripts/grub.cfg | dirs
>@mkdir -p $(ISO_GRUB)
>if ! command -v $(GRUB_MKRESCUE) >/dev/null 2>&1; then echo "*** Error: $(GRUB_MKRESCUE) not found"; echo "*** Install grub-mkrescue and xorriso to build ISO"; exit 1; fi
>cp $(KERNEL) $(ISO_BOOT)/kernel
>cp $(FS_IMG) $(ISO_BOOT)/fs.img
>cp scripts/grub.cfg $(GRUB_CFG)
>$(GRUB_MKRESCUE) -o $@ $(ISO_ROOT)

CPUS ?= 1
QEMUOPTS = -enable-kvm -cdrom $(XV6_ISO) -boot d -smp $(CPUS) -m 512
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; then echo "-gdb tcp::$(GDBPORT)"; else echo "-s -p $(GDBPORT)"; fi)

qemu: $(XV6_ISO)
>$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-nox: $(XV6_ISO)
>$(QEMU) -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
>sed "s/localhost:1234/localhost:$(GDBPORT)/" < $< > $@

qemu-gdb: $(XV6_ISO) .gdbinit
>@echo "*** Now run 'gdb'." 1>&2
>$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb: $(XV6_ISO) .gdbinit
>@echo "*** Now run 'gdb'." 1>&2
>$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)

qemu-deep:
>$(MAKE) DEEP_VERIFY=1 qemu

qemu-nox-deep:
>$(MAKE) DEEP_VERIFY=1 qemu-nox

clean:
>rm -rf $(OUT_DIR) .gdbinit

DEPFILES := \
 $(ENTRY_OBJ:.o=.d) \
 $(ENTRYOTHER_OBJ:.o=.d) \
 $(INITCODE_OBJ:.o=.d) \
 $(KERNEL_OBJS:.o=.d) \
 $(KERNEL_MEMFS_OBJS:.o=.d) \
 $(VECTORS_OBJ:.o=.d) \
 $(USER_LIB_OBJS:.o=.d) \
 $(USER_APP_OBJS:.o=.d)

-include $(DEPFILES)
