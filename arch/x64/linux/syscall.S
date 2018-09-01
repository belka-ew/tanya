/*
The kernel uses the following registers:
%rdi, %rsi, %rdx, %r8, %r9, %r10

The number of the syscall is passed in %rax.

A syscall clobbers:
%rax, %rcx, %r11

The returned value is placed in %rax.
*/
	.text

// 1 parameter.
	.globl _D5tanya3sys5linux7syscallQiFNbNillZl
	.type _D5tanya3sys5linux7syscallQiFNbNillZl, @function

_D5tanya3sys5linux7syscallQiFNbNillZl:
	movq %rsi, %rax // Syscall number.

	syscall

	ret


// 2 parameters.
	.globl _D5tanya3sys5linux7syscallQiFNbNilllZl
	.type _D5tanya3sys5linux7syscallQiFNbNilllZl, @function

_D5tanya3sys5linux7syscallQiFNbNilllZl:
	movq %rdx, %rax

	syscall

	ret


// 3 parameters.
	.globl _D5tanya3sys5linux7syscallQiFNbNillllZl
	.type _D5tanya3sys5linux7syscallQiFNbNillllZl, @function

_D5tanya3sys5linux7syscallQiFNbNillllZl:
	movq %rcx, %rax

	syscall

	ret


// 6 parameters.
	.globl _D5tanya3sys5linux7syscallQiFNbNilllllllZl
	.type _D5tanya3sys5linux7syscallQiFNbNilllllllZl, @function

_D5tanya3sys5linux7syscallQiFNbNilllllllZl:
	pushq %rbp
	movq %rsp, %rbp

	movq 16(%rbp), %rax

	mov %rcx, %r10

	syscall

	leave
	ret
