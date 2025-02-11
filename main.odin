package main
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:path/filepath"
import "core:time"
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
	sdl_panic_if(sdl.Init({.VIDEO}) == false)
	window = sdl.CreateWindow(
		"Hello triangle",
		i32(screenWidth),
		i32(screenHeight),
		{.RESIZABLE, .FULLSCREEN},
	)
	sdl_panic_if(window == nil)
	defer sdl.DestroyWindow(window)

	sdl.GetWindowSizeInPixels(window, &screenWidth, &screenHeight)

	device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_panic_if(device == nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_panic_if(
		sdl.ClaimWindowForGPUDevice(device, window) == false,
		"could not create gpu device",
	)

	vertexShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "cube.vert.spv"}),
		0,
		1,
		1,
		0,
	)

	sdl_panic_if(vertexShader == nil, "Vertex shader is null")
	fragmentShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "cube.frag.spv"}),
		0,
		2,
		0,
		0,
	)
	sdl_panic_if(fragmentShader == nil, "Frag shader is null")

	cubePipelineInfo := sdl.GPUGraphicsPipelineCreateInfo {
		target_info = {
			num_color_targets         = 1,
			color_target_descriptions = raw_data(
				[]sdl.GPUColorTargetDescription {
					{
						format = sdl.GetGPUSwapchainTextureFormat(device, window),
						// blend_state = {
						// 	enable_blend = true,
						// 	color_blend_op = .ADD,
						// 	alpha_blend_op = .ADD,
						// 	src_color_blendfactor = .SRC_ALPHA,
						// 	dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						// 	src_alpha_blendfactor = .SRC_ALPHA,
						// 	dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						// },
					},
				},
			),
			has_depth_stencil_target  = true,
			depth_stencil_format      = .D24_UNORM,
		},
		depth_stencil_state = sdl.GPUDepthStencilState {
			enable_depth_test = true,
			enable_depth_write = true,
			enable_stencil_test = false,
			compare_op = .LESS,
			write_mask = 0xFF,
		},
		rasterizer_state = {cull_mode = .NONE, fill_mode = .FILL, front_face = .COUNTER_CLOCKWISE},
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = raw_data(
				[]sdl.GPUVertexBufferDescription {
					{
						slot = 0,
						instance_step_rate = 0,
						input_rate = .VERTEX,
						pitch = size_of(Vertex),
					},
				},
			),
			num_vertex_attributes = 2,
			vertex_attributes = raw_data(
				[]sdl.GPUVertexAttribute {
					{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
					{
						buffer_slot = 0,
						format = .FLOAT3,
						location = 1,
						offset = u32(offset_of(Vertex, normal)),
					},
				},
			),
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vertexShader,
		fragment_shader = fragmentShader,
	}
	cubePipeline := sdl.CreateGPUGraphicsPipeline(device, cubePipelineInfo)
	sdl_panic_if(cubePipeline == nil, "could not create pipeline")

	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)


	lightFragShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "lightCube.frag.spv"}),
		0,
		1,
		0,
		0,
	)
	lightCubePipelineInfo := cubePipelineInfo
	lightCubePipelineInfo.fragment_shader = lightFragShader
	lightingPipeline := sdl.CreateGPUGraphicsPipeline(device, lightCubePipelineInfo)
	sdl_panic_if(lightingPipeline == nil, "could not create light cube pipeline")
	sdl.ReleaseGPUShader(device, lightFragShader)


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


	cubeVertexBuffer, cubeIndicesBuffer := upload_cube_vertices()
	defer {
		sdl.ReleaseGPUBuffer(device, cubeVertexBuffer)
		sdl.ReleaseGPUBuffer(device, cubeIndicesBuffer)
	}
	cubesBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)
	defer sdl.ReleaseGPUBuffer(device, cubesBuffer)


	{
		for x in 0 ..< GRID_SIZE {
			for z in 0 ..< GRID_SIZE {
				cubes[x * GRID_SIZE + z] = CubeInfo {
					{f32(x) * 2, 0.0, f32(z) * 2},
					0,
					{.5, .5, .5, 1},
				}
			}
		}
		load_into_gpu_buffer(cubesBuffer, raw_data(&cubes), size_of(cubes))
	}


	lighting: LightInfo = {
		pos   = {5, 5, 5},
		color = {1, 1, 1, 1},
	}

	lightCubeBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)
	defer sdl.ReleaseGPUBuffer(device, lightCubeBuffer)
	load_into_gpu_buffer(lightCubeBuffer, &lighting, size_of(lighting))


	quit := false
	lastTime := time.now()


	FPS :: 144
	frameTime := f64(time.Second) / f64(FPS) // Target time per frame in nanoseconds
	frameDuration := time.Duration(frameTime) // Convert to Duration type
	camera := Camera_new()
	lightAddDir: f32 = 1

	movementSpeed := 5.0
	for !quit {
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
		{

			sdl.BindGPUGraphicsPipeline(renderPass, lightingPipeline)
			Camera_frame_update(&camera, cmdBuf)

			sdl.BindGPUVertexStorageBuffers(renderPass, 0, &lightCubeBuffer, 1)

			sdl.BindGPUVertexBuffers(
				renderPass,
				0,
				raw_data([]sdl.GPUBufferBinding{{buffer = cubeVertexBuffer, offset = 0}}),
				1,
			)
			sdl.BindGPUIndexBuffer(renderPass, {buffer = cubeIndicesBuffer, offset = 0}, ._16BIT)

			// planes := [2]f32{nearPlane, farPlane}
			// sdl.PushGPUFragmentUniformData(cmdBuf, 0, raw_data(&planes), size_of(planes))

			sdl.DrawGPUIndexedPrimitives(renderPass, TOTAL_NUMBER_OF_INDICES, 1, 0, 0, 0)

		}

		{
			sdl.BindGPUGraphicsPipeline(renderPass, cubePipeline)
			Camera_frame_update(&camera, cmdBuf)

			sdl.BindGPUVertexStorageBuffers(renderPass, 0, &cubesBuffer, 1)
			sdl.BindGPUVertexBuffers(
				renderPass,
				0,
				raw_data([]sdl.GPUBufferBinding{{buffer = cubeVertexBuffer, offset = 0}}),
				1,
			)
			sdl.BindGPUIndexBuffer(renderPass, {buffer = cubeIndicesBuffer, offset = 0}, ._16BIT)


			// planes := [2]f32{nearPlane, farPlane}
			// sdl.PushGPUFragmentUniformData(cmdBuf, 0, raw_data(&planes), size_of(planes))

			// lighting.color += f32(dt) * 00.1 * lightAddDir
			// if lighting.color.x >= 1 {
			// 	lighting.color = {1, 1, 1, 1}
			// 	lightAddDir *= -1
			// }

			// if lighting.color.x <= 0 {
			// 	lighting.color = {0, 0, 0, 1}
			// 	lightAddDir *= -1
			// }
			// lighting.color[3] = 1

			sdl.PushGPUFragmentUniformData(cmdBuf, 1, &lighting, size_of(lighting))
			sdl.DrawGPUIndexedPrimitives(
				renderPass,
				TOTAL_NUMBER_OF_INDICES,
				GRID_SIZE * GRID_SIZE,
				0,
				0,
				0,
			)
		}


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
