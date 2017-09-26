	.text

/*
 * copyMemory.
 *
 * rdi - source length
 * rsi - source data.
 * rdx - target length.
 * rcx - target data.
 */
	.globl _D5tanya6memory2op10copyMemoryFNaNbNixAvAvZv
	.type _D5tanya6memory2op10copyMemoryFNaNbNixAvAvZv, @function

_D5tanya6memory2op10copyMemoryFNaNbNixAvAvZv:
		mov %rdi, %rdx
		mov %rcx, %rdi

		cmp  $0x08, %rdx
		jc aligned_1
		test $0x07, %edi
		jz aligned_8

	naligned:
		movsb
		dec  %rdx
		test $0x07, %edi
		jnz naligned

	aligned_8:
		mov %rdx,  %rcx
		shr $0x03, %rcx
		rep movsq
		and $0x07, %edx
		jz end

	aligned_1:
		// Write the remaining bytes
		mov %rdx, %rcx
		rep movsb

	end:
		ret

/*
 * moveMemory.
 *
 * rdi - source length
 * rsi - source data.
 * rdx - target length.
 * rcx - target data.
 */
	.globl _D5tanya6memory2op10moveMemoryFNaNbNixAvAvZv
	.type _D5tanya6memory2op10moveMemoryFNaNbNixAvAvZv, @function

_D5tanya6memory2op10moveMemoryFNaNbNixAvAvZv:
		mov %rdi, %rdx

		lea -1(%rdx, %rsi), %rsi
		lea -1(%rdx, %rcx), %rdi
		mov %rdx, %rcx

		std // Set the direction flag

		rep movsb

		cld // Clear the direction flag
		ret
