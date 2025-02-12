package main
import "core:fmt"
import "vendor:cgltf"

gltf_load :: proc(path: cstring) -> ^cgltf.data {

	data, result := cgltf.parse_file({}, path)
	if result != .success {
		panic(fmt.tprintf("cfltf did not import the file properly, got: %v", result))
	}


	result = cgltf.load_buffers({}, data, path)
	if result != .success {
		panic(fmt.tprintf("cfltf did not load buffers properly, got: %v", result))
	}

    mesh := data.meshes[0]
    primitive := mesh.primitives[0]
    

	return data
}
