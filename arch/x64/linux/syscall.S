/*
The kernel uses the following registers:
%rdi, %rsi, %rdx, %r8, %r9, %r10

The number of the syscall is passed in %rax.

A syscall clobbers:
%rax, %rcx, %r11

The returned value is placed in %rax.
*/
	.text

	.globl syscall1
	.type syscall1, @function

syscall1:
	movq %rsi, %rax // Syscall number.

	syscall

	ret


	.globl syscall2
	.type syscall2, @function

syscall2:
	// Store registers.
	movq %rdi, %r8

	movq %rdx, %rax // Syscall number.

	// Syscall arguments.
	movq %rsi, %rdi
	movq %r8, %rsi

	syscall

	// Restore registers.
	movq %rdi, %rsi
	movq %r8, %rdi

	ret


	.globl syscall3
	.type syscall3, @function

syscall3:
	// Store registers.
	movq %rdi, %r8

	movq %rcx, %rax // Syscall number.

	// Syscall arguments.
	movq %rdx, %rdi
	movq %r8, %rdx

	syscall

	// Restore registers.
	movq %r8, %rdi

	ret
