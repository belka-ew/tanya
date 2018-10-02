	.text

/*
 * equalMemory.
 *
 * rdi - r1 length
 * rsi - r1 data.
 * rdx - r2 length.
 * rcx - r2 data.
 */
	.globl _D5tanya6memory2op11equalMemoryFNaNbNixAvxQdZb
	.type _D5tanya6memory2op11equalMemoryFNaNbNixAvxQdZb, @function
_D5tanya6memory2op11equalMemoryFNaNbNixAvxQdZb:
		// Compare the lengths
		cmp %rdx, %rdi
		jne not_equal

		mov %rcx, %rdi

		// Check if we're aligned
		cmp $0x08, %rdx
		jc aligned_1
		test $0x07, %edi
		jz aligned_8

	naligned:
		cmpsb
		jne not_equal

		dec %rdx
		test $0x07, %edi
		jnz naligned

	aligned_8:
		mov %rdx,  %rcx
		shr $0x03, %rcx

		repe cmpsq
		jne not_equal

		and $0x07, %edx
		jz equal

	aligned_1: // Compare the remaining bytes
		mov %rdx, %rcx
		cmp $0x0, %rcx

		repe cmpsb
		jne not_equal

	equal:
		mov $0x01, %rax // Return 1
		jmp end

	not_equal:
		xor %rax, %rax // Return 0

	end:
		ret
