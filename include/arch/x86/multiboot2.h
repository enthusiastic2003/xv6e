#ifndef XV6E_ARCH_X86_MULTIBOOT2_H
#define XV6E_ARCH_X86_MULTIBOOT2_H

#include "core/types.h"

#define MB2_BOOTLOADER_MAGIC 0x36d76289
#define MB2_TAG_ALIGN 8

#define MB2_TAG_END 0
#define MB2_TAG_BOOT_LOADER_NAME 2
#define MB2_TAG_MMAP 6
#define MB2_TAG_MODULE 3

#define MB2_BOOTLOADER_NAME_MAX 64

struct mb2_info {
  uint total_size;
  uint reserved;
};

struct mb2_tag {
  uint type;
  uint size;
};

struct mb2_tag_string {
  uint type;
  uint size;
  char string[0];
};

struct mb2_tag_module {
  uint type;
  uint size;
  uint mod_start;
  uint mod_end;
  char string[0];
};

struct mb2_tag_mmap {
  uint type;
  uint size;
  uint entry_size;
  uint entry_version;
  uchar entries[0];
};

#endif
