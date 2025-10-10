#include "types.h"
int map_kernel_page(void *vaddr, uint paddr, int perm);
void unmap_kernel_page(void *vaddr);
void kfree_and_unmap_page(void *vaddr);
void unmap_kernel_page(void *vaddr);