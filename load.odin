package main
import "core:fmt"
import "core:strings"
import s "vendor:sdl3"
load_shader :: proc(
	device: ^s.GPUDevice,
	shaderPath: string,
	samplerCount, uniformBufferCount, storageBufferCount, storageTextureCount: u32,
) -> ^s.GPUShader {
	stage: s.GPUShaderStage
	if strings.contains(shaderPath, ".vert") {
		stage = .VERTEX
	} else if strings.contains(shaderPath, ".frag") {
		stage = .FRAGMENT
	} else {
		panic(
			fmt.tprintf("Shader suffix is neither .vert or .frag, shader path is %s", shaderPath),
		)
	}

	format := s.GetGPUShaderFormats(device)
	entrypoint: cstring
	if format == {.SPIRV} || format == {.DXIL} {
		entrypoint = "main"
	} else {
		panic("unsupported backend shader format")
	}

	codeSize: uint
	code := s.LoadFile(strings.clone_to_cstring(shaderPath, context.temp_allocator), &codeSize)
	sdl_panic_if(code == nil)
	defer s.free(code)

	return s.CreateGPUShader(
		device,
		s.GPUShaderCreateInfo {
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
