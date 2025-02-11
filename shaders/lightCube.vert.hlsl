struct CubeData
{
  float3 position;
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
float4x4 TranslationMatrix(float3 translation)
{
  return float4x4(
      1, 0, 0, translation.x,
      0, 1, 0, translation.y,
      0, 0, 1, translation.z,
      0, 0, 0, 1);
}
VSOutput main(VSInput input)
{
  VSOutput output;
  CubeData cube = CubesBuffer[input.instanceId];

  output.outColor = cube.color;

  float4 pos = float4(input.inPosition, 1.0);

  float4x4 model = TranslationMatrix(cube.position);

  float4 worldPos = mul(model, pos);
  float4 viewPos = mul(view, worldPos);
  float4 clipPos = mul(proj, viewPos);

  output.Position = clipPos;
  return output;
}