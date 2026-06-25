cbuffer constant0 : register(b0) {
	float4 color;
};
float4 const_value(float4 pos : SV_Position) : SV_Target
{
	return color;
}
