; boot.asm - Единый файл загрузчика VenturaOS
; Сборка: nasm -f bin boot.asm -o boot.bin

; ========== КОНСТАНТЫ ==========
KERNEL_LBA      equ 5
KERNEL_SECTORS  equ 128
BOOT_INFO_ADDR  equ 0x500

; ========== STAGE 1: Boot Sector ==========
[bits 16]
[org 0x7C00]

stage1:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    ; Загружаем stage2 (секторы 1-4) по адресу 0x7E00
    mov si, dap_stage2
    mov ah, 0x42
    int 0x13
    jc disk_error

    jmp 0x0000:0x7E00

disk_error:
    mov si, msg_disk_error
    call print_string_16
    cli
    hlt

print_string_16:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string_16
.done:
    ret

dap_stage2:
    db 0x10
    db 0
    dw 4              ; 4 сектора для stage2
    dw 0x7E00
    dw 0x0000
    dq 1

msg_disk_error db "Disk error!", 0
boot_drive db 0

times 510 - ($ - $$) db 0
dw 0xAA55

; ========== STAGE 2 ==========
; Начинается сразу после boot sector (физический адрес 0x7E00)
; Используем absolute адресацию вместо org

[bits 16]
section stage2 vstart=0x7E00

stage2_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Устанавливаем VBE режим
    call vbe_set_mode

    ; Загружаем ядро
    call load_kernel

    ; Переходим в 64-битный режим
    jmp enter_long_mode

    cli
    hlt

; ---------- Загрузка ядра ----------
load_kernel:
    mov si, dap_kernel
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc .error
    ret
.error:
    mov si, msg_kernel_err
    call print_string_16
    cli
    hlt

dap_kernel:
    db 0x10
    db 0
    dw KERNEL_SECTORS
    dw 0x1000
    dw 0x0000
    dq KERNEL_LBA

msg_kernel_err db "Kernel load error!", 0

; ---------- VBE установка режима ----------
vbe_set_mode:
    push es
    push ds

    mov ax, 0x4F00
    mov di, 0x8000
    int 0x10
    cmp ax, 0x004F
    jne .no_vbe

    les si, [di + 0x0E]
    push es
    pop ds

    mov word [vbe_mode], 0xFFFF

.search_1920:
    mov cx, [si]
    cmp cx, 0xFFFF
    je .fallback_1024
    add si, 2

    push ds
    pop es
    mov di, 0x8200
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne .search_1920

    test byte [di], 0x90
    jz .search_1920

    cmp word [di + 0x12], 1920
    jne .search_1920
    cmp word [di + 0x14], 1200
    jne .search_1920
    cmp byte [di + 0x19], 32
    jne .search_1920

    mov [vbe_mode], cx
    jmp .found

.fallback_1024:
    les si, [0x8000 + 0x0E]
    push es
    pop ds
.fb1024_loop:
    mov cx, [si]
    cmp cx, 0xFFFF
    je .fallback_any
    add si, 2

    push ds
    pop es
    mov di, 0x8200
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne .fb1024_loop

    test byte [di], 0x90
    jz .fb1024_loop

    cmp word [di + 0x12], 1024
    jne .fb1024_loop
    cmp word [di + 0x14], 768
    jne .fb1024_loop
    cmp byte [di + 0x19], 32
    jne .fb1024_loop

    mov [vbe_mode], cx
    jmp .found

.fallback_any:
    les si, [0x8000 + 0x0E]
    push es
    pop ds
.any_loop:
    mov cx, [si]
    cmp cx, 0xFFFF
    je .no_vbe
    add si, 2

    push ds
    pop es
    mov di, 0x8200
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne .any_loop

    test byte [di], 0x90
    jz .any_loop
    cmp byte [di + 0x19], 32
    jne .any_loop

    mov [vbe_mode], cx
    jmp .found

.no_vbe:
    mov si, msg_vbe
    call print_string_16
    cli
    hlt

.found:
    mov ax, 0x4F02
    mov bx, [vbe_mode]
    or bx, 0x4000
    int 0x10

    ; Заполняем boot_info
    mov di, BOOT_INFO_ADDR
    mov dword [di], 0xB0071E55
    mov ax, [0x8200 + 0x12]
    mov [di + 4], ax
    mov ax, [0x8200 + 0x14]
    mov [di + 6], ax
    mov al, [0x8200 + 0x19]
    mov [di + 8], al
    mov ax, [0x8200 + 0x10]
    mov [di + 10], ax
    mov eax, [0x8200 + 0x28]
    mov [di + 12], eax
    mov dword [di + 16], 0

    pop ds
    pop es
    ret

vbe_mode dw 0
msg_vbe db "VBE not found!", 0

; ---------- Переход в Long Mode ----------
enter_long_mode:
    cli

    ; Включаем A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Загружаем GDT
    lgdt [gdtr]

    ; Переходим в защищенный режим
    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x08:protected_mode_32

[bits 32]
protected_mode_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Очистка страничных таблиц (16 КБ)
    mov edi, 0x100000
    mov ecx, 0x4000
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT
    mov dword [0x100000], 0x101003
    ; PDPT[0] -> PD
    mov dword [0x101000], 0x102003

    ; PD: 512 записей по 2MB (первые 1 ГБ)
    mov edi, 0x102000
    mov eax, 0x000083
    mov ecx, 512
.fill_pd:
    mov [edi], eax
    add edi, 8
    add eax, 0x200000
    loop .fill_pd

    ; Включаем PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Включаем Long Mode в EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Загружаем CR3
    mov eax, 0x100000
    mov cr3, eax

    ; Включаем пейджинг
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Прыгаем в 64-битный код
    jmp 0x18:long_mode_64

[bits 64]
long_mode_64:
    mov ax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Передаем указатель на boot_info в RDI
    mov rdi, BOOT_INFO_ADDR
    
    ; Прыгаем на ядро (0x1000)
    mov rax, 0x1000
    jmp rax

; ---------- GDT (должна быть выровнена) ----------
align 8
gdt:
    dq 0x0000000000000000  ; NULL дескриптор
    dq 0x00CF9A000000FFFF  ; 32-bit код (селектор 0x08)
    dq 0x00CF92000000FFFF  ; 32-bit данные (селектор 0x10)
    dq 0x00209A0000000000  ; 64-bit код (селектор 0x18)
    dq 0x0000920000000000  ; 64-bit данные (селектор 0x20)

gdtr:
    dw $ - gdt - 1
    dd gdt
