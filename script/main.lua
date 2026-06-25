--information:ColoredCollar_S ${PACKAGE_VERSION} by ${AUTHOR}
--label:装飾
--filter
--require:${LEAST_AVIUTL_VERSION}
---$track:サイズ, min = 0, max = 500, step = 0.01, scale = 0.4
local thick = 5

---$track:ぼかし, min = 0, max = 100, step = 0.01
local blur = 5

---$track:色拡散, min = 0, max = 200, step = 0.01, scale = 0.5
local col_blur = 50

---$track:αしきい値, min = 0, max = 100, step = 0.01
local threshold = 50

---$checksection:サイズ固定
local fixed_size = false

--group:色設定,false
---$color:縁色
local color = 0xffffff

---$track:色の濃さ, min = 0, max = 100, step = 0.01
local col_alpha = 30

---$color:縁色外側
local color_outer = nil

---$track:outer::色の濃さ, min = 0, max = 100, step = 0.01
local col_alpha_outer = 30

--group:透明度設定,false
---$track:透明度, min = 0, max = 100, step = 0.01
local alpha = 0

---$track:前景透明度, min = 0, max = 100, step = 0.01
local front_alpha = 0

--group:その他,false
---$track:錯視補正, min = 0, max = 100, step = 0.01
local mollify = 0

---$value:PI
local PI = {}

--[[pixelshader@const_value:
---$include "const_value.hlsl"
]]
--[[pixelshader@dist_init:
---$include "dist_header.hlsl"
---$include "dist_init.hlsl"
]]
--[[pixelshader@dist_step:
---$include "dist_header.hlsl"
---$include "dist_step.hlsl"
]]
--[[pixelshader@dist_fin:
---$include "dist_header.hlsl"
---$include "dist_fin.hlsl"
]]
--[[computeshader@convol:
---$include "convol.hlsl"
]]
--[[pixelshader@put_col:
---$include "put_col.hlsl"
]]
local obj, math, tonumber, bit_band = obj, math, tonumber, bit.band;

--#region PI / normalize parameters / further calculations.

-- take parameters.
--[==[
	PI = {
		thick:				number?,
		blur:				number?,
		col_blur:			number?,
		threshold:			number?,
		fixed_size:			boolean|number|nil,
		color:				number?,
		col_alpha:			number?,
		color_outer:		number|false|nil,
		col_alpha_outer:	number?,
		alpha:				number?,
		front_alpha:		number?,
		mollify:			number?,
	}
]==]
local function as_bool(pi_value, gui_value)
	if type(pi_value) == "boolean" then return pi_value;
	elseif type(pi_value) == "number" then return pi_value ~= 0;
	else return gui_value end
end
thick = tonumber(PI.thick) or thick;
blur = tonumber(PI.blur) or blur;
col_blur = tonumber(PI.col_blur) or col_blur;
threshold = tonumber(PI.threshold) or threshold;
fixed_size = as_bool(PI.fixed_size, fixed_size);
color = tonumber(PI.color) or color;
col_alpha = tonumber(PI.col_alpha) or col_alpha;
if PI.color_outer == false then color_outer = nil;
else color_outer = tonumber(PI.color_outer) or color_outer end
col_alpha_outer = tonumber(PI.col_alpha_outer) or col_alpha_outer;
alpha = tonumber(PI.alpha) or alpha;
front_alpha = tonumber(PI.front_alpha) or front_alpha;
mollify = tonumber(PI.mollify) or mollify;

-- normalize paramters.
thick = math.min(math.max(thick, 0), 500);
blur = math.min(math.max(blur / 100, 0), 1);
col_blur = math.min(math.max(col_blur / 100, 0), 1);
threshold = math.min(math.max(threshold / 100, 2 ^ -24), 1 - 2 ^ -13);
fixed_size = fixed_size or obj.getinfo("filter");
color = math.floor(color) % 2 ^ 24;
col_alpha = math.min(math.max(col_alpha / 100, 0), 1);
if color_outer then
	color_outer = math.floor(color_outer) % 2 ^ 24;
	col_alpha_outer = math.min(math.max(col_alpha_outer / 100, 0), 1);
else color_outer, col_alpha_outer = color, col_alpha end
alpha = math.min(math.max(1 - alpha / 100, 0), 1);
front_alpha = math.min(math.max(1 - front_alpha / 100, 0), 1);
mollify = math.min(math.max(mollify / 100, 0), 1);

-- further calculations.
local mollify_size = mollify * thick;
local thick_i, mollify_size_i = fixed_size and 0 or math.ceil(thick), math.ceil(mollify_size);
local offset_i = thick_i + mollify_size_i;
local col1_r, col1_g, col1_b =
	bit_band(color, 0xff0000) / 0xff0000,
	bit_band(color, 0x00ff00) / 0x00ff00,
	bit_band(color, 0x0000ff) / 0x0000ff;
col1_r, col1_g, col1_b = col_alpha * col1_r, col_alpha * col1_g, col_alpha * col1_b;
local col2_r, col2_g, col2_b =
	bit_band(color_outer, 0xff0000) / 0xff0000,
	bit_band(color_outer, 0x00ff00) / 0x00ff00,
	bit_band(color_outer, 0x0000ff) / 0x0000ff;
col2_r, col2_g, col2_b = col_alpha_outer * col2_r, col_alpha_outer * col2_g, col_alpha_outer * col2_b;
if col_alpha >= 1 and col_alpha_outer >= 1 then col_blur = 0 end

--#endregion PI / normalize parameters / further calculations.

-- early return.
if thick <= 0 or alpha <= 0 then
	if front_alpha < 1 then
		if front_alpha > 0 then
			obj.pixelshader("const_value", "object", nil, {
				0, 0, 0, front_alpha
			}, "mask");
		else obj.clearbuffer("object") end
	end
	if thick > 0 then
		obj.effect("領域拡張", "上", thick_i, "下", thick_i, "左", thick_i, "右", thick_i);
	end
	return;
end

-- create reposition map.
local w, h = obj.w, obj.h;
local W, H = w + 2 * offset_i, h + 2 * offset_i;
local cache_tmp, cache_map = "cache:ColoredCollar_S/tmp1", "cache:ColoredCollar_S/tmp2";
obj.clearbuffer(cache_tmp, W, H); obj.clearbuffer(cache_map, W, H);
obj.pixelshader("dist_init", cache_map, "object", { offset_i, offset_i, threshold });
for i = math.ceil(math.max(math.log(math.max(W, H) / 2, 2), -1)), 0, -1 do
	obj.pixelshader("dist_step", cache_tmp, cache_map, { W, H; 2 ^ i; });
	cache_tmp, cache_map = cache_map, cache_tmp;
end
obj.pixelshader("dist_fin", cache_tmp, { cache_map, "object" }, { W, H; offset_i, offset_i; });
cache_tmp, cache_map = cache_map, cache_tmp;

-- mollify the distance part.
if mollify > 0 then
	local dim1, dim2, span_i, span_f, inv_span = H, W,
		mollify_size_i - 1, 2 ^ 7 * (mollify_size - mollify_size_i + 1),
		2 ^ -7 / mollify_size;
	if dim1 ~= dim2 then obj.clearbuffer(cache_tmp, dim1, dim2) end
	for _ = 1, 4 do
		obj.computeshader("convol", cache_tmp, cache_map, {
			dim1, dim2; span_i, span_f, inv_span;
		}, 1, math.ceil(dim1 / 64), 1);
		cache_tmp, cache_map = cache_map, cache_tmp;
		dim1, dim2 = dim2, dim1;
	end
	obj.clearbuffer(cache_tmp, W - 2 * mollify_size_i, H - 2 * mollify_size_i);
end

-- put color to the destination.
obj.pixelshader("put_col", cache_tmp, { "object", cache_map }, {
	col1_r, col1_g, col1_b, col_alpha;
	col2_r, col2_g, col2_b, col_alpha_outer;
	W, H; thick_i, thick_i; -mollify_size_i, -mollify_size_i;
	thick, 1 / math.max(thick * blur, blur > 0 and 1 or 2 ^ -8);
	alpha, front_alpha; col_blur;
});
obj.copybuffer("object", cache_tmp);
