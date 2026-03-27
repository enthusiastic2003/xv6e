// kernel/vm/vm.h
// Public interface for the Memory Management Subsystem.

#ifndef _VM_H_
#define _VM_H_

#include "types.h"

// Forward-declare structs that are used in function signatures
// but whose definitions are private to the module.
struct proc;
struct inode;

// ====================================================================
// === Physical Page Allocator (from kalloc.c)
// ====================================================================

void            kinit1(void*, void*); // Called before scheduler is set up
void            kinit2(void*, void*); // Called after scheduler is set up
char*           kalloc(void);         // Allocate one 4096-byte page
void            kfree(char*);    // Free a 4096-byte page


// ====================================================================
// === Kernel Heap Allocator (from kheap.c)
// ====================================================================
void            kheap_init(void);
void    *kheap_malloc(size_t);				///< The standard function.
void    *kheap_realloc(void *, size_t);		///< The standard function.
void    *kheap_calloc(size_t, size_t);		///< The standard function.
void     kheap_free(void *);					///< The standard function.


// ====================================================================
// === Virtual Memory & Page Tables (from vm.c)
// ====================================================================

// --- Kernel Virtual Memory ---
void            seginit(void);
void            kvmalloc(void);
pde_t* setupkvm(void);
void            switchkvm(void);
int             map_kernel_page(void *vaddr, uint paddr, int perm);
void            unmap_kernel_page(void *vaddr);
void            kfree_and_unmap_page(void *vaddr);
char* uva2ka(pde_t*, char*);

// --- User Virtual Memory ---
void            inituvm(pde_t*, char*, uint);
int             allocuvm(pde_t*, uint, uint);
int             deallocuvm(pde_t*, uint, uint);
void            freevm(pde_t*);
int             loaduvm(pde_t*, char*, struct inode*, uint, uint);
pde_t* copyuvm(pde_t*, uint);
void            switchuvm(struct proc*);
int             copyout(pde_t*, uint, void*, uint);
void            clearpteu(pde_t *pgdir, char *uva);

#endif // _VM_H_