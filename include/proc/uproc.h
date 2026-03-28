#include "core/types.h"
struct uproc {
  uint pid;
  uint ppid;
  char name[16];
  int state;
  int priority;
};
