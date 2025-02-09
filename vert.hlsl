struct VSInput
{
    float3 inPosition : POSITION;
    float4 inColor    : COLOR;
};

struct VSOutput
{
    float4 outColor : COLOR;
    float4 position : SV_POSITION;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    output.outColor = input.inColor;
    output.position = float4(input.inPosition, 1.0f);
    return output;
}