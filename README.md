# VenturaOS

A minimal 32-bit operating system written from scratch in assembly.

## Features

- 32-bit Protected Mode
- Direct VGA video memory access (0xB8000)
- Color text output (white, green, red)
- Hardware text cursor
- PS/2 keyboard driver with scancode-to-ASCII mapping
- Command line interface with input buffer
- Built-in commands:
  - `help` — show available commands
  - `clear` — clear the screen
  - `conclusion "text"` — print text in quotes

## Building

Requirements: NASM.
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

## Running

Requirements: QEMU.
qemu-system-i386 -drive format=raw,file=os.img
## Project Structure

| File | Description |
|------|-------------|
| `boot.asm` | Bootloader (512 bytes): A20 gate, GDT, 32-bit switch, loads kernel |
| `kernel.asm` | Kernel: VGA driver, keyboard driver, command parser |
| `build.py` | Build script: compiles and links boot + kernel into os.img |

## How It Works

1. BIOS loads `boot.asm` from sector 1
2. Bootloader switches CPU to 32-bit Protected Mode
3. Kernel is loaded from disk to memory
4. Kernel initializes VGA and keyboard
5. Command prompt waits for user input

## License

MIT License — see LICENSE file.
