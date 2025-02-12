
cbuffer CameraUBO : register(b0, space3)
{
  float3 ViewPos;
};

cbuffer LightInfoUBO : register(b1, space3)
{
  uint AmountOfLights;
};

struct LightData
{
  float3 position;
  float4 color;
};
StructuredBuffer<LightData> LightsSBO : register(t0, space2);

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
#define ambientStrength 0.1
#define specularStrength .5

FSOutput main(FSInput input)
{
  
  FSOutput output;


  float3 ambient = ambientStrength * float3(1.0, 1.0, 1.0); // Assuming white ambient light
  float3 result = ambient;


  for (int i =  0 ; i < AmountOfLights ; i++){
    LightData light = LightsSBO[i];
    float3 lightColor3 = light.color.xyz;


    float3 norm = normalize(input.normal);
    float3 lightDir = normalize(light.position - input.worldPosition);

    float diff = max(dot(norm, lightDir), 0.0);
    float3 diffuse = diff * lightColor3 ;

    float3 viewDir = normalize(ViewPos- input.worldPosition.xyz);
    float3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir) , 0.0),32);
    float3 specular = specularStrength *  spec * lightColor3;

    result +=diffuse + specular;

  }
  
  output.color = float4(result,1);
  // float3 LightColor3 = LightColor.xyz;
  // float3 ambient = ambientStrength * LightColor3;

  // output.Depth = LinearizeDepth(input.position.z, NearPlane, FarPlane);
  return output;
}
