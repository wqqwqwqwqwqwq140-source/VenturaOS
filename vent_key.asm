	.file	"VentKeyDriver.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	_VenturaKey
	.def	_VenturaKey;	.scl	2;	.type	32;	.endef
_VenturaKey:
	mov	eax, DWORD PTR [esp+4]
	xor	edx, edx
	cmp	al, 58
	ja	L1
	movzx	eax, al
	movzx	edx, BYTE PTR _ventura_layout[eax]
L1:
	mov	eax, edx
	ret
	.globl	_ventura_layout
	.section .rdata,"dr"
	.align 32
_ventura_layout:
	.ascii "\0\33"
	.ascii "1234567890-=\10\11qwertyuiop[]\12\0asdfghjkl;'`\0\\zxcvbnm,./\0*\0 \0"
	.ident	"GCC: (GNU) 13.2.0"
