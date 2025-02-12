package main
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "vendor:cgltf"

import sdl "vendor:sdl3"
vec3 :: [3]f32
vec4 :: [4]f32
GRID_SIZE :: 4
cubes := [GRID_SIZE * GRID_SIZE]CubeInfo{}

CubeInfo :: struct #packed {
	pos:   vec3,
	_pad0: f32,
	color: vec4,
}


LightInfo :: struct {
	pos:   vec3,
	_pad0: f32,
	color: vec4,
}

camera := Camera_new()


sdl_panic_if :: proc(cond: bool, message: string = "") {
	if cond {
		if len(message) > 0 {
			fmt.println(message)
		}
		fmt.println(sdl.GetError())
		os.exit(1)
	}

}

main :: proc() {

	// when ODIN_DEBUG {
	// 	track: mem.Tracking_Allocator
	// 	mem.tracking_allocator_init(&track, context.allocator)
	// 	context.allocator = mem.tracking_allocator(&track)

	// 	defer {
	// 		if len(track.allocation_map) > 0 {
	// 			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
	// 			for _, entry in track.allocation_map {
	// 				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
	// 			}
	// 		}
	// 		if len(track.bad_free_array) > 0 {
	// 			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
	// 			for entry in track.bad_free_array {
	// 				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
	// 			}
	// 		}
	// 		mem.tracking_allocator_destroy(&track)
	// 	}
	// }


	sdl_panic_if(sdl.Init({.VIDEO}) == false)
	window = sdl.CreateWindow(
		"Hello triangle",
		i32(screenWidth),
		i32(screenHeight),
		{.RESIZABLE, .FULLSCREEN},
	)
	sdl_panic_if(window == nil)

	sdl.GetWindowSizeInPixels(window, &screenWidth, &screenHeight)

	device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_panic_if(device == nil)

	defer {
		sdl.DestroyWindow(window)
		sdl.DestroyGPUDevice(device)
	}

	sdl_panic_if(
		sdl.ClaimWindowForGPUDevice(device, window) == false,
		"could not create gpu device",
	)


	// dogData, cgltfResult := cgltf.parse_file(
	// 	{},
	// 	strings.clone_to_cstring(
	// 		filepath.join({"resources", "models", "dog.gltf"}),
	// 		allocator = context.temp_allocator,
	// 	),
	// )

	// if cgltfResult != .success {
	// 	panic(fmt.tprintf("cfltf did not import the file properly, got: %v"))
	// }
	cubes_load()
	defer cubes_cleanup()

	lighting_load()
	defer lighting_cleanup()


	depthTexture := sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			width = u32(screenWidth),
			height = u32(screenHeight),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			format = .D24_UNORM,
			usage = {.DEPTH_STENCIL_TARGET},
		},
	)
	defer sdl.ReleaseGPUTexture(device, depthTexture)


	quit := false
	lastTime := time.now()
	FPS :: 144
	frameTime := f64(time.Second) / f64(FPS) // Target time per frame in nanoseconds
	frameDuration := time.Duration(frameTime) // Convert to Duration type
	lightingAddDir: f32 = 1

	movementSpeed := 5.0
	for !quit {
		defer free_all(context.temp_allocator)
		e: sdl.Event
		frameStart := time.now()

		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				quit = true
				break
			case .KEY_DOWN:
				if e.key.key == sdl.K_ESCAPE {
					quit = true
				}
			case .WINDOW_RESIZED:
				screenWidth, screenHeight := e.window.data1, e.window.data2

				sdl.SetWindowSize(window, screenWidth, screenHeight)


				sdl.ReleaseGPUTexture(device, depthTexture)
				depthTexture = sdl.CreateGPUTexture(
					device,
					sdl.GPUTextureCreateInfo {
						type = .D2,
						width = u32(screenWidth),
						height = u32(screenHeight),
						layer_count_or_depth = 1,
						num_levels = 1,
						sample_count = ._1,
						format = .D24_UNORM,
						usage = {.DEPTH_STENCIL_TARGET},
					},
				)

				sdl.SyncWindow(window)

			case .MOUSE_MOTION:
				Camera_process_mouse_movement(&camera, e.motion.xrel, e.motion.yrel)
			case:
				continue
			}
		}
		Camera_process_keyboard_movement(&camera)
		// Update rotation angle based on time
		cmdBuf := sdl.AcquireGPUCommandBuffer(device)
		if cmdBuf == nil do continue
		defer sdl_panic_if(sdl.SubmitGPUCommandBuffer(cmdBuf) == false)

		// fmt.printfln("camera %v", camera)
		swapTexture: ^sdl.GPUTexture
		widthU32 := u32(screenWidth)
		heightU32 := u32(screenHeight)


		if sdl.WaitAndAcquireGPUSwapchainTexture(cmdBuf, window, &swapTexture, &widthU32, &heightU32) == false do continue

		colorTargetInfo := sdl.GPUColorTargetInfo {
			texture     = swapTexture,
			clear_color = {0.3, 0.2, 0.7, 1.0},
			load_op     = .CLEAR,
			store_op    = .STORE,
		}

		depthStencilTargetInfo: sdl.GPUDepthStencilTargetInfo = {
			texture          = depthTexture,
			cycle            = true,
			clear_depth      = 1,
			clear_stencil    = 0,
			load_op          = .CLEAR,
			store_op         = .STORE,
			stencil_load_op  = .CLEAR,
			stencil_store_op = .STORE,
		}

		renderPass := sdl.BeginGPURenderPass(cmdBuf, &colorTargetInfo, 1, &depthStencilTargetInfo)

		cubes_render(cmdBuf, renderPass)
		lighting_render(cmdBuf, renderPass)


		sdl.EndGPURenderPass(renderPass)

		frameEnd := time.now()
		frameDuration := time.diff(frameEnd, frameStart)

		// Calculate how long to sleep
		if frameDuration < time.Duration(frameTime) {
			sleepTime := time.Duration(frameTime) - frameDuration
			time.sleep(sleepTime)
		}

		// Calculate actual dt for next frame
		dt = time.duration_milliseconds(time.since(lastTime)) * 0.001
		lastTime = time.now()
	}

}
