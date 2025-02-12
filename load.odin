package main
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"

load_shader :: proc(
	device: ^sdl.GPUDevice,
	shaderPath: string,
	samplerCount, uniformBufferCount, storageBufferCount, storageTextureCount: u32,
) -> ^sdl.GPUShader {

	stage: sdl.GPUShaderStage
	if strings.contains(shaderPath, ".vert") {
		stage = .VERTEX
	} else if strings.contains(shaderPath, ".frag") {
		stage = .FRAGMENT
	} else {
		panic(
			fmt.tprintf("Shader suffix is neither .vert or .frag, shader path is %s", shaderPath),
		)
	}

	format := sdl.GetGPUShaderFormats(device)
	entrypoint: cstring
	if format == {.SPIRV} || format == {.DXIL} {
		entrypoint = "main"
	} else {
		panic("unsupported backend shader format")
	}

	codeSize: uint
	code := sdl.LoadFile(strings.clone_to_cstring(shaderPath, context.temp_allocator), &codeSize)
	sdl_panic_if(code == nil)
	defer sdl.free(code)

	return sdl.CreateGPUShader(
		device,
		sdl.GPUShaderCreateInfo {
			code = transmute([^]u8)(code),
			code_size = codeSize,
			entrypoint = entrypoint,
			format = format,
			stage = stage,
			num_samplers = samplerCount,
			num_uniform_buffers = uniformBufferCount,
			num_storage_buffers = storageBufferCount,
			num_storage_textures = storageTextureCount,
		},
	)


}

load_into_gpu_buffer :: proc(gpuBuffer: ^sdl.GPUBuffer, data: rawptr, size: uint) {

	assert(data != nil && size > 0)
	transferBuffer := sdl.CreateGPUTransferBuffer(
		device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(size)},
	)

	infoPtr := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
	sdl.memcpy(infoPtr, data, size)
	sdl.UnmapGPUTransferBuffer(device, transferBuffer)


	uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
	copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)
	sdl.UploadToGPUBuffer(
		copyPass,
		sdl.GPUTransferBufferLocation{offset = 0, transfer_buffer = transferBuffer},
		sdl.GPUBufferRegion{buffer = gpuBuffer, offset = 0, size = u32(size)},
		true,
	)
	sdl.EndGPUCopyPass(copyPass)
	sdl_panic_if(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) == false)

}
