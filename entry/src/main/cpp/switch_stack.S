.global switch_stack
# arguments:
# r0: argc
# r1: argv
# r2: envp
# r3: callee
# r4: new stack pointer
switch_stack:
        mov     sp, x4
        blr     x3

        # flush all buffers via fflush(0)
        # w19: callee saved
        mov     w19, w0
        mov     x0, 0
        bl      fflush
        
        # call exit
        # the return value of callee is the first argument of exit
        mov     w0, w19
        bl      exit