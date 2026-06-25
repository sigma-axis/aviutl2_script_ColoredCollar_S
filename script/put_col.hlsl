Texture2D src : register(t0);
Texture2D map : register(t1);
cbuffer constant0 : register(b0) {
	float4 color[2];
	float2 size_f, ofs_src_f, ofs_map_f, blur;
	float alpha_back, alpha_fore, col_blur;
};
static const uint2 size = uint2(size_f);
static const int2
	ofs_src = int2(ofs_src_f),
	ofs_map = int2(ofs_map_f);

float4 put_col(float4 pos : SV_Position) : SV_Target
{
	const int2 pt0 = int2(pos.xy) - ofs_map;
	const float4 c_fore = src.Load(int3(int2(pos.xy) - ofs_src, 0));
	const float d_len = map[pt0].a;
	const float a = saturate((blur.x - d_len) * blur.y);
	const float4 c_fill = lerp(color[0], color[1], saturate(d_len / blur.x));

	const float r = col_blur > 0 && a > 0 && c_fill.a < 1 ?
			col_blur * sqrt(d_len) + 2 : 1,
		wt_rate = -3 / (r * r);
	const int R = ceil(r - 1);
	float4 c_back = 0;
	for (int yi = -R; yi <= R; yi++) {
		for (int xi = -R; xi <= R; xi++) {
			const uint2 pt = pt0 + uint2(xi, yi);
			const float wt = any(pt >= size) ? 0 :
				exp(wt_rate * (xi * xi + yi * yi));
			c_back += wt * float4(map.Load(int3(pt, 0)).rgb, 1);
		}
	}
	c_back.rgb /= c_back.a;
	c_back.rgb = lerp(c_back.rgb, c_fill.rgb, c_fill.a);
	c_back.a = max(a - c_fore.a, 0); c_back.rgb *= c_back.a;

	return alpha_fore * c_fore + alpha_back * c_back;
}
