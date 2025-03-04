package main
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
CUBE_VERTEX_SIZE :: size_of(Vertex) * TOTAL_NUMBER_OF_VERTICES
cubeVertices := [TOTAL_NUMBER_OF_VERTICES]Vertex {
	// Front face (z = 1)
	{{-0.5, -0.5, 0.5}, {0, 0, 1}},
	{{0.5, -0.5, 0.5}, {0, 0, 1}},
	{{0.5, 0.5, 0.5}, {0, 0, 1}},
	{{-0.5, 0.5, 0.5}, {0, 0, 1}},

	// Back face (z = -1)
	{{-0.5, -0.5, -0.5}, {0, 0, -1}},
	{{0.5, -0.5, -0.5}, {0, 0, -1}},
	{{0.5, 0.5, -0.5}, {0, 0, -1}},
	{{-0.5, 0.5, -0.5}, {0, 0, -1}},

	// Right face (x = 1)
	{{0.5, -0.5, 0.5}, {1, 0, 0}},
	{{0.5, -0.5, -0.5}, {1, 0, 0}},
	{{0.5, 0.5, -0.5}, {1, 0, 0}},
	{{0.5, 0.5, 0.5}, {1, 0, 0}},

	// Left face (x = -1)
	{{-0.5, -0.5, 0.5}, {-1, 0, 0}},
	{{-0.5, -0.5, -0.5}, {-1, 0, 0}},
	{{-0.5, 0.5, -0.5}, {-1, 0, 0}},
	{{-0.5, 0.5, 0.5}, {-1, 0, 0}},

	// Top face (y = 1)
	{{-0.5, 0.5, 0.5}, {0, 1, 0}},
	{{0.5, 0.5, 0.5}, {0, 1, 0}},
	{{0.5, 0.5, -0.5}, {0, 1, 0}},
	{{-0.5, 0.5, -0.5}, {0, 1, 0}},

	// Bottom face (y = -1)
	{{-0.5, -0.5, 0.5}, {0, -1, 0}},
	{{0.5, -0.5, 0.5}, {0, -1, 0}},
	{{0.5, -0.5, -0.5}, {0, -1, 0}},
	{{-0.5, -0.5, -0.5}, {0, -1, 0}},
}
#assert(size_of(cubeVertices) == CUBE_VERTEX_SIZE)

upload_cube_vertices :: proc() -> (vertexBuffer: ^sdl.GPUBuffer, indicesBuffer: ^sdl.GPUBuffer) {
	assert(device != nil)

	// Create vertex buffer
	vertexBuffer = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(CUBE_VERTEX_SIZE)},
	)
	sdl_panic_if(vertexBuffer == nil, "vertex buffer is nil")

	// Create index buffer
	indicesBuffer = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = CUBE_INDEX_SIZE},
	)
	sdl_panic_if(indicesBuffer == nil, "indices buffer is nil")

	// Create transfer buffer for both vertex and index data
	transferBuffer := sdl.CreateGPUTransferBuffer(
		device,
		sdl.GPUTransferBufferCreateInfo {
			usage = .UPLOAD,
			size = CUBE_VERTEX_SIZE + CUBE_INDEX_SIZE,
		},
	)
	defer sdl.ReleaseGPUTransferBuffer(device, transferBuffer)

	// Map the transfer buffer
	transferPtr := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
	if transferPtr == nil {
		sdl_panic_if(true, "Failed to map transfer buffer")
	}

	// Copy vertex data to first part of transfer buffer
	sdl.memcpy(transferPtr, raw_data(&cubeVertices), CUBE_VERTEX_SIZE)

	// Copy index data to second part of transfer buffer
	sdl.memcpy(
		rawptr(uintptr(transferPtr) + uintptr(CUBE_VERTEX_SIZE)),
		raw_data(&cubeIndices),
		uint(CUBE_INDEX_SIZE),
	)

	sdl.UnmapGPUTransferBuffer(device, transferBuffer)

	// Upload both buffers
	uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
	copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)

	// Upload vertices
	sdl.UploadToGPUBuffer(
		copyPass,
		sdl.GPUTransferBufferLocation{transfer_buffer = transferBuffer, offset = 0},
		sdl.GPUBufferRegion{buffer = vertexBuffer, offset = 0, size = CUBE_VERTEX_SIZE},
		true,
	)

	// Upload indices
	sdl.UploadToGPUBuffer(
		copyPass,
		sdl.GPUTransferBufferLocation{transfer_buffer = transferBuffer, offset = CUBE_VERTEX_SIZE},
		sdl.GPUBufferRegion{buffer = indicesBuffer, offset = 0, size = CUBE_INDEX_SIZE},
		true,
	)

	sdl.EndGPUCopyPass(copyPass)
	sdl_panic_if(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) == false)

	return vertexBuffer, indicesBuffer
}
