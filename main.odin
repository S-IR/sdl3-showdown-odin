package main
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"
vec3 :: [3]f32
PositionColorVertex :: struct {
	x, y, z:    f32,
	r, g, b, a: u8,
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

	width: i32 = 1280
	height: i32 = 720
	sdl_panic_if(sdl.Init({.VIDEO}) == false)
	window := sdl.CreateWindow("Hello triangle", i32(width), i32(height), {.RESIZABLE})
	defer sdl.DestroyWindow(window)

	device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_panic_if(device == nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_panic_if(
		sdl.ClaimWindowForGPUDevice(device, window) == false,
		"could not create gpu device",
	)

	vertexShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "shader.vert.spv"}),
		0,
		1,
		0,
		0,
	)
	sdl_panic_if(vertexShader == nil, "Vertex shader is null")
	fragmentShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "shader.frag.spv"}),
		0,
		1,
		0,
		0,
	)
	sdl_panic_if(fragmentShader == nil, "Frag shader is null")


	pipeline := sdl.CreateGPUGraphicsPipeline(
		device,
		sdl.GPUGraphicsPipelineCreateInfo {
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = raw_data(
					[]sdl.GPUColorTargetDescription {
						{format = sdl.GetGPUSwapchainTextureFormat(device, window)},
					},
				),
				has_depth_stencil_target = true,
				depth_stencil_format = .D24_UNORM,
			},
			depth_stencil_state = sdl.GPUDepthStencilState {
				enable_depth_test = true,
				enable_depth_write = true,
				enable_stencil_test = false,
				compare_op = .LESS,
				write_mask = 0xFF,
			},
			rasterizer_state = {
				cull_mode = .NONE,
				fill_mode = .FILL,
				front_face = .COUNTER_CLOCKWISE,
			},
			vertex_input_state = {
				num_vertex_buffers = 1,
				vertex_buffer_descriptions = raw_data(
					[]sdl.GPUVertexBufferDescription {
						{
							slot = 0,
							instance_step_rate = 0,
							input_rate = .VERTEX,
							pitch = size_of(PositionColorVertex),
						},
					},
				),
				num_vertex_attributes = 2,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
						{
							buffer_slot = 0,
							format = .UBYTE4_NORM,
							location = 1,
							offset = u32(offset_of(PositionColorVertex, r)),
						},
					},
				),
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vertexShader,
			fragment_shader = fragmentShader,
		},
	)
	sdl_panic_if(pipeline == nil, "could not create pipeline")

	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)

	sdl.GetWindowSizeInPixels(window, &width, &height)
	depthTexture := sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			format = .D24_UNORM,
			usage = {.DEPTH_STENCIL_TARGET},
		},
	)
	defer sdl.ReleaseGPUTexture(device, depthTexture)

	CUBE_VERTEX_SIZE: u32 = size_of(PositionColorVertex) * 24


	vertexBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = CUBE_VERTEX_SIZE},
	)
	sdl_panic_if(vertexBuffer == nil, "vertex buffer is nil ")
	defer sdl.ReleaseGPUBuffer(device, vertexBuffer)


	TOTAL_NUMBER_OF_INDICES :: 36
	CUBE_INDEX_SIZE: u32 = size_of(u16) * TOTAL_NUMBER_OF_INDICES
	indicesBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = CUBE_INDEX_SIZE},
	)
	defer sdl.ReleaseGPUBuffer(device, indicesBuffer)
	sdl_panic_if(indicesBuffer == nil, "indices buffer is nil ")


	{
		transferBuffer := sdl.CreateGPUTransferBuffer(
			device,
			{usage = .UPLOAD, size = CUBE_VERTEX_SIZE + CUBE_INDEX_SIZE},
		)

		transferData := transmute([^]PositionColorVertex)sdl.MapGPUTransferBuffer(
			device,
			transferBuffer,
			true,
		)

		transferData[0] = {-10, -10, -10, 255, 0, 0, 255}
		transferData[1] = {10, -10, -10, 255, 0, 0, 255}
		transferData[2] = {10, 10, -10, 255, 0, 0, 255}
		transferData[3] = {-10, 10, -10, 255, 0, 0, 255}

		transferData[4] = {-10, -10, 10, 255, 255, 0, 255}
		transferData[5] = {10, -10, 10, 255, 255, 0, 255}
		transferData[6] = {10, 10, 10, 255, 255, 0, 255}
		transferData[7] = {-10, 10, 10, 255, 255, 0, 255}

		transferData[8] = {-10, -10, -10, 255, 0, 255, 255}
		transferData[9] = {-10, 10, -10, 255, 0, 255, 255}
		transferData[10] = {-10, 10, 10, 255, 0, 255, 255}
		transferData[11] = {-10, -10, 10, 255, 0, 255, 255}

		transferData[12] = {10, -10, -10, 0, 255, 0, 255}
		transferData[13] = {10, 10, -10, 0, 255, 0, 255}
		transferData[14] = {10, 10, 10, 0, 255, 0, 255}
		transferData[15] = {10, -10, 10, 0, 255, 0, 255}

		transferData[16] = {-10, -10, -10, 0, 255, 255, 255}
		transferData[17] = {-10, -10, 10, 0, 255, 255, 255}
		transferData[18] = {10, -10, 10, 0, 255, 255, 255}
		transferData[19] = {10, -10, -10, 0, 255, 255, 255}

		transferData[20] = {-10, 10, -10, 0, 0, 255, 255}
		transferData[21] = {-10, 10, 10, 0, 0, 255, 255}
		transferData[22] = {10, 10, 10, 0, 0, 255, 255}
		transferData[23] = {10, 10, -10, 0, 0, 255, 255}

		indexData := transmute([^]u16)&transferData[CUBE_VERTEX_SIZE]

		indices := [?]u16 {
			0,
			1,
			2,
			0,
			2,
			3,
			4,
			5,
			6,
			4,
			6,
			7,
			8,
			9,
			10,
			8,
			10,
			11,
			12,
			13,
			14,
			12,
			14,
			15,
			16,
			17,
			18,
			16,
			18,
			19,
			20,
			21,
			22,
			20,
			22,
			23,
		}
		sdl.memcpy(indexData, raw_data(&indices), size_of(indices))

		sdl.UnmapGPUTransferBuffer(device, transferBuffer)

		uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
		copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)
		sdl.UploadToGPUBuffer(
			copyPass,
			{transfer_buffer = transferBuffer, offset = 0},
			{buffer = vertexBuffer, offset = 0, size = CUBE_VERTEX_SIZE},
			false,
		)

		sdl.UploadToGPUBuffer(
			copyPass,
			{transfer_buffer = transferBuffer, offset = CUBE_VERTEX_SIZE},
			{buffer = indicesBuffer, offset = 0, size = CUBE_INDEX_SIZE},
			false,
		)
		sdl.EndGPUCopyPass(copyPass)
		sdl_panic_if(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) == false)
		sdl.ReleaseGPUTransferBuffer(device, transferBuffer)
	}

	e: sdl.Event
	quit := false

	dt: f64
	rotationSpeed: f32 = 5.0
	lastTime := time.now()
	radius: f32 = 30.0

	nearPlane: f32 = 0.1
	farPlane: f32 = 60000.0
	rotationAngle: f32 = 0.0

	movementSpeed := 5.0
	for !quit {
		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				quit = true
				break
			case .KEY_DOWN:
				if e.key.key == sdl.K_ESCAPE {
					quit = true
				}
			case:
				continue
			}
		}
		dt = time.duration_milliseconds(time.since(lastTime))
		lastTime = time.now()

		rotationAngle = rotationSpeed * f32(dt)

		cmdBuf := sdl.AcquireGPUCommandBuffer(device)
		if cmdBuf == nil do continue
		defer sdl_panic_if(sdl.SubmitGPUCommandBuffer(cmdBuf) == false)

		swapTexture: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(cmdBuf, window, &swapTexture, nil, nil) == false do continue


		colorTargetInfo := sdl.GPUColorTargetInfo {
			texture     = swapTexture,
			clear_color = {0.3, 0.2, 0.7, 1.0},
			load_op     = .CLEAR,
			store_op    = .STORE,
			// texture     = swapTexture,
			// clear_color = {0.3, 0.2, 0.7, 1.0},
			// load_op     = .CLEAR,
			// store_op    = .STORE,
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
		sdl.BindGPUGraphicsPipeline(renderPass, pipeline)
		sdl.BindGPUVertexBuffers(
			renderPass,
			0,
			raw_data([]sdl.GPUBufferBinding{{buffer = vertexBuffer, offset = 0}}),
			1,
		)
		sdl.BindGPUIndexBuffer(renderPass, {buffer = indicesBuffer, offset = 0}, ._16BIT)
		cameraPos := vec3 {
			math.cos(math.RAD_PER_DEG * rotationAngle) * radius,
			30,
			math.sin(math.RAD_PER_DEG * rotationAngle) * radius,
		}

		model: matrix[4, 4]f32 = f32(1)
		view := linalg.matrix4_look_at_f32(cameraPos, {0, 0, 0}, {0, 1, 0})
		proj := linalg.matrix4_perspective_f32(
			math.RAD_PER_DEG * 75.0,
			f32(width) / f32(height),
			f32(nearPlane),
			f32(farPlane),
		)
		transforms: [3]matrix[4, 4]f32 = {model, view, proj}
		sdl.PushGPUVertexUniformData(cmdBuf, 0, raw_data(&transforms), size_of(transforms))

		planes := [2]f32{nearPlane, farPlane}
		sdl.PushGPUFragmentUniformData(cmdBuf, 0, raw_data(&planes), size_of(planes))

		sdl.DrawGPUIndexedPrimitives(renderPass, TOTAL_NUMBER_OF_INDICES, 1, 0, 0, 0)
		sdl.EndGPURenderPass(renderPass)
	}

}
