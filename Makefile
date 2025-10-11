#--------------------------------------------
# xv6 Makefile (clean build with obj/ directory)
#--------------------------------------------

# Object directory
OBJDIR := obj
$(shell mkdir -p $(OBJDIR))

# VM Submodule Sources
VM_SRC = \
    vm/kalloc.c \
    vm/kheap.c \
    vm/liballoc.c \
    vm/vm.c

# Kernel object files
OTHER_KERNEL_OBJS = \
	bio.o \
	console.o \
	exec.o \
	file.o \
	fs.o \
	ide.o \
	ioapic.o \
	kbd.o \
	lapic.o \
	log.o \
	main.o \
	mp.o \
	picirq.o \
	pipe.o \
	proc.o \
	sleeplock.o \
	spinlock.o \
	string.o \
	swtch.o \
	syscall.o \
	sysfile.o \
	sysproc.o \
	trapasm.o \
	trap.o \
	uart.o \
	vectors.o \

# Generate object file paths from sources and combine for the linker
VM_OBJS = $(addprefix $(OBJDIR)/, $(notdir $(VM_SRC:.c=.o)))
OTHER_OBJS = $(addprefix $(OBJDIR)/, $(OTHER_KERNEL_OBJS))
OBJS = $(OTHER_OBJS) $(VM_OBJS)

# User library
ULIB = $(OBJDIR)/ulib.o $(OBJDIR)/usys.o $(OBJDIR)/printf.o $(OBJDIR)/umalloc.o

# Cross-compiling (e.g., on Mac OS X)
TOOLPREFIX = i686-elf-

# Using native tools (e.g., on X86 Linux)
# TOOLPREFIX = 

# ifndef TOOLPREFIX
# TOOLPREFIX := $(shell if i386-jos-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
# 	then echo 'i386-jos-elf-'; \
# 	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
# 	then echo ''; \
# 	else echo "***" 1>&2; \
# 	echo "*** Error: Couldn't find an i386-*-elf version of GCC/binutils." 1>&2; \
# 	echo "*** Is the directory with i386-jos-elf-gcc in your PATH?" 1>&2; \
# 	exit 1; fi)
# endif

# # QEMU detection
ifndef QEMU
QEMU = $(shell if which qemu > /dev/null; \
	then echo qemu; \
	elif which qemu-system-i386 > /dev/null; \
	then echo qemu-system-i386; \
	elif which qemu-system-x86_64 > /dev/null; \
	then echo qemu-system-x86_64; \
	else echo "*** Error: Could not find QEMU"; exit 1; fi)
endif

# Tools
CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)as
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

CFLAGS = -Wno-infinite-recursion -g -fno-pic -static -fno-builtin -Wno-array-bounds -fno-strict-aliasing -Os -Wall -MD -ggdb -m32 -Werror -fno-omit-frame-pointer
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
ASFLAGS = -m32 -gdwarf-2 -Wa,-divide
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)

# Disable PIE if possible
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

#--------------------------------------------
# Build targets
#--------------------------------------------

xv6.img: bootblock kernel
	dd if=/dev/zero of=xv6.img count=10000
	dd if=bootblock of=xv6.img conv=notrunc
	dd if=kernel of=xv6.img seek=1 conv=notrunc

xv6memfs.img: bootblock kernelmemfs
	dd if=/dev/zero of=xv6memfs.img count=10000
	dd if=bootblock of=xv6memfs.img conv=notrunc
	dd if=kernelmemfs of=xv6memfs.img seek=1 conv=notrunc

#--------------------------------------------
# Bootblock
#--------------------------------------------
bootblock: $(OBJDIR)/bootmain.o $(OBJDIR)/bootasm.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $(OBJDIR)/bootblock.o $(OBJDIR)/bootasm.o $(OBJDIR)/bootmain.o
	$(OBJDUMP) -S $(OBJDIR)/bootblock.o > bootblock.asm
	$(OBJCOPY) -S -O binary -j .text $(OBJDIR)/bootblock.o bootblock
	./sign.pl bootblock

$(OBJDIR)/bootmain.o: bootmain.c
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

$(OBJDIR)/bootasm.o: bootasm.S
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

#--------------------------------------------
# Entry / Initcode
#--------------------------------------------
$(OBJDIR)/entryother.o: entryother.S
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

entryother: $(OBJDIR)/entryother.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $(OBJDIR)/bootblockother.o $(OBJDIR)/entryother.o
	$(OBJCOPY) -S -O binary -j .text $(OBJDIR)/bootblockother.o entryother
	$(OBJDUMP) -S $(OBJDIR)/bootblockother.o > entryother.asm

$(OBJDIR)/initcode.o: initcode.S
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

initcode: $(OBJDIR)/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(OBJDIR)/initcode.out $(OBJDIR)/initcode.o
	$(OBJCOPY) -S -O binary $(OBJDIR)/initcode.out initcode
	$(OBJDUMP) -S $(OBJDIR)/initcode.o > initcode.asm

#--------------------------------------------
# Kernel
#--------------------------------------------
$(OBJS): | $(OBJDIR)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o: vm/%.c
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

$(OBJDIR)/%.o: %.c
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

$(OBJDIR)/%.o: %.S
	$(CC) $(CFLAGS) -nostdinc -I. -c $< -o $@

vectors.S: vectors.pl
	./vectors.pl > vectors.S

kernel: $(OBJS) $(OBJDIR)/entry.o entryother initcode kernel.ld
	$(LD) $(LDFLAGS) -T kernel.ld -o kernel $(OBJDIR)/entry.o $(OBJS) -b binary initcode entryother
	$(OBJDUMP) -S kernel > kernel.asm
	$(OBJDUMP) -t kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernel.sym

# Kernelmemfs
MEMFSOBJS = $(filter-out ide.o,$(KERNEL_OBJS))
MEMFSOBJS := $(addprefix $(OBJDIR)/,$(MEMFSOBJS))
kernelmemfs: $(MEMFSOBJS) $(OBJDIR)/entry.o entryother initcode fs.img
	$(LD) $(LDFLAGS) -T kernel.ld -o kernelmemfs $(OBJDIR)/entry.o $(MEMFSOBJS) -b binary initcode entryother fs.img
	$(OBJDUMP) -S kernelmemfs > kernelmemfs.asm
	$(OBJDUMP) -t kernelmemfs | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > kernelmemfs.sym

#--------------------------------------------
# User programs
#--------------------------------------------
UPROGS=\
	_cat\
	_echo\
	_forktest\
	_grep\
	_init\
	_kill\
	_ln\
	_ls\
	_mkdir\
	_rm\
	_sh\
	_stressfs\
	_usertests\
	_wc\
	_zombie\

$(OBJDIR)/%.o: %.c
	$(CC) $(CFLAGS) -I. -c $< -o $@

$(OBJDIR)/%.o: %.S
	$(CC) $(CFLAGS) -I. -c $< -o $@

_%: $(OBJDIR)/%.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

_forktest: $(OBJDIR)/forktest.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o _forktest $(OBJDIR)/forktest.o $(OBJDIR)/ulib.o $(OBJDIR)/usys.o
	$(OBJDUMP) -S _forktest > forktest.asm

#--------------------------------------------
# mkfs
#--------------------------------------------
mkfs: mkfs.c fs.h
	gcc -Werror -Wall -o mkfs mkfs.c

fs.img: mkfs README $(UPROGS)
	./mkfs fs.img README $(UPROGS)

#--------------------------------------------
# Clean
#--------------------------------------------
.PRECIOUS: %.o

clean:
	rm -rf $(OBJDIR) *.asm *.sym *.img kernel kernelmemfs bootblock entryother initcode initcode.out mkfs $(UPROGS) *.d *.gdbinit

#--------------------------------------------
# Emulators
#--------------------------------------------
# ifndef CPUS
# CPUS := 1
# endif
CPUS := 1
QEMUOPTS = -enable-kvm -drive file=fs.img,index=1,media=disk,format=raw -drive file=xv6.img,index=0,media=disk,format=raw -smp 1 -m 512

GDBPORT = $(shell expr `id -u` % 5000 + 25000)
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

qemu: fs.img xv6.img
	$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-memfs: xv6memfs.img
	$(QEMU) -drive file=xv6memfs.img,index=0,media=disk,format=raw -smp $(CPUS) -m 256

qemu-nox: fs.img xv6.img
	$(QEMU) -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/" < $^ > $@

qemu-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)

#--------------------------------------------
# Distribution
#--------------------------------------------
EXTRA=\
	mkfs.c ulib.c user.h cat.c echo.c forktest.c grep.c kill.c\
	ln.c ls.c mkdir.c rm.c stressfs.c usertests.c wc.c zombie.c\
	printf.c umalloc.c\
	README dot-bochsrc *.pl toc.* runoff runoff1 runoff.list\
	.gdbinit.tmpl gdbutil

FILES = $(shell grep -v '^\#' runoff.list)

dist:
	rm -rf dist
	mkdir dist
	for i in $(FILES); do \
		grep -v PAGEBREAK $$i > dist/$$i; \
	done
	sed '/CUT HERE/,$$d' Makefile > dist/Makefile
	echo > dist/runoff.spec
	cp $(EXTRA) dist

dist-test:
	rm -rf dist
	make dist
	rm -rf dist-test
	mkdir dist-test
	cp dist/* dist-test
	cd dist-test; $(MAKE) print
	cd dist-test; $(MAKE) bochs || true
	cd dist-test; $(MAKE) qemu
