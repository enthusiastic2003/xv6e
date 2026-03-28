#define NPROC 64
#include "core/types.h"
#include "syscall.h"
#include "proc/uproc.h"
#include "user/user.h"

char *process_states[] = {
    "UNUSED","EMBRYO", "SLEEPING", "RUNNABLE", "RUNNING", "ZOMBIE" 
};

int main() {
    struct uproc processes[NPROC];
    int num_procs = getprocs(NPROC, processes);
    if (num_procs < 0) {
        printf(2, "Error: getprocs failed\n");
        exit();
    }
    
    printf(1, "PID\tPPID\tSTATE\tPRIORITY\tNAME\n");
    for (int i = 0; i < num_procs; i++) {
        char* proc_state = process_states[processes[i].state];
        printf(1, "%d\t%d\t%s\t%d\t%s\n", processes[i].pid, processes[i].ppid, proc_state, processes[i].priority, processes[i].name);
    }
    
    exit();
    }