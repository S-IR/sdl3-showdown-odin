dxc vert.hlsl -T vs_6_0 -E main -D VERTEX_SHADER -spirv -Fo  resources/shader-binaries/shader.vert.spv
dxc frag.hlsl -T ps_6_0 -E main -D FRAGMENT_SHADER -spirv -Fo resources/shader-binaries/shader.frag.spv
