
#ifndef KHEAP_H
#define KHEAP_H
#include "memlayout.h"
#include "types.h"
#include "mmu.h"

// Kernel heap layout
#define KHEAP_START (P2V(PHYSTOP))      // KHeap Virtual Address Start: Start right after mapped physical RAM
#define KHEAP_END   DEVSPACE              // KHeap Virtual Address End: End right before device memory
#define MAX_VMEM_REGIONS 1024 // Or another reasonable number

// Datastructures for heap regions
// A node in a linked list representing a
// contiguous block of free virtual memory pages.
struct vmem_region {
  uintptr_t base_vaddr;        // The starting virtual address of this free region.
  size_t    num_pages;         // The number of contiguous free pages in this region.
  struct vmem_region *next;    // Pointer to the next free region in the list.
  struct kheap_metadata_page *metadata_page; // Pointer to the metadata page containing this region.
};

// vmem_region denotes a region of free virtual memory pages. To manage these
// regions, we need space. We should use a dynamic memory allocation strategy.
// To do that, we are going to design a struct that denotes a page. 
struct kheap_metadata_page {
    struct kheap_metadata_page *next; // Pointer to the next metadata page.
    size_t num_regions;                // Number of regions stored in this metadata page.
    struct vmem_region regions[];      // Flexible array member to hold regions.
};

#define REGIONS_PER_PAGE ((PGSIZE - sizeof(struct kheap_metadata_page)) / sizeof(struct vmem_region))

void *liballoc_alloc(size_t num_pages);
int liballoc_free(void *vaddr, size_t num_pages);
void kheap_init(void);
int liballoc_lock();
int liballoc_unlock();
#endif // KHEAP_H