package main
import "core:fmt"
import "core:math"
import "core:math/linalg"
import sdl "vendor:sdl3"
CAMERA_MOVEMENT :: enum {
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT,
}

DEFAULT_YAW :: -90.0
DEFAULT_PITCH :: 0
DEFAULT_SPEED :: .005
DEFAULT_SENSITIVITY: f32 = 0.1

FOV :: 45.0
worldUp: vec3 : {0, 1, 0}

Camera :: struct {
	pos:               vec3,
	front:             vec3,
	up:                vec3,
	right:             vec3,
	yaw:               f32,
	pitch:             f32,
	movement_speed:    f32,
	mouse_sensitivity: f32,
	fov:               f32,
}
Camera_process_keyboard_movement :: proc(c: ^Camera) {
	keys := sdl.GetKeyboardState(nil)

	movementVector: vec3 = {}
	normalizedFront := linalg.normalize(vec3{c.front.x, 0, c.front.z})
	normalizedRight := linalg.normalize(vec3{c.right.x, 0, c.right.z})

	if keys[sdl.Scancode.W] != false {
		movementVector += normalizedFront // Move forward
	}
	if keys[sdl.Scancode.S] != false {
		movementVector -= normalizedFront // Move backward
	}
	if keys[sdl.Scancode.A] != false {
		movementVector -= normalizedRight // Move left
	}
	if keys[sdl.Scancode.D] != false {
		movementVector += normalizedRight // Move right
	}

	velocity := f32(dt) * c.movement_speed

	if linalg.length(movementVector) > 0 {
		delta := linalg.normalize(movementVector) * velocity
		c.pos += vec3{delta.x, 0, delta.z}
	}

}
Camera_process_mouse_movement :: proc(c: ^Camera, received_xOffset, received_yOffset: f32) {
	xOffset := received_xOffset * c.mouse_sensitivity
	yOffset := -received_yOffset * c.mouse_sensitivity // Negative to invert mouse movement

	c.yaw += xOffset
	c.pitch += yOffset

	c.pitch = math.clamp(c.pitch, -89.0, 89.0)
	Camera_update_vectors(c)
}
Camera_frame_update :: proc(c: ^Camera, cmdBuf: ^sdl.GPUCommandBuffer) {
	view := linalg.matrix4_look_at_f32(c.pos, c.pos + c.front, c.up)

	proj := linalg.matrix4_perspective_f32(
		c.fov,
		f32(screenWidth) / f32(screenHeight),
		f32(nearPlane),
		f32(farPlane),
	)

	transforms: [2]matrix[4, 4]f32 = {view, proj}
	sdl.PushGPUVertexUniformData(cmdBuf, 0, raw_data(&transforms), size_of(transforms))
}
Camera_new :: proc(
	pos: vec3 = {0.0, 0.0, 3},
	up: vec3 = {0.0, 1.0, 0.0},
	yaw: f32 = DEFAULT_YAW,
	pitch: f32 = DEFAULT_PITCH,
	front: vec3 = {0, 0, 0},
) -> Camera {

	c := Camera {
		front             = front,
		movement_speed    = DEFAULT_SPEED,
		mouse_sensitivity = DEFAULT_SENSITIVITY,
		pos               = pos,
		yaw               = yaw,
		pitch             = pitch,
		fov               = FOV,
	}
	Camera_update_vectors(&c)
	return c
}

@(private)
Camera_update_vectors :: proc(using c: ^Camera) {
	assert(!(math.is_nan(yaw) || math.is_nan(pitch)), "Invalid camera rotation")

	// Correct front vector calculation
	front.x = math.cos(yaw * linalg.RAD_PER_DEG) * math.cos(pitch * linalg.RAD_PER_DEG)
	front.y = math.sin(pitch * linalg.RAD_PER_DEG)
	front.z = math.sin(yaw * linalg.RAD_PER_DEG) * math.cos(pitch * linalg.RAD_PER_DEG)
	front = linalg.normalize(front)


	right = linalg.normalize(linalg.cross(front, worldUp))
	up = linalg.normalize(linalg.cross(right, front))
}
