package util

import "core:fmt"
import sdl "vendor:sdl2"
import img "vendor:sdl2/image"

what_is :: proc(x: any) {
	fmt.printf("%T\n", x)
}

rect_all :: proc(all: i32) -> sdl.Rect {
	return sdl.Rect{all, all, all, all}
}
