Texture2D prev : register(t0);
Texture2D src : register(t1);
cbuffer constant0 : register(b0) {
	float2 size_f, offset_f;
};
static const uint2 size = uint2(size_f),
	offset = uint2(offset_f);

float4 dist_fin(float4 pos : SV_Position) : SV_Target
{
	const uint2 p0 = int2(pos.xy);

	uint2 p_min = p_none;
	int len_sq_min = dot(p_none, p_none);
	[unroll] for (int yi = -1; yi <= 1; yi++) {
		[unroll] for (int xi = -1; xi <= 1; xi++) {
			const uint2 p1 = p0 + int2(xi, yi);
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

	p_min -= offset;
	float4 col = 0;
	[unroll] for (yi = -1; yi <= 1; yi++) {
		[unroll] for (int xi = -1; xi <= 1; xi++) {
			const float wt = (2 - abs(xi)) * (2 - abs(yi));
			col += wt * src.Load(int3(p_min + uint2(xi, yi), 0));
		}
	}
	return float4(col.a > 0 ? col.rgb / col.a : 0, sqrt(len_sq_min));
}
