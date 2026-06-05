; kernel_gui.asm - 64-bit GUI kernel
[bits 64]
[org 0x1000]

gui_start:
    ; RDI указывает на boot_info (magic, width, height, bpp, pitch, fb_addr)
    
    ; Рисуем красный экран через фреймбуфер
    mov rsi, [rdi + 12]          ; framebuffer address
    movzx ecx, word [rdi + 4]    ; width
    movzx edx, word [rdi + 6]    ; height
    imul ecx, edx                ; total pixels
    
    mov eax, 0x00FF0000          ; красный (R,G,B = 0,0,255? или наоборот? RGBA?)
    rep stosd                    ; заполняем
    
.hang:
    hlt
    jmp .hang
