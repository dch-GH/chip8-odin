package main

import "core:fmt"
import sdl "vendor:sdl2"

TILE_SIZE :: 32

App_State :: struct {
	running: bool,
}

main :: proc() {
	fmt.println("Hi")
	err := sdl.Init(sdl.INIT_EVERYTHING)
	if err != 0 {
		panic("SDL2 Init failed.")
	}
	defer sdl.Quit()

	window := sdl.CreateWindow(
		"sdl",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		TILE_SIZE * 16,
		TILE_SIZE * 16,
		sdl.WINDOW_SHOWN,
	)
	if window == nil {
		panic("SDL2 CreateWindow failed.")
	}
	defer sdl.DestroyWindow(window)

	sdl.CreateRenderer(window, 0, {sdl.RendererFlag.ACCELERATED})

	renderer := sdl.GetRenderer(window)
	if renderer == nil {
		panic("Failed to GetRenderer!")
	}

	app_state := App_State {
		running = true
	}

	quit :: proc(state: ^App_State) {
		fmt.printf("Quitting...")
		state.running = false
	}

	for app_state.running {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case sdl.EventType.QUIT:
				quit(&app_state)
			case sdl.EventType.KEYUP:
				{
					if event.key.keysym.sym == sdl.Keycode.ESCAPE {
						quit(&app_state)
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
