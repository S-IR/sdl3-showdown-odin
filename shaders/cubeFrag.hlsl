
cbuffer UBO : register(b0, space3)
{
  float NearPlane;
  float FarPlane;
};
cbuffer LightUBO : register(b1, space3)
{
  float4x4 LightPos;
  float3 LightColor;
};

struct FSInput
{
  float4 Color : TEXCOORD0;
  float4 Position : TEXCOORD1;
  float4 NORMAL : TEXCOORD2;
};

struct FSOutput
{
  float4 Color : SV_Target0;
  float Depth : SV_Depth;
};

float LinearizeDepth(float depth, float near, float far)
{
  float z = depth * 2.0 - 1.0;
  return ((2.0 * near * far) / (far + near - z * (far - near))) / far;
}
#define ambientStrength 0.1
FSOutput main(FSInput input)
{
  FSOutput result;

  float3 calculatedLightColor = float3(LightColor);
  calculatedLightColor *= ambientStrength;

  result.Color = input.Color * float4(calculatedLightColor, 1);
  result.Depth = LinearizeDepth(input.Position.z, NearPlane, FarPlane);
  return result;
}