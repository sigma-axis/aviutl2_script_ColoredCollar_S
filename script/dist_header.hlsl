half2 enc(uint p) { return half2(p >> 8, p & 0xff); }
half4 enc(uint2 p) { return half4(enc(p.x), enc(p.y)); }
uint dec(half2 u) { return uint(dot(float2(256, 1), u)); }
uint2 dec(half4 u) { return uint2(dec(u.xy), dec(u.zw)); }
bool valid(uint2 p) { return all(p < (1 << 14)); }
static const uint2 p_none = (1 << 15) - 1;
