#ifndef _VMA_H_
#define _VMA_H_

#include "core/types.h"
#include "core/mman.h"

struct file;
struct proc;

struct vma {
  uintptr_t start;       // Start of VMA (inclusive)
  uintptr_t end;         // End of VMA (exclusive)
  int prot;              // PROT_READ | PROT_WRITE | PROT_EXEC
  int flags;             // MAP_ANONYMOUS | MAP_PRIVATE | MAP_SHARED
  struct file *file;     // Mapped file, if any
  size_t offset;         // Offset into file
  struct vma *next;      // Next VMA in the list
};

int vma_map(struct proc *p, uintptr_t addr, size_t length, int prot, int flags, struct file *f, size_t offset, uintptr_t *allocated_addr);
int vma_unmap(struct proc *p, uintptr_t addr, size_t length);
int is_valid_user_ptr(struct proc *p, uintptr_t addr, size_t length);

#endif // _VMA_H_
