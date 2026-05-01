#include "syscall.h"
#include "arch/x86/traps.h"

#define SYSCALL(name, nargs) \
  .globl name; \
  name: \
    pushl %ebp; \
    pushl %edi; \
    pushl %esi; \
    pushl %ebx; \
    .if nargs > 0; movl 20(%esp), %ebx; .endif; \
    .if nargs > 1; movl 24(%esp), %ecx; .endif; \
    .if nargs > 2; movl 28(%esp), %edx; .endif; \
    .if nargs > 3; movl 32(%esp), %esi; .endif; \
    .if nargs > 4; movl 36(%esp), %edi; .endif; \
    .if nargs > 5; movl 40(%esp), %ebp; .endif; \
    movl $SYS_ ## name, %eax; \
    int $T_SYSCALL; \
    popl %ebx; \
    popl %esi; \
    popl %edi; \
    popl %ebp; \
    ret

SYSCALL(fork, 0)
SYSCALL(exit, 1)
SYSCALL(wait, 0)
SYSCALL(pipe, 1)
SYSCALL(read, 3)
SYSCALL(write, 3)
SYSCALL(close, 1)
SYSCALL(kill, 1)
SYSCALL(exec, 2)
SYSCALL(open, 2)
SYSCALL(mknod, 3)
SYSCALL(unlink, 1)
SYSCALL(fstat, 2)
SYSCALL(link, 2)
SYSCALL(mkdir, 1)
SYSCALL(chdir, 1)
SYSCALL(dup, 1)
SYSCALL(getpid, 0)
SYSCALL(sbrk, 1)
SYSCALL(sleep, 1)
SYSCALL(uptime, 0)
SYSCALL(getprocs, 2)
SYSCALL(mmap, 6)
SYSCALL(munmap, 2)
