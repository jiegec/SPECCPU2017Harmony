.global switch_stack
# arguments:
# r0: argc
# r1: argv
# r2: envp
# r3: callee
# r4: new stack pointer
# r5: dlopen handle
switch_stack:
        # x20: callee saved
        mov     x20, x5
        mov     sp, x4
        blr     x3

        # call dlclose(handle)
        # w19: callee saved, save return value
        mov     w19, w0
        mov     x0, x20
        bl      dlclose

        # flush all buffers via fflush(0)
        mov     x0, 0
        bl      fflush
        
        # call exit
        # the return value of callee is the first argument of exit
        mov     w0, w19
        bl      exit
