package main
import sdl "vendor:sdl3"

device: ^sdl.GPUDevice
window: ^sdl.Window

screenWidth: i32 = 1280
screenHeight: i32 = 720

nearPlane: f32 : 20.0
farPlane: f32 : 60.0
dt: f64
