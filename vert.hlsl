struct CubeData
{
  float4x4 model;
  float4 color;
};
StructuredBuffer<CubeData> CubesBuffer : register(t0, space0);

cbuffer UBO : register(b0, space1)
{
  matrix view;
  matrix proj;
};

struct VSInput
{
  float3 inPosition : POSITION;
  uint instanceId : SV_InstanceID;
};

struct VSOutput
{
  float4 outColor : TEXCOORD0;
  float4 Position : SV_Position;
};

VSOutput main(VSInput input)
{
  VSOutput output;
  CubeData cube = CubesBuffer[input.instanceId];

  output.outColor = cube.color;

  float4 pos = float4(input.inPosition, 1.0);
  float4 worldPos = mul(cube.model, pos);
  float4 viewPos = mul(view, worldPos);
  float4 clipPos = mul(proj, viewPos);

  output.Position = clipPos;
  return output;
}