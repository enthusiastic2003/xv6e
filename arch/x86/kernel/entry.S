# The xv6 kernel starts executing in this file. This file is linked with
# the kernel C code, so it can refer to kernel symbols such as main().
# The boot block (bootasm.S and bootmain.c) jumps to entry below.
        
# Multiboot2 header, for multiboot2-compliant boot loaders like GNU GRUB 2.
# https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html
#
# Using GRUB 2, you can boot xv6 from a file stored in a
# Linux file system by copying kernel or kernelmemfs to /boot
# and then adding this menu entry:
#
# menuentry "xv6" {
# 	insmod ext2
# 	set root='(hd0,msdos1)'
# 	set kernel='/boot/kernel'
# 	echo "Loading ${kernel}..."
# 	multiboot2 ${kernel}
# 	boot
# }

#include "arch/x86/asm.h"
#include "core/memlayout.h"
#include "arch/x86/mmu.h"
#include "core/param.h"

# Multiboot2 header. Data to direct multiboot2 loader.
# Must be 8-byte aligned and in the first 32KiB of the kernel image.
.p2align 3
.text
.globl multiboot_header
multiboot_header:
  #define mb2_header_magic 0xe85250d6
  #define mb2_arch_i386 0
  #define mb2_header_length 24
  .long mb2_header_magic
  .long mb2_arch_i386
  .long mb2_header_length
  .long -(mb2_header_magic + mb2_arch_i386 + mb2_header_length)
  .short 0
  .short 0
  .long 8

# By convention, the _start symbol specifies the ELF entry point.
# Keep _start inside the ELF loadable segment virtual range so
# multiboot2 loaders accept it as a valid segment entry.
.globl _start
_start = entry

# Entering xv6 on boot processor, with paging off.
.globl entry
entry:
  # GRUB multiboot2 handoff:
  #  eax = multiboot2 magic, ebx = physical pointer to multiboot2 info.
  movl    %eax, (V2P_WO(mb2_boot_magic))
  movl    %ebx, (V2P_WO(mb2_info_ptr_pa))

  # Turn on page size extension for 4Mbyte pages
  movl    %cr4, %eax
  orl     $(CR4_PSE), %eax
  movl    %eax, %cr4
  # Set page directory
  movl    $(V2P_WO(entrypgdir)), %eax
  movl    %eax, %cr3
  # Turn on paging.
  movl    %cr0, %eax
  orl     $(CR0_PG|CR0_WP), %eax
  movl    %eax, %cr0

  # Set up the stack pointer.
  movl $(stack + KSTACKSIZE), %esp

  # Jump to main(), and switch to executing at
  # high addresses. The indirect call is needed because
  # the assembler produces a PC-relative instruction
  # for a direct jump.
  mov $main, %eax
  jmp *%eax

.data
.globl mb2_boot_magic
mb2_boot_magic:
  .long 0

.globl mb2_info_ptr_pa
mb2_info_ptr_pa:
  .long 0

.comm stack, KSTACKSIZE
