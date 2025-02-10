struct CubeData
{
  float3 pos;
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

float4x4 CreateTranslationMatrix(float3 position)
{
  return float4x4(
      1, 0, 0, position.x,
      0, 1, 0, position.y,
      0, 0, 1, position.z,
      0, 0, 0, 1);
}
VSOutput main(VSInput input)
{
  VSOutput output;
  CubeData cube = CubesBuffer[input.instanceId];

  output.outColor = cube.color;

  float4 pos = float4(input.inPosition, 1.0);
  float4x4 model = CreateTranslationMatrix(cube.pos);
  float4 worldPos = mul(model, pos);    // Changed order
  float4 viewPos = mul(view, worldPos); // Changed order
  float4 clipPos = mul(proj, viewPos);  // Changed order

  output.Position = clipPos;
  return output;
}