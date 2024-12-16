.global switch_stack
# arguments:
# r0: argc
# r1: argv
# r2: envp
# r3: callee
# r4: new stack pointer
switch_stack:
	mov sp, x4
	blr x3

	# call exit
	# the return value of callee is the first argument of exit
	bl exit