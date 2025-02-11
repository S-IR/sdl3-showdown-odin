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
  float3 position : TEXCOORD0;
  float3 normal : TEXCOORD1;
  uint instanceId : SV_InstanceID;
};

struct VSOutput
{
  float4 color : TEXCOORD0;
  float3 normal : TEXCOORD1;
  float3 worldPosition : TEXCOORD2;
  float4 position : SV_Position;
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
  output.normal = input.normal;
  CubeData cube = CubesBuffer[input.instanceId];

  output.color = cube.color;

  float4 vertexPosition = float4(input.position, 1.0);

  float4x4 model = TranslationMatrix(cube.position);

  float4 worldPos = mul(model, vertexPosition);
  output.worldPosition = worldPos.xyz;

  float4 viewPos = mul(view, worldPos);
  float4 clipPos = mul(proj, viewPos);

  output.position = clipPos;
  return output;
}