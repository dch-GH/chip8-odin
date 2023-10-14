package main

import "core:fmt"
import alg "core:math/linalg"
import sdl "vendor:sdl2"
import img "vendor:sdl2/image"

import dis "disassembler"
import "util"

Performance_Stats :: struct {
	fps:        u32,
	frame_time: f32,
}

App :: struct {
	running:  bool,
	window:   ^sdl.Window,
	renderer: ^sdl.Renderer,
	chip:     ^Interpreter,
}

main :: proc() {
	fmt.println("Running...")
	err := sdl.Init(sdl.INIT_EVERYTHING)
	if err != 0 {
		panic("SDL2 Init failed.")
	}
	defer sdl.Quit()

	img.Init(img.INIT_PNG)
	defer img.Quit()

	min_width: i32 = 32 * 16

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
		panic("SDL2 GetRenderer failed!")
	}

	app := new(App)
	app.running = true
	app.window = window
	app.renderer = renderer
	app.chip = new(Interpreter)
	incl(&app.chip.debug_flags, Debug_Flag.Log_RAM, Debug_Flag.Log_ROM)

	if !interpreter_initialize(app.chip) {quit(app)}

	defer interpreter_destroy(app.chip)
	defer free(app)

	if !load_rom(app.chip, "roms/splash.ch8") {
		fmt.eprintln("Couldn't load rom!")
		quit(app)
	}

	quit :: proc(state: ^App) {
		fmt.printf("Quitting...")
		state.running = false
	}

	for app.running {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case sdl.EventType.QUIT:
				quit(app)
			case sdl.EventType.KEYUP:
				{
					if event.key.keysym.sym == sdl.Keycode.ESCAPE {
						quit(app)
					}
				}
			}
		}

		if !app.running {break}

		ticks := sdl.GetTicks()

		mouse_x, mouse_y: i32
		sdl.GetMouseState(&mouse_x, &mouse_y)

		rect := sdl.Rect{0, 0, 200, 200}
		sdl.GetWindowSize(window, &rect.w, &rect.h)

		interpreter_tick(app.chip, ticks)

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
