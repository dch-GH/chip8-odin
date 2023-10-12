package main

import "core:fmt"
import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import alg "core:math/linalg"

import "util"
import dis "disassembler"

Performance_Stats :: struct {
	fps: u32,
	frame_time: f32
}

App :: struct {
	running: bool,
	window: ^sdl.Window,
	renderer: ^sdl.Renderer,
}

main :: proc() {
	fmt.println("Running...")
	if dis.dissassemble("roms/splash.ch8") != dis.Disassembler_Error.None {
		
	}

	err := sdl.Init(sdl.INIT_EVERYTHING)
	if err != 0 {
		panic("SDL2 Init failed.")
	}
	defer sdl.Quit()
	
	img.Init(img.INIT_PNG)
	defer img.Quit()

	min_width :i32 = 32 * 16

	window := sdl.CreateWindow(
		"sdl",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		min_width,
		min_width,
		sdl.WINDOW_SHOWN | sdl.WINDOW_RESIZABLE,
	)
	if window == nil {
		panic("SDL2 CreateWindow failed.")
	}
	defer sdl.DestroyWindow(window)

	sdl.SetWindowMinimumSize(window, min_width / 2, min_width / 2)
	sdl.CreateRenderer(window, 0, {sdl.RendererFlag.ACCELERATED})

	renderer := sdl.GetRenderer(window)
	if renderer == nil {
		panic("Failed to GetRenderer!")
	}

	App := App {
		running = true
	}

	quit :: proc(state: ^App) {
		fmt.printf("Quitting...")
		state.running = false
	}

	for App.running {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case sdl.EventType.QUIT:
				quit(&App)
			case sdl.EventType.KEYUP:
				{
					if event.key.keysym.sym == sdl.Keycode.ESCAPE {
						quit(&App)
					}
				}
			}
		}

		mouse_x, mouse_y: i32
		sdl.GetMouseState(&mouse_x, &mouse_y)

		rect := sdl.Rect{0, 0, 200, 200}
		sdl.GetWindowSize(window, &rect.w, &rect.h)
		sdl.RenderClear(renderer)
		{
			sdl.SetRenderDrawColor(renderer, 0, 0, 100, 255)
			sdl.RenderFillRect(renderer, &rect)

			sdl.SetRenderDrawColor(renderer, 255, 255, 255, 255)
			sdl.RenderDrawLine(renderer, 0, 0, mouse_x, mouse_y)
		}
		sdl.RenderPresent(renderer)
	}
}

