	.text

/*
 * fillMemory.
 *
 * rdi - length.
 * rsi - pointer.
 * rdx - value filled with a byte.
 */
	.globl _D5tanya6memory2op10fillMemoryFNaNbNiAvmZv
	.type _D5tanya6memory2op10fillMemoryFNaNbNiAvmZv, @function

_D5tanya6memory2op10fillMemoryFNaNbNiAvmZv:
		// Check for zero length
		test    %rdi, %rdi
		jz end

		mov     %rdi, %rax
		mov     %rsi, %r8

		movq    %rdx,  %xmm0
		movlhps %xmm0, %xmm0

		// Check if the pointer is aligned to a 16-byte boundary
		and     $-0x10, %r8

		// Compute the number of misaligned bytes
		mov  %rsi, %r9
		sub  %r8,  %r9

		test %r9,  %r9
		jz aligned

		// Get the number of bytes to be written until we are aligned
		mov $0x10, %rcx
		sub %r9,   %rcx

		mov %rsi,  %r8

		// If the length is less than the number of misaligned bytes,
		// write one byte at a time and exit
		cmp %rax, %rcx
		jg aligned_1

	naligned:
		mov %dl, (%r8) // Write a byte

		// Advance the pointer. Decrease the total number of bytes
		// and the misaligned ones
		inc %r8
		dec %rcx
		dec %rax

		// Checks if we are aligned
		test %rcx, %rcx
		jnz naligned

	aligned:
		// Checks if we're done writing bytes
		test %rax, %rax
		jz end

		// Write 1 byte at a time
		cmp $8, %rax
		jl aligned_1

		// Write 8 bytes at a time
		cmp $16, %rax
		jl aligned_8

		// Write 16 bytes at a time
		cmp $32, %rax
		jl aligned_16

		// Write 32 bytes at a time
		cmp $64, %rax
		jl aligned_32

	aligned_64:
		movdqa %xmm0, (%r8)
		movdqa %xmm0, 16(%r8)
		movdqa %xmm0, 32(%r8)
		movdqa %xmm0, 48(%r8)

		add $64, %r8
		sub $64, %rax

		cmp $64, %rax
		jge aligned_64

		// Checks if we're done writing bytes
		test %rax, %rax
		jz end

		// Write 1 byte at a time
		cmp $8, %rax
		jl aligned_1

		// Write 8 bytes at a time
		cmp $16, %rax
		jl aligned_8

		// Write 16 bytes at a time
		cmp $32, %rax
		jl aligned_16

	aligned_32:
		movdqa %xmm0, (%r8)
		movdqa %xmm0, 16(%r8)

		add $32, %r8
		sub $32, %rax

		// Checks if we're done writing bytes
		test %rax, %rax
		jz end

		// Write 1 byte at a time
		cmp $8, %rax
		jl aligned_1

		// Write 8 bytes at a time
		cmp $16, %rax
		jl aligned_8

	aligned_16:
		movdqa %xmm0, (%r8)

		add $16, %r8
		sub $16, %rax

		// Checks if we're done writing bytes
		test %rax, %rax
		jz end

		// Write 1 byte at a time
		cmp $8, %rax
		jl aligned_1

	aligned_8:
		mov %rdx, (%r8)

		add $8, %r8
		sub $8, %rax

		// Checks if we're done writing bytes
		test %rax, %rax
		jz end

	aligned_1:
		mov %dl, (%r8)

		inc %r8
		dec %rax

		test %rax, %rax
		jnz aligned_1

	end:
		ret
