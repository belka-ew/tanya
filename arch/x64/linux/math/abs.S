	.text


// fabsf.
	.globl _D5tanya4math8nbtheory4fabsFNaNbNiNffZf
	.type _D5tanya4math8nbtheory4fabsFNaNbNiNffZf, @function

_D5tanya4math8nbtheory4fabsFNaNbNiNffZf:
	mov $0x7fffffff, %eax
	movq %rax, %xmm1
	andpd %xmm1, %xmm0
	ret


// fabs.
	.globl _D5tanya4math8nbtheory4fabsFNaNbNiNfdZd
	.type _D5tanya4math8nbtheory4fabsFNaNbNiNfdZd, @function

_D5tanya4math8nbtheory4fabsFNaNbNiNfdZd:
	mov $0x7fffffffffffffff, %rax
	movq %rax, %xmm1
	andpd %xmm1, %xmm0
	ret


// fabsl.
	.globl _D5tanya4math8nbtheory4fabsFNaNbNiNfeZe
	.type _D5tanya4math8nbtheory4fabsFNaNbNiNfeZe, @function

// Load the parameter from the stack onto FP stack, execute 'fabs' instruction
// The result is returned in ST0.
_D5tanya4math8nbtheory4fabsFNaNbNiNfeZe:
	fldt 0x8(%rsp)
	fabs
	ret
