package main

import "core:path/filepath"
import "core:strings"
import sdl "vendor:sdl3"

lightingData: LightInfo = {
	pos   = {5, 5, 5},
	color = {1, 1, 1, 1},
}


lightingingPipeline: ^sdl.GPUGraphicsPipeline
lightingSBO: ^sdl.GPUBuffer

lighting_load :: proc() {

	lightingVertexShader := load_shader(
		device,
		filepath.join(
			{"resources", "shader-binaries", "cube.vert.spv"},
			allocator = context.temp_allocator,
		),
		0,
		1,
		1,
		0,
	)

	lightingFragmentShader := load_shader(
		device,
		filepath.join(
			{"resources", "shader-binaries", "lightCube.frag.spv"},
			allocator = context.temp_allocator,
		),
		0,
		1,
		0,
		0,
	)

	lightingCubePipelineInfo := sdl.GPUGraphicsPipelineCreateInfo {
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
			num_vertex_buffers = 2,
			vertex_buffer_descriptions = raw_data(
				[]sdl.GPUVertexBufferDescription {
					{
						slot = 0,
						instance_step_rate = 0,
						input_rate = .VERTEX,
						pitch = size_of(vec3),
					},
					{
						slot = 1,
						instance_step_rate = 0,
						input_rate = .VERTEX,
						pitch = size_of(vec3),
					},
				},
			),
			num_vertex_attributes = 2,
			vertex_attributes = raw_data(
				[]sdl.GPUVertexAttribute {
					{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
					{buffer_slot = 1, format = .FLOAT3, location = 1, offset = 0},
				},
			),
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = lightingVertexShader,
		fragment_shader = lightingFragmentShader,
	}


	lightingingPipeline = sdl.CreateGPUGraphicsPipeline(device, lightingCubePipelineInfo)
	sdl_panic_if(lightingingPipeline == nil, "could not create lighting cube pipeline")

	lightingSBO = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)

	if cubesVertexNormals == nil || cubesVertexPositions == nil || cubeVertexIndices == nil {
		init_cube_vertices()
	}

	load_into_gpu_buffer(lightingSBO, &lightingData, size_of(lightingData))
	sdl.ReleaseGPUShader(device, lightingVertexShader)
	sdl.ReleaseGPUShader(device, lightingFragmentShader)

}
lighting_render :: proc(cmdBuf: ^sdl.GPUCommandBuffer, renderPass: ^sdl.GPURenderPass) {

	sdl.BindGPUGraphicsPipeline(renderPass, lightingingPipeline)
	Camera_frame_update(&camera, cmdBuf)

	sdl.BindGPUVertexStorageBuffers(renderPass, 0, &lightingSBO, 1)

	sdl.BindGPUVertexBuffers(
		renderPass,
		0,
		raw_data(
			[]sdl.GPUBufferBinding {
				{buffer = cubesVertexPositions, offset = 0},
				{buffer = cubesVertexNormals, offset = 0},
			},
		),
		2,
	)
	sdl.BindGPUIndexBuffer(renderPass, {buffer = cubeVertexIndices, offset = 0}, ._16BIT)

	// planes := [2]f32{nearPlane, farPlane}
	// sdl.PushGPUFragmentUniformData(cmdBuf, 0, raw_data(&planes), size_of(planes))

	sdl.DrawGPUIndexedPrimitives(renderPass, TOTAL_NUMBER_OF_INDICES, 1, 0, 0, 0)


}
lighting_cleanup :: proc() {
	sdl.ReleaseGPUBuffer(device, lightingSBO)
	sdl.ReleaseGPUGraphicsPipeline(device, lightingingPipeline)
}
