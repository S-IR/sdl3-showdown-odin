cbuffer UBO : register(b0, space1)
{
  matrix model;
  matrix view;
  matrix proj;
};

struct VSInput
{
  float3 inPosition : POSITION;
  float4 inColor : COLOR;
  uint instanceID : SV_InstanceID;
};

struct VSOutput
{
  float4 outColor : TEXCOORD0;
  float4 Position : SV_Position;
};

VSOutput main(VSInput input)
{
  VSOutput output;
  output.outColor = input.inColor;

  // Transform the vertex position using the instance-specific model matrix
  float4 worldPos = mul(float4(input.inPosition, 1.0), model);
  float4 viewPos = mul(worldPos, view);
  float4 clipPos = mul(viewPos, proj);

  output.Position = clipPos;
  return output;
}