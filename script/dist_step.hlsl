Texture2D prev : register(t0);
cbuffer constant0 : register(b0) {
	float2 size_f;
	float step_len_f;
};
static const uint2 size = uint2(size_f);
static const int step_len = int(step_len_f);

float4 dist_step(float4 pos : SV_Position) : SV_Target
{
	const uint2 p0 = int2(pos.xy);

	uint2 p_min = p_none;
	int len_sq_min = dot(p_none, p_none);
	[unroll] for (int j = -1; j <= 1; j++) {
		[unroll] for (int i = -1; i <= 1; i++) {
			const uint2 p1 = p0 + int2(i, j) * step_len;
			if (any(p1 >= size)) continue;

			const uint2 p = dec(prev[p1]);
			if (!valid(p)) continue;

			const int2 dp = p - p0;
			const int len_sq = dot(dp, dp);
			if (len_sq >= len_sq_min) continue;

			p_min = p;
			len_sq_min = len_sq;
		}
	}

	return enc(p_min);
}
