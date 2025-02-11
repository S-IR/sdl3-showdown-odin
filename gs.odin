package main
import sdl "vendor:sdl3"

device: ^sdl.GPUDevice
window: ^sdl.Window

screenWidth: i32 = 1920
screenHeight: i32 = 1080

nearPlane: f32 : 0.2
farPlane: f32 : 160.0
dt: f64
