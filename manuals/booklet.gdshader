shader_type canvas_item;
render_mode unshaded;

uniform sampler2D previous_spread : filter_linear, repeat_disable;
uniform float turn_progress = 1.0;
uniform bool turn_forward = true;
uniform bool bound_spread = false;

vec2 page_uv(float x, float y) {
	return vec2(turn_forward ? x : 1.0 - x, y);
}

void fragment() {
	vec4 page = texture(TEXTURE, UV);
	if (turn_progress < 1.0) {
		float t = turn_progress;
		float x = turn_forward ? UV.x : 1.0 - UV.x;
		float width = 0.5 * abs(cos(PI * t));
		float distance_from_spine = abs(x - 0.5);
		bool turning_side = t < 0.5 ? x >= 0.5 : x < 0.5;
		bool under_sheet = x < 0.5 || (t < 0.5 && turning_side && distance_from_spine < width);
		page = under_sheet ? texture(previous_spread, UV) : page;

		if (turning_side && width > 0.001 && distance_from_spine < width) {
			float across = distance_from_spine / width;
			float source_x = 0.5 + (t < 0.5 ? 0.5 : -0.5) * across;
			float bend = 1.0 - 0.09 * sin(PI * t) * across;
			float source_y = (UV.y - 0.5) / bend + 0.5;
			vec4 sheet = t < 0.5 ? texture(previous_spread, page_uv(source_x, source_y)) :
				texture(TEXTURE, page_uv(source_x, source_y));
			if (source_y >= 0.0 && source_y <= 1.0 && sheet.a > 0.0) {
				sheet.rgb *= 1.0 - 0.26 * sin(PI * t) * (0.35 + 0.65 * across);
				page = sheet;
			}
		}
	}
	if (bound_spread && turn_progress >= 1.0) {
		float distance_from_fold = abs(UV.x - 0.5);
		float fold = 1.0 - smoothstep(0.0, 0.036, distance_from_fold);
		float crease = 1.0 - smoothstep(0.0, 0.003, distance_from_fold);
		page.rgb *= 1.0 - fold * 0.18 - crease * 0.13;
	}
	COLOR = page;
}
