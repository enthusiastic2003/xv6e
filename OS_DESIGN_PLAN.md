# Operating System Modernization Plans: xv6e

This document outlines the architectural blueprints for implementing two major subsystem upgrades in the xv6e kernel: a Multi-Level Feedback Queue (MLFQ) scheduler and a POSIX-style Signal handling system.

---

## 1. Multi-Level Feedback Queue (MLFQ) Scheduler

### The Problem
Currently, xv6 uses a simple Round-Robin scheduler. Every process is treated equally, meaning an interactive shell (`sh`) or `ls` gets the exact same CPU time slice as a heavy background math computation. This leads to poor responsiveness for interactive tasks.

### The MLFQ Design
The goal is to favor interactive processes (short bursts) while preventing CPU-heavy processes from starving.

#### 1. Data Structure Updates (`include/proc/proc.h`)
*   Add `int priority;` to `struct proc`. We will use 3 priority levels (0, 1, 2) where 0 is the highest priority.
*   Add `int ticks_used;` to track how long a process has been running in its current time slice.

#### 2. Time Slicing via Hardware Timer (`kernel/core/trap.c`)
*   Currently, `trap()` forces a `yield()` on every timer tick (`T_IRQ0 + IRQ_TIMER`).
*   **New Logic:** Let Q0 processes get 1 tick, Q1 get 2 ticks, and Q2 get 4 ticks (or a similar scaling factor).
*   When the timer traps, increment the current process's `ticks_used`. ONLY call `yield()` if `ticks_used` exceeds the allowance for its current priority level.

#### 3. Priority Demotion
*   If a process is forced to `yield()` because it consumed its *entire* time slice, it is behaving like a CPU hog. Demote it by increasing its priority value by 1 (up to the maximum of 2).
*   If a process blocks voluntarily (e.g., calling `sleep()` to wait for disk I/O or keyboard input), it yields before using its full slice. It should retain its high priority, rewarding interactive I/O behavior.

#### 4. The Scheduler Algorithm (`kernel/proc/proc.c : scheduler()`)
*   Instead of picking the very next `RUNNABLE` process in `ptable`, the scheduler must scan the table to find the `RUNNABLE` process with the *highest priority* (lowest number).
*   *Optimization detail:* To avoid traversing the whole table repeatedly, processes could eventually be moved into explicit linked-list queues for each priority.

#### 5. Priority Boost (Starvation Prevention)
*   To prevent CPU hogs from permanently starving, we must implement a priority boost.
*   Check the global `ticks` counter. Every `N` ticks (e.g., 100), walk the entire process table and reset all processes to Priority 0 and reset their `ticks_used` to 0.

---

## 2. POSIX-Style Signals

### The Problem
xv6's `kill(pid)` syscall simply sets a `killed = 1` flag on the target process. When the kernel returns to user space, it checks this flag and calls `exit()` if set. User-space programs cannot intercept events, run cleanup code, or handle asynchronous notifications.

### The Signal Design
We need the ability for one process (or the kernel) to send an asynchronous event to another, interrupting its normal execution to run a specific User-Space C function (the handler), and then returning to the interrupted code perfectly.

#### 1. Signal Registration (`sys_sigaction`)
*   Add an array to `struct proc`: `void (*signal_handlers[32])(int)`.
*   Create a syscall (`sys_sigaction`) allowing user-space to register a memory address as the handler for a specific signal number (e.g., "On SIGINT (2), run the function at `0x4000`").
*   Add a `uint pending_signals;` bitmask to track unhandled signals.

#### 2. Signal Delivery (`sys_kill`)
*   Modify `kill` to take a signal number: `int kill(int pid, int signum)`.
*   Instead of setting `p->killed = 1`, set the corresponding bit in the target process's `pending_signals` bitmask.
*   If the target is `SLEEPING` (and the signal represents a fatal event or interruption), wake it up to deal with the signal.

#### 3. The Kernel-to-User Trampoline (`kernel/core/trap.c`)
This is the most complex part. Before `trap()` returns to user space, it must check `pending_signals`. If a signal is pending:
*   We cannot simply overwrite `tf->eip` with the handler's address, because we would lose the program's original execution state permanently.
*   **The Hack (Modifying the User Stack):**
    1.  Subtract `sizeof(struct trapframe)` from the user's stack pointer (`tf->esp`).
    2.  Use `copyout` to write the *current* Trapframe (the saved registers of where the program was interrupted) onto the user's stack.
    3.  Subtract 4 more bytes from `tf->esp` and push a "return address". This return address must point to a special "sigreturn trampoline" (a tiny assembly stub injected into every process's memory space, or mapped globally).
    4.  Update `tf->eip` to the signal handler's registered user-space address.
    5.  Clear the bit in `pending_signals`.

#### 4. The Sigreturn Syscall (`sys_sigreturn`)
*   When the user's signal handler finishes, it implicitly calls `ret`.
*   Because we pushed the trampoline address onto the stack, the CPU jumps to the trampoline.
*   The trampoline contains assembly to invoke a special `SYS_sigreturn` syscall.
*   **Inside the kernel (`sys_sigreturn`):** The kernel reads the saved Trapframe off the user's stack, copies it *back* into the process's real `p->tf`, and returns.
*   **Result:** The program resumes exactly where it was interrupted, completely unaware that a signal handler just executed!