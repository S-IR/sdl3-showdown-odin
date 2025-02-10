dxc shaders/cubeVert.hlsl -T vs_6_0 -Zi -E main -D VERTEX_SHADER -spirv -Fo  resources/shader-binaries/cube.vert.spv
dxc shaders/cubeFrag.hlsl -T ps_6_0 -Zi -E main -D FRAGMENT_SHADER -spirv -Fo resources/shader-binaries/cube.frag.spv



dxc shaders/lightCube.vert.hlsl -T vs_6_0 -Zi -E main -D FRAGMENT_SHADER -spirv -Fo resources/shader-binaries/lightCube.vert.spv

dxc shaders/lightCube.frag.hlsl -T ps_6_0 -Zi -E main -D FRAGMENT_SHADER -spirv -Fo resources/shader-binaries/lightCube.frag.spv