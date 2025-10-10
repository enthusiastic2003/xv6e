#include "kheap.h"
#include "vm.h"
#include "defs.h"

struct kheap_metadata_page *metadata_pages = NULL; // Head of the linked list of metadata pages.
struct vmem_region *vmem_free_list_head = NULL; // Head of the free list of virtual memory regions.



static struct vmem_region*
get_new_vmem_region(void)
{
  // 1. Traverse the list of metadata pages to find one with space.
  struct kheap_metadata_page *current_page = metadata_pages;
  while (current_page) {
    if (current_page->num_regions < REGIONS_PER_PAGE) {
      // This page has an empty slot.
      struct vmem_region *region = &current_page->regions[current_page->num_regions];
      current_page->num_regions++;
      
      // Set the back-pointer to its containing page.
      region->metadata_page = current_page;
      return region;
    }
    current_page = current_page->next;
  }

  // 2. If all pages are full, we must allocate a new one.
  char *new_page_mem = kalloc();
  if (new_page_mem == 0)
    return 0; // Out of memory

  // 3. Initialize the new page's header.
  struct kheap_metadata_page *new_page = (struct kheap_metadata_page*)new_page_mem;
  new_page->num_regions = 0;
  
  // 4. Add it to the front of the list.
  new_page->next = metadata_pages;
  metadata_pages = new_page;

  // 5. Now, allocate the first region from this new page.
  struct vmem_region *region = &new_page->regions[0];
  new_page->num_regions++;
  region->metadata_page = new_page;
  
  return region;
}

/**
 * @brief Recycles a vmem_region struct.
 * If its containing metadata page becomes empty, the entire page is freed.
 */
static void
recycle_vmem_region(struct vmem_region *region)
{
  if (region == 0 || region->metadata_page == 0)
    return;

  struct kheap_metadata_page *page = region->metadata_page;
  page->num_regions--;

  // This simple version doesn't handle the "hole" created by freeing a region
  // from the middle of the array. It just decrements the count.
  // A more complex implementation would use a bitmap or free list *within* the page.
  
  // For now, we can add logic to free an entire page only when it's completely empty.
  if (page->num_regions == 0) {
    // This page is now empty. Remove it from the linked list and free it.
    
    // 1. Find the page in the list to remove it.
    struct kheap_metadata_page *prev = 0;
    struct kheap_metadata_page *current = metadata_pages;
    while(current != page && current != 0){
        prev = current;
        current = current->next;
    }
    
    if (current == 0) return; // Should not happen

    if(prev) prev->next = current->next;
    else metadata_pages = current->next;
    
    // 2. Free the page's memory.
    kfree((char*)page);
  }
}


/**
 * @brief Allocates a contiguous block of virtual memory pages in the kernel heap.
 * * @param num_pages The number of 4KB pages to allocate.
 * @return A pointer to the start of the allocated virtual memory, or 0 on failure.
 */
void*
kheap_alloc_pages(uint num_pages)
{
  if (num_pages == 0)
    return 0;

  // 1. Traverse the free list to find a suitable region.
  struct vmem_region *current = vmem_free_list_head;
  struct vmem_region *prev = 0;
  while (current) {
    if (current->num_pages >= num_pages) {
      // Found a suitable region.
      uintptr_t found_vaddr = current->base_vaddr;

      // Case A: The region is a perfect fit.
      if (current->num_pages == num_pages) {
        // Unlink it from the free list.
        if (prev)
          prev->next = current->next;
        else
          vmem_free_list_head = current->next;
        
        // Recycle the metadata struct for this region.
        recycle_vmem_region(current);

      // Case B: The region is larger than needed. Split it.
      } else {
        // Carve out the requested pages from the beginning of the region.
        current->base_vaddr += num_pages * PGSIZE;
        current->num_pages  -= num_pages;
      }
      
      // 2. Now, map physical pages to the secured virtual address range.
      for (uint i = 0; i < num_pages; i++) {
        char *p_page = kalloc();
        if (p_page == 0) {
          // Out of physical memory! This is a critical error.
          // We MUST undo our changes and free the virtual space we reserved.
          // (For simplicity in this example, we'll panic. A real kernel
          // would need to implement the undo logic.)
          panic("kheap_alloc_pages: out of physical memory");
        }
        // Map the physical page 'p_page' to the virtual address 'found_vaddr + i * PGSIZE'.
        // This requires a function like map_kernel_page(vaddr, paddr, flags).
        map_kernel_page((void*)(found_vaddr + i*PGSIZE), V2P(p_page), PTE_W | PTE_P);
    }

      // 3. Success. Return the starting virtual address.
      return (void*)found_vaddr;
    }
    // Move to the next region in the list.
    prev = current;
    current = current->next;
  }

  // 4. If the loop finishes, no suitable region was found.
  cprintf("kheap_alloc_pages: out of virtual memory\n");
  return 0;
}



/**
 * @brief Frees a contiguous block of virtual memory pages, returning them to the heap.
 * It handles coalescing with adjacent free blocks to prevent fragmentation.
 * @param vaddr The starting virtual address of the block to free. Must be page-aligned.
 * @param num_pages The number of 4KB pages in the block.
 */
void kheap_free_pages(void *vaddr, uint num_pages)
{
  if (vaddr == 0 || num_pages == 0)
    return;

  uintptr_t va_to_free = (uintptr_t)vaddr;

  // 1. Unmap and free underlying physical pages.
  for (uint i = 0; i < num_pages; i++) {
    kfree_and_unmap_page((void*)(va_to_free + i * PGSIZE));
  }

  // 2. Find the correct, address-sorted position in the free list.
  struct vmem_region *current = vmem_free_list_head;
  struct vmem_region *prev = 0;
  while (current && current->base_vaddr < va_to_free) {
    prev = current;
    current = current->next;
  }

  struct vmem_region *node_to_check_forward;

  // 3. Coalesce backwards: Check if we can merge with the PREVIOUS block.
  if (prev && (prev->base_vaddr + prev->num_pages * PGSIZE) == va_to_free) {
    // Yes. Extend the previous block to include the freed space.
    prev->num_pages += num_pages;
    node_to_check_forward = prev; // This is now the block to check against 'current'.
  } else {
    // No. We must insert a new node to represent the freed space.
    struct vmem_region *new_node = get_new_vmem_region();
    if (new_node == 0) panic("kheap_free_pages: out of metadata");
    
    new_node->base_vaddr = va_to_free;
    new_node->num_pages = num_pages;
    new_node->next = current;

    if (prev) prev->next = new_node;
    else vmem_free_list_head = new_node;
    
    node_to_check_forward = new_node;
  }

  // 4. Coalesce forwards: Check if our block can merge with the NEXT one.
  if (current && (node_to_check_forward->base_vaddr + node_to_check_forward->num_pages * PGSIZE) == current->base_vaddr) {
    // Yes. Absorb the next block into our current one.
    node_to_check_forward->num_pages += current->num_pages;
    node_to_check_forward->next = current->next;
    recycle_vmem_region(current);
  }
}

void
kheap_init(void)
{
  // 1. Get the very first vmem_region struct.
  // This will trigger the allocation of our first metadata page.
  struct vmem_region *initial_region = get_new_vmem_region();

  if (initial_region == 0) {
    panic("kheap_init: failed to allocate initial metadata page");
  }

  // 2. Configure this first region to describe the entire heap space.
  initial_region->base_vaddr = (uintptr_t)KHEAP_START;
  // Cast the void pointers to an integer type before performing subtraction.
    initial_region->num_pages = ((uintptr_t)KHEAP_END - (uintptr_t)KHEAP_START) / PGSIZE;
  initial_region->next = 0; // It's the only item in the list.

  // 3. Set the main free list head to point to our initial region.
  vmem_free_list_head = initial_region;

  // The kernel heap is now ready to be used.
}