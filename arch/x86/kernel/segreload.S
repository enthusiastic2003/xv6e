#include "arch/x86/mmu.h"

.globl x86_segreload
x86_segreload:
  movw $(SEG_KDATA<<3), %ax
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %ss

  # Clear NT so iret never attempts a task return path.
  pushfl
  popl %eax
  andl $~0x00004000, %eax
  pushl %eax
  popfl

  # Reload CS from xv6's GDT code selector after lgdt in seginit().
  ljmp $(SEG_KCODE<<3), $1f
1:
  ret