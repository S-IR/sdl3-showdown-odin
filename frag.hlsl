
cbuffer UBO : register(b0, space3)
{
  float NearPlane;
  float FarPlane;
};
cbuffer LightUBO : register(b1, space3)
{
  float3 LightPos;
  float3 LightColor;
};

struct Output
{
  float4 Color : SV_Target0;
  float Depth : SV_Depth;
};

float LinearizeDepth(float depth, float near, float far)
{
  float z = depth * 2.0 - 1.0;
  return ((2.0 * near * far) / (far + near - z * (far - near))) / far;
}

Output main(float4 Color : TEXCOORD0, float4 Position : SV_Position)
{
  Output result;

  result.Color = Color * float4(LightColor, 1);
  result.Depth = LinearizeDepth(Position.z, NearPlane, FarPlane);
  return result;
}