package main
import "core:path/filepath"
import "core:strings"
import sdl "vendor:sdl3"

Vertex :: struct #packed {
	pos:    vec3,
	normal: vec3,
}

TOTAL_NUMBER_OF_INDICES :: 36
CUBE_INDEX_SIZE :: size_of(u16) * TOTAL_NUMBER_OF_INDICES
cubeIndices := [TOTAL_NUMBER_OF_INDICES]u16 {
	// Front face
	0,
	1,
	2,
	0,
	2,
	3,

	// Back face
	4,
	6,
	5, // Note the order here!
	4,
	7,
	6,

	// Right face
	8,
	10,
	9,
	8,
	11,
	10,

	// Left face
	12,
	14,
	13,
	12,
	15,
	14,

	// Top face
	16,
	17,
	18,
	16,
	18,
	19,

	// Bottom face
	20,
	22,
	21,
	20,
	23,
	22,
}

#assert(size_of(cubeIndices) == CUBE_INDEX_SIZE)

TOTAL_NUMBER_OF_VERTICES :: 24
CUBE_VERTEX_POSITION_SIZE :: size_of(vec3) * TOTAL_NUMBER_OF_VERTICES
CUBE_VERTEX_NORMALS_SIZE :: size_of(vec3) * TOTAL_NUMBER_OF_VERTICES

cubeVertexNormals := [TOTAL_NUMBER_OF_VERTICES]vec3 {
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, -1},
	{0, 0, -1},
	{0, 0, -1},
	{0, 0, -1},
	{1, 0, 0},
	{1, 0, 0},
	{1, 0, 0},
	{1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, -1, 0},
	{0, -1, 0},
	{0, -1, 0},
	{0, -1, 0},
}
cubeVertexPositions := [TOTAL_NUMBER_OF_VERTICES]vec3 {
	// Front face (z = 1)
	{-0.5, -0.5, 0.5},
	{0.5, -0.5, 0.5},
	{0.5, 0.5, 0.5},
	{-0.5, 0.5, 0.5},
	// Back face (z = -1)
	{-0.5, -0.5, -0.5},
	{0.5, -0.5, -0.5},
	{0.5, 0.5, -0.5},
	{-0.5, 0.5, -0.5},
	// Right face (x = 1)
	{0.5, -0.5, 0.5},
	{0.5, -0.5, -0.5},
	{0.5, 0.5, -0.5},
	{0.5, 0.5, 0.5},
	// Left face (x = -1)
	{-0.5, -0.5, 0.5},
	{-0.5, -0.5, -0.5},
	{-0.5, 0.5, -0.5},
	{-0.5, 0.5, 0.5},
	// Top face (y = 1)
	{-0.5, 0.5, 0.5},
	{0.5, 0.5, 0.5},
	{0.5, 0.5, -0.5},
	{-0.5, 0.5, -0.5},
	// Bottom face (y = -1)
	{-0.5, -0.5, 0.5},
	{0.5, -0.5, 0.5},
	{0.5, -0.5, -0.5},
	{-0.5, -0.5, -0.5},
}


cubesPipeline: ^sdl.GPUGraphicsPipeline
cubesVertexPositions, cubesVertexNormals, cubeVertexIndices: ^sdl.GPUBuffer
cubesSBO: ^sdl.GPUBuffer

cubes_load :: proc() {

	cubeVertexShader := load_shader(
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

	sdl_panic_if(cubeVertexShader == nil, "Vertex shader is null")
	fragmentShader := load_shader(
		device,
		filepath.join(
			{"resources", "shader-binaries", "cube.frag.spv"},
			allocator = context.temp_allocator,
		),
		0,
		2,
		0,
		0,
	)
	sdl_panic_if(fragmentShader == nil, "Frag shader is null")


	cubesPipelineInfo := sdl.GPUGraphicsPipelineCreateInfo {
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
		vertex_shader = cubeVertexShader,
		fragment_shader = fragmentShader,
	}
	cubesPipeline = sdl.CreateGPUGraphicsPipeline(device, cubesPipelineInfo)
	sdl_panic_if(cubesPipeline == nil, "could not create pipeline")

	sdl.ReleaseGPUShader(device, cubeVertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)
	assert(device != nil)

	init_cube_vertices()


	for x in 0 ..< GRID_SIZE {
		for z in 0 ..< GRID_SIZE {
			cubes[x * GRID_SIZE + z] = CubeInfo{{f32(x) * 2, 0.0, f32(z) * 2}, 0, {.5, .5, .5, 1}}
		}
	}

	cubesSBO = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)
	load_into_gpu_buffer(cubesSBO, raw_data(&cubes), size_of(cubes))


}

cubes_render :: proc(cmdBuf: ^sdl.GPUCommandBuffer, renderPass: ^sdl.GPURenderPass) {
	sdl.BindGPUGraphicsPipeline(renderPass, cubesPipeline)
	Camera_frame_update(&camera, cmdBuf)

	sdl.BindGPUVertexStorageBuffers(renderPass, 0, raw_data([]^sdl.GPUBuffer{cubesSBO}), 1)
	assert(cubesVertexPositions != nil)

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


	//stop RIGHT HERE
	sdl.BindGPUIndexBuffer(renderPass, {buffer = cubeVertexIndices, offset = 0}, ._16BIT)

	sdl.PushGPUFragmentUniformData(cmdBuf, 1, &lightingData, size_of(lightingData))
	sdl.DrawGPUIndexedPrimitives(
		renderPass,
		TOTAL_NUMBER_OF_INDICES,
		GRID_SIZE * GRID_SIZE,
		0,
		0,
		0,
	)

}
init_cube_vertices :: proc() {
	// Create vertex buffer
	cubesVertexPositions = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(CUBE_VERTEX_POSITION_SIZE)},
	)
	sdl_panic_if(cubesVertexPositions == nil, "vertex buffer is nil")

	// Create vertex buffer
	cubesVertexNormals = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(CUBE_VERTEX_NORMALS_SIZE)},
	)
	sdl_panic_if(cubesVertexNormals == nil, "vertex buffer is nil")

	// Create index buffer
	cubeVertexIndices = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = CUBE_INDEX_SIZE},
	)
	sdl_panic_if(cubeVertexIndices == nil, "indices buffer is nil")


	load_into_gpu_buffer(cubesVertexPositions, &cubeVertexPositions, CUBE_VERTEX_POSITION_SIZE)
	load_into_gpu_buffer(cubesVertexNormals, &cubeVertexNormals, CUBE_VERTEX_NORMALS_SIZE)
	load_into_gpu_buffer(cubeVertexIndices, &cubeIndices, CUBE_INDEX_SIZE)
}
cubes_cleanup :: proc() {
	sdl.ReleaseGPUBuffer(device, cubesSBO)
	sdl.ReleaseGPUBuffer(device, cubesVertexPositions)
	sdl.ReleaseGPUBuffer(device, cubesVertexNormals)
	sdl.ReleaseGPUBuffer(device, cubeVertexIndices)

	sdl.ReleaseGPUGraphicsPipeline(device, cubesPipeline)

}
