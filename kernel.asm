bits 32
org 0x1000

kernel_start:
    mov esi, print1
    mov edi, 0xb8000
    mov bl, 0x07
    call embe32
    mov esi, print2
    mov edi, 0xb80a0
    call embe32

    mov esi, input
    mov edi, 0xb8140

.main_loop:
    call .wait_for_key
    jmp .main_loop

.wait_for_key:
    in al, 0x64
    test al, 0x01
    jz .wait_for_key

    in al, 0x60
    cmp al, 0x80
    jae .skip

    cmp al, 0x1C
    je .enter_pressed

    movzx ebx, al
    mov al, [keymap + ebx]
    test al, al
    jz .skip

    mov [edi], al
    mov [esi], al
    inc esi
    mov byte [edi+1], 0x0F
    add edi, 2
    call update_cursor
    jmp .skip

.enter_pressed:
    mov byte [esi], 0

    mov eax, edi
    sub eax, 0xb8000
    xor edx, edx
    mov ecx, 160
    div ecx
    inc eax
    mul ecx
    add eax, 0xb8000
    mov edi, eax

    push edi

    ; === help ===
    mov esi, input
    mov edi, cmd_help
    mov ecx, 5
    repe cmpsb
    je .run_help

    ; === clear ===
    mov esi, input
    mov edi, cmd_clear
    mov ecx, 6
    repe cmpsb
    je .run_clear

    ; === conclusion ===
    mov esi, input
    mov edi, cmd_conclusion
    mov ecx, 10
    repe cmpsb
    je .run_conclusion

    pop edi
    jmp .unknown

.run_help:
    pop edi
    call embe32.help
    jmp .done_cmd

.run_clear:
    pop edi
    push edi
    mov edi, 0xb8000
    mov eax, 0x0F200F20
    mov ecx, 1000
    cld
    rep stosd
    pop edi
    mov edi, 0xb8000
    jmp .done_cmd

.run_conclusion:
    pop edi
    mov esi, input
    
    ; Пропускаем саму команду conclusion (Я ЗАЕБАЛСЯ ЭТО ПИСАТЬ ЧЕ МЕНЯ ДВИЖЕТ)
    add esi, 10
    
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .done_cmd           ; конец строки без текста
    cmp al, 0x22           ; открывающая кавычка
    je .print_quoted
    
    ; Если не кавычка, выводим как есть (без кавычек)
    mov [edi], al
    mov byte [edi+1], 0x0F
    add edi, 2
    jmp .skip_spaces

.print_quoted:
    lodsb
    cmp al, 0
    je .done_cmd           ; неожиданный конец (нет закрывающей кавычки)
    cmp al, 0x22           ; закрывающая кавычка
    je .done_cmd
    mov [edi], al
    mov byte [edi+1], 0x0F
    add edi, 2
    jmp .print_quoted


.unknown:
    call embe32_help
    db 3, "ERROR: unknown command", 10, 1, 0

.done_cmd:
    push edi
    mov edi, input
    mov ecx, 16
    xor eax, eax
    rep stosd
    pop edi
    mov esi, input
    call update_cursor
    ret

.skip:
    ret

update_cursor:
    push eax
    push edx
    push ebx
    mov eax, edi
    sub eax, 0xb8000
    shr eax, 1
    mov bx, ax
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al
    pop ebx
    pop edx
    pop eax
    ret

; хуй
embe32_help:
    pop esi
    call .print
    push esi
    ret
.print:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .newline
    cmp al, 3
    je .set_red
    cmp al, 2
    je .set_green
    cmp al, 1
    je .set_white
    mov [edi], al
    mov byte [edi+1], bl
    add edi, 2
    jmp .print
.set_red:
    mov bl, 0x0C
    jmp .print
.set_green:
    mov bl, 0x0A
    jmp .print
.set_white:
    mov bl, 0x0F
    jmp .print
.newline:
    mov eax, edi
    sub eax, 0xb8000
    xor edx, edx
    mov ecx, 160
    div ecx
    inc eax
    mul ecx
    add eax, 0xb8000
    mov edi, eax
    jmp .print
.done:
    ret

; манда
embe32:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .next
    cmp al, 3
    je .set_red
    cmp al, 2
    je .set_green
    cmp al, 1
    je .set_white
    mov [edi], al
    mov byte [edi+1], bl
    add edi, 2
    jmp embe32
.set_red:
    mov bl, 0x0C
    jmp embe32
.set_green:
    mov bl, 0x0A
    jmp embe32
.set_white:
    mov bl, 0x0F
    jmp embe32
.next:
    mov eax, edi
    sub eax, 0xb8000
    xor edx, edx
    mov ecx, 160
    div ecx
    inc eax
    mul ecx
    add eax, 0xb8000
    mov edi, eax
    call update_cursor
    jmp embe32
.help:
    call embe32_help
    db 1, "Commands:", 10
    db 2, "  help", 1, " - show this help", 10
    db 2, "  clear", 1, " - clear screen", 10
    db 2, "  conclusion", 1, ' "text" - print text', 10
    db 0
    ret
.done:
    ret

; сисечка
print1 db 1, "Welcome to 32-bit VenturaOS!", 10, 0
print2 db 1, "c", 2, "o", 3, "l", 1, "o", 2, "r", 3, "s", 1, 10, 0

input times 64 db 0

keymap:
    db 0, 0, '1','2','3','4','5','6','7','8','9','0','-','=', 0, 0
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 0, 0, 'a'
    db 's','d','f','g','h','j','k','l',';', 0x27, '`', 0, '\', 'z'
    db 'x','c','v','b','n','m', ',', '.', '/', 0, '*', 0, ' ', 0
    times 128 - ($ - keymap) db 0

cmd_help db "help", 0
cmd_clear db "clear", 0
cmd_conclusion db "conclusion", 0

times 1024-($-$$) db 0