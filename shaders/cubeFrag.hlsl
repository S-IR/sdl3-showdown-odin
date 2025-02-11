
// cbuffer UBO : register(b0, space3)
// {
//   float NearPlane;
//   float FarPlane;
// };
cbuffer LightUBO : register(b1, space3)
{
  float3 LightPosition;
  float4 LightColor;
};

struct FSInput
{
  float4 color : TEXCOORD0;
  float3 normal : TEXCOORD1;
  float3 worldPosition : TEXCOORD2;
  float4 position : TEXCOORD3;
};

struct FSOutput
{
  float4 color : SV_Target0;
  float Depth : SV_Depth;
};

float LinearizeDepth(float depth, float near, float far)
{
  float z = depth * 2.0 - 1.0;
  return ((2.0 * near * far) / (far + near - z * (far - near))) / far;
}
#define ambientStrength 0.4

FSOutput main(FSInput input)
{
  FSOutput output;

  float3 ambient = ambientStrength * LightColor.xyz;

  float3 norm = normalize(input.normal);
  float3 lightDir = normalize(LightPosition - input.worldPosition);

  float diff = max(dot(norm, lightDir), 0.0);
  float3 diffuse = diff * LightColor.xyz;

  float3 result = (ambient + diffuse) * input.color.xyz;

  // output.Depth = LinearizeDepth(input.position.z, NearPlane, FarPlane);
  output.color = float4(result, 1);
  return output;
}
