package main

import "core:fmt"
import "core:mem"
import "core:os"

LOG_PATH :: "log.txt"
MASK_X :: 0xF
MASK_Y :: 0xFF
MEM_LENGTH :: 4096

Debug_Flag :: enum u8 {
	None = 0,
	Log_RAM, // Log the contents of memory starting at 0x200, ending at 0x600.
	Log_ROM, // Log the contents of selected ROM on load.
}

Debug_Set :: bit_set[Debug_Flag]

Interpreter :: struct {
	memory:      [4096]byte, // "heap" memory
	V:           [16]u8, // the Vx registers 0-16 (0-F hex) V16/VF register should not be used by programs, used as a flag by instructions.
	I:           u16, // generally used to store memory addresses. lowest 12 bits are usually only needed.
	PC:          u16, // program counter, store currently executing address.
	SP:          u8, // stack pointer. used to point to the topmost level of the stack.
	stack:       [16]u16, // the stack. used to store the address that the interpreter shoud return to when finished with a subroutine. allows up to 16 levels of nested subroutines.
	DT:          u8, // active whenever the delay timer register (DT) is non-zero. This timer does nothing more than subtract 1 from the value of DT at a rate of 60Hz. When DT reaches 0, it deactivates.
	ST:          u8, // sound timer register. decrements at a rate of 60Hz, however, as long as ST's value is greater than zero, the Chip-8 buzzer will sound. When ST reaches zero, the sound timer deactivates.
	log_file:    os.Handle,
	debug_flags: Debug_Set,
}

load_rom :: proc(chip: ^Interpreter, path: string) -> bool {
	using chip
	if !os.is_file(path) {return false}

	data, ok := os.read_entire_file(path)
	if !ok {return false}

	if Debug_Flag.Log_ROM in debug_flags {
		log(chip, "-----------")
		log(chip, "----ROM----")
		log(chip, "-----------")

		for b, i in data {
			logf(chip, "[0x%X (%i)]: 0x%X == %d === %#b\n", i, i, b, b, b)
		}
	}

	{
		// Load program into memory.
		offset := mem.ptr_offset(&memory[0], 512)
		mem.copy(offset, &data[0], len(data))

		if Debug_Flag.Log_RAM in debug_flags {
			log(chip, "--------------")
			log(chip, "----MEMORY----")
			log(chip, "--------------")

			for x, address in memory {
				if address < 512 || address > 1500 {continue}
				log_address(chip, address)
			}
		}
	}

	return true
}

interpreter_initialize :: proc(chip: ^Interpreter) -> bool {
	using chip
	PC = 512

	handle, err := os.open(LOG_PATH, os.O_CREATE | os.O_WRONLY)
	if err > 0 {
		fmt.eprintf("Couldn't create log file")
		return false
	}

	// Clear the log file first.
	os.write_entire_file(LOG_PATH, nil)

	log_file = handle
	return true
}

interpreter_tick :: proc(chip: ^Interpreter, ticks: u32) -> Instruction {
	using chip

	// Try to parse an instruction from memory.
	{
		instruction := Instruction.Invalid

		next_byte_index := cast(int)PC >= MEM_LENGTH ? MEM_LENGTH : cast(int)(PC + 1)
		two_bytes: u16 = cast(u16)memory[PC] << 8
		kk := cast(u16)memory[next_byte_index]
		two_bytes |= kk

		highest_nibble := cast(u8)(two_bytes >> 12)
		x := (two_bytes >> 8) & MASK_X
		y := kk & MASK_Y
		nnn := two_bytes << 12

		if two_bytes == cast(u16)Instruction.CLS {
			return Instruction.CLS
		}

		// // if two_bytes & Instruction.JP_nnn {
		// 	log(chip, "Jump")
		// }

		// for ins in Instruction {
		// 	casted_ins := cast(u16)(ins)
		// 	if two_bytes == casted_ins {
		// 		// logf(chip, "Instruction: %s : 0x%X\n", ins, two_bytes)
		// 	}
		// }
		PC += 2
	}

	if PC >= MEM_LENGTH {
		PC = 512
	}

	return Instruction.Invalid
}

interpreter_destroy :: proc(chip: ^Interpreter) {
	using chip
	free(&chip.log_file)
	free(chip)
}

@(private = "file")
logf :: proc(chip: ^Interpreter, format: string, a: ..any) {
	using chip
	fmt.fprintf(log_file, format, ..a)
}

@(private = "file")
log :: proc(chip: ^Interpreter, a: ..any) {
	using chip
	fmt.fprintln(log_file, ..a)
}

@(private = "file")
log_address :: proc(chip: ^Interpreter, address: int) {
	using chip
	value_at_address := memory[address]
	fmt.fprintf(
		chip.log_file,
		"[0x%X (%i)]: 0x%X == %d === %#b\n",
		address,
		address,
		value_at_address,
		value_at_address,
		value_at_address,
	)
}


//b 0000 0000 0000 0000
//  	 x    y    n
//			 [   kk   ]
//		 [    nnn     ]

// nnn/addr = 12bit: lowest 12 bits
// n/nibble = 4bit: lowest 4 bits of the instruction
// x = 4bit: lower bits of higher byte of the instruction
// y = 4bit: upper bits of lower byte of the instruction
// kk/byte = 8bit: lowest 8 bits of the instruction

// Vx == register number of the x nibble of the instruction
// Vy == register number of the y nibble of the instruction

// All instructions are 2 bytes long and are stored most-significant-byte first. 
// In memory, the first byte of each instruction should be located at an even addresses. 
// If a program includes sprite data, it should be padded so any instructions following it will be properly situated in RAM.

Instruction :: enum u16 {
	Invalid                   = 0x0000,
	CLS                       = 0x00E0, // CLS.  Clear the display.
	RET                       = 0x00EE, // RET.  Return from a subroutine. The interpreter sets the program counter to the address at the top of the stack, then subtracts 1 from the stack pointer.
	JP_nnn                    = 0x1000, // 1nnn. Jump to location nnn. The interpreter sets the program counter to nnn.
	CALL_nnn                  = 0x2000, // 2nnn. Call subroutine at nnn. The interpreter increments the stack pointer, then puts the current PC on the top of the stack. The PC is then set to nnn.
	SE_Vx_kk                  = 0x3000, // 3xkk. Skip next instruction if Vx = kk. The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
	SNE_Vx_kk                 = 0x4000, // 4xkk. Skip next instruction if Vx != kk. The interpreter compares register Vx to kk, and if they are not equal, increments the program counter by 2.
	SE_Vx_Vy                  = 0x5000, // 5xy0. Skip next instruction if Vx = Vy. The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
	LD_Vx_kk                  = 0x6000, // 6xkk. The interpreter puts the value kk into register Vx.
	ADD_Vx_kk                 = 0x7000, // 7xkk. Adds the value kk to the value of register Vx, then stores the result in Vx.
	LD_Vx_Vy                  = 0x8000, // 8xy0. Stores the value of register Vy in register Vx.,
	OR_Vx_Vy                  = 0x8001, // 8xy1. Set Vx = Vx OR Vy. Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx. A bitwise OR compares the corrseponding bits from two values, and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
	AND_Vx_Vy                 = 0x8002, // 8xy2. Set Vx = Vx AND Vy. Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx. A bitwise AND compares the corrseponding bits from two values, and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
	XOR_Vx_Vy                 = 0x8003, // 8xy3. Set Vx = Vx XOR Vy. Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx. An exclusive OR compares the corrseponding bits from two values, and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
	ADD_Vx_Vy                 = 0x8004, // 8xy4. Set Vx = Vx + Vy, set VF = carry. The values of Vx and Vy are added together. If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0. Only the lowest 8 bits of the result are kept, and stored in Vx.
	SUB_Vx_Vy                 = 0x8005, // 8xy5. Set Vx = Vx - Vy, set VF = NOT borrow. If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
	SHR_Vx                    = 0x8006, // 8xy6. Set Vx = Vx SHR 1. If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
	SUBN_Vx_Vy                = 0x8007, // 8xy7. Set Vx = Vy - Vx, set VF = NOT borrow. If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
	SHL_Vx                    = 0x800E, // 8xyE. Set Vx = Vx SHL 1. If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
	SNE_Vx_Vy                 = 0x9000, // 9xy0. Skip next instruction if Vx != Vy. The values of Vx and Vy are compared, and if they are not equal, the program counter is increased by 2.
	LD_I_nnn                  = 0xA000, // Annn. Set I = nnn. The value of register I is set to nnn.
	JP_V0_nnn                 = 0xB000, // Bnnn. Jump to location nnn + V0. The program counter is set to nnn plus the value of V0.
	RND_Vx_kk                 = 0xC000, // Cxkk. Set Vx = random byte AND kk. The interpreter generates a random number from 0 to 255, which is then ANDed with the value kk. The results are stored in Vx. See instruction 8xy2 for more information on AND.
	DRW_Vx_Vy_nibble          = 0xD000, // Dxyn. Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision. The interpreter reads n bytes from memory, starting at the address stored in I. These bytes are then displayed as sprites on screen at coordinates (Vx, Vy). Sprites are XORed onto the existing screen. If this causes any pixels to be erased, VF is set to 1, otherwise it is set to 0. If the sprite is positioned so part of it is outside the coordinates of the display, it wraps around to the opposite side of the screen. See instruction 8xy3 for more information on XOR, and section 2.4, Display, for more information on the Chip-8 screen and sprites.
	SKP_Vx                    = 0xE09E, // Ex9E. Skip next instruction if key with the value of Vx is pressed. Checks the keyboard, and if the key corresponding to the value of Vx is currently in the down position, PC is increased by 2.
	SKNP_Vx                   = 0xE0A1, // ExA1. Skip next instruction if key with the value of Vx is not pressed. Checks the keyboard, and if the key corresponding to the value of Vx is currently in the up position, PC is increased by 2.
	LD_Vx_DT                  = 0xF007, // Fx07. Set Vx = delay timer value. The value of DT is placed into Vx.
	LD_Vx_K                   = 0xF00A, // Fx0A. Wait for a key press, store the value of the key in Vx. All execution stops until a key is pressed, then the value of that key is stored in Vx.
	LD_DT_VX                  = 0xF015, // Fx15. Set delay timer = Vx. DT is set equal to the value of Vx.
	LD_ST_Vx                  = 0xF018, // Fx18. Set sound timer = Vx. ST is set equal to the value of Vx.
	ADD_I_Vx                  = 0xF01E, // Fx1E. Set I = I + Vx. The values of I and Vx are added, and the results are stored in I.
	LD_F_Vx                   = 0xF029, // Fx29. Set I = location of sprite for digit Vx. The value of I is set to the location for the hexadecimal sprite corresponding to the value of Vx.
	LD_B_Vx                   = 0xF033, // Fx33. Store BCD representation of Vx in memory locations I, I+1, and I+2. The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
	STORE_V0_TO_Vx_AT_I       = 0xF055, // Fx55. Store registers V0 through Vx in memory starting at location I. The interpreter copies the values of registers V0 through Vx into memory, starting at the address in I.
	READ_FROM_I_INTO_V0_TO_Vx = 0xF065, // Fx65. Read registers V0 through Vx from memory starting at location I. The interpreter reads values from memory starting at location I into registers V0 through Vx.
}
