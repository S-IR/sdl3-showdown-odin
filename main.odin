package main

import "core:fmt"
import "core:path/filepath"

import "core:os"
import sdl "vendor:sdl3"

PositionColorVertex :: struct {
	x, y, z:    f32,
	r, g, b, a: f32,
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

	width := 1280
	height := 720
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
		0,
		0,
		0,
	)
	sdl_panic_if(vertexShader == nil, "Vertex shader is null")
	fragmentShader := load_shader(
		device,
		filepath.join({"resources", "shader-binaries", "shader.frag.spv"}),
		0,
		0,
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
							format = .FLOAT4,
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

	bufferSize: u32 = size_of(PositionColorVertex) * 3
	vetexBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = bufferSize},
	)
	{
		transferBuffer := sdl.CreateGPUTransferBuffer(device, {usage = .UPLOAD, size = bufferSize})

		transferData := transmute([^]PositionColorVertex)sdl.MapGPUTransferBuffer(
			device,
			transferBuffer,
			true,
		)
		transferData[0] = {0.5, -0.5, 0.0, 1, 0, 0, 1}
		transferData[1] = {-0.5, -0.5, 0.0, 0, 1, 0, 1}
		transferData[2] = {0.0, 0.5, 0.0, 0, 0, 1, 1}
		sdl.UnmapGPUTransferBuffer(device, transferBuffer)

		uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
		copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)
		sdl.UploadToGPUBuffer(
			copyPass,
			{transfer_buffer = transferBuffer, offset = 0},
			{buffer = vetexBuffer, offset = 0, size = bufferSize},
			false,
		)

		sdl.EndGPUCopyPass(copyPass)
		sdl_panic_if(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) == false)
		sdl.ReleaseGPUTransferBuffer(device, transferBuffer)
	}

	e: sdl.Event
	quit := false

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
		}
		renderPass := sdl.BeginGPURenderPass(cmdBuf, &colorTargetInfo, 1, nil)
		sdl.BindGPUGraphicsPipeline(renderPass, pipeline)
		sdl.BindGPUVertexBuffers(
			renderPass,
			0,
			raw_data([]sdl.GPUBufferBinding{{buffer = vetexBuffer, offset = 0}}),
			1,
		)
		sdl.DrawGPUPrimitives(renderPass, 3, 1, 0, 0)
		sdl.EndGPURenderPass(renderPass)
	}

}
