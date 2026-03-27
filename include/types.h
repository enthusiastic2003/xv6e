typedef unsigned int   uint;
typedef unsigned short ushort;
typedef unsigned char  uchar;
typedef uint pde_t;
// Defines an unsigned integer type that is wide enough to hold a pointer.
// On a 32-bit machine, a 'uint' is sufficient.
typedef uint uintptr_t;

// Defines the type for object sizes. 'uint' is the natural choice.
typedef uint size_t;

#ifndef NULL
#define NULL ((void*)0)
#endif