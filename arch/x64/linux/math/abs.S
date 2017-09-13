	.text


// fabsf.
	.globl _D5tanya4math8nbtheory10__T3absTfZ3absFNaNbNiNffZf
	.type _D5tanya4math8nbtheory10__T3absTfZ3absFNaNbNiNffZf, @function

_D5tanya4math8nbtheory10__T3absTfZ3absFNaNbNiNffZf:
	mov $0x7fffffff, %eax
	movq %rax, %xmm1
	andpd %xmm1, %xmm0
	ret


// fabs.
	.globl _D5tanya4math8nbtheory10__T3absTdZ3absFNaNbNiNfdZd
	.type _D5tanya4math8nbtheory10__T3absTdZ3absFNaNbNiNfdZd, @function

_D5tanya4math8nbtheory10__T3absTdZ3absFNaNbNiNfdZd:
	mov $0x7fffffffffffffff, %rax
	movq %rax, %xmm1
	andpd %xmm1, %xmm0
	ret


// fabsl.
	.globl _D5tanya4math8nbtheory10__T3absTeZ3absFNaNbNiNfeZe
	.type _D5tanya4math8nbtheory10__T3absTeZ3absFNaNbNiNfeZe, @function

// Load the parameter from the stack onto FP stack, execute 'fabs' instruction
// The result is returned in ST0.
_D5tanya4math8nbtheory10__T3absTeZ3absFNaNbNiNfeZe:
	fldt 0x8(%rsp)
	fabs
	ret
