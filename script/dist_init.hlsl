Texture2D src : register(t0);
cbuffer constant0 : register(b0) {
	float2 offset;
	float thresh;
};

float4 dist_init(float4 pos : SV_Position) : SV_Target
{
	return src.Load(int3(floor(pos.xy - offset), 0)).a < thresh ?
		enc(p_none) : enc(uint2(pos.xy));
}
