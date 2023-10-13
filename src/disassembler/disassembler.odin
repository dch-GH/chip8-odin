package disassembler

import "core:fmt"
import "core:io"
import "core:os"

Disassembler_Error :: enum u16 {
	None = 0,
	No_File_Found,
	Cannot_Read_File,
	Malformed_Data,
}

disassemble :: proc(path: string) -> Disassembler_Error {
	using Disassembler_Error
	err := None

	if !os.is_file(path) {
		err = No_File_Found
	}

	data, ok := os.read_entire_file(path)
	if !ok {
		err = Cannot_Read_File
		return err
	}

	instruction: u16
	length := len(data)
	for index := 0; index < length; index += 1 {
		instruction = cast(u16)data[index]
		instruction <<= 8
		second_index := index >= length ? length : index + 1
		instruction |= cast(u16)data[second_index]
		index += 1

		fmt.printf("%x\n", instruction)
	}

	#partial switch err {
	case No_File_Found:
		fmt.eprintf("No file found to disassemble! @ %s\n", path)
	}

	return err
}
