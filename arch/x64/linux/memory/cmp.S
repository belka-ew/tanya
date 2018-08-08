	.text

/*
 * cmpMemory.
 *
 * rdi - r1 length
 * rsi - r1 data.
 * rdx - r2 length.
 * rcx - r2 data.
 */
	.globl _D5tanya6memory2op9cmpMemoryFNaNbNixAvxQdZi
	.type _D5tanya6memory2op9cmpMemoryFNaNbNixAvxQdZi, @function
_D5tanya6memory2op9cmpMemoryFNaNbNixAvxQdZi:
		// Compare the lengths
		cmp %rdx, %rdi
		jl  less
		jg  greater

		mov %rcx, %rdi

		// Check if we're aligned
		cmp $0x08, %rdx
		jc aligned_1
		test $0x07, %edi
		jz aligned_8

	naligned:
		cmpsb
		jl less
		jg greater

		dec %rdx
		test $0x07, %edi
		jnz naligned

	aligned_8:
		mov %rdx,  %rcx
		shr $0x03, %rcx

		repe cmpsq
		jl less
		jg greater

		and $0x07, %edx
		jz equal

	aligned_1: // Compare the remaining bytes
		mov %rdx, %rcx
		cmp $0x0, %rcx

		repe cmpsb
		jl less
		jg greater

	equal:
		xor %rax, %rax // Return 0
		jmp end

	greater:
		mov $0x01, %rax
		jmp end

	less:
		mov $-0x01, %rax

	end:
		ret
