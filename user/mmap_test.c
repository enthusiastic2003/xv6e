#include "core/types.h"
#include "user/user.h"
#include "core/mman.h"

int main(void) {
  printf(1, "Starting mmap test...\n");

  // Attempt to allocate 1 page (4096 bytes)
  void *ptr = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
  
  if (ptr == MAP_FAILED || ptr == (void*)-1 || ptr == 0) {
    printf(1, "mmap failed!\n");
    exit();
  }

  printf(1, "mmap success! Allocated at address: 0x%x\n", (uint)ptr);

  // Write to the memory
  char *str = (char*)ptr;
  strcpy(str, "Hello from the new VMA memory island!");

  // Read from the memory
  printf(1, "Read from mapped memory: %s\n", str);

  // Attempt to unmap
  if (munmap(ptr, 4096) < 0) {
    printf(1, "munmap failed!\n");
    exit();
  }

  printf(1, "munmap success!\n");
  printf(1, "mmap test fully passed.\n");

  exit();
}
