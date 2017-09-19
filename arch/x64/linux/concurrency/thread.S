	.text

	.globl thrd_current
	.type thrd_current, @function

thrd_current:
	mov %fs:0, %rax
	ret
