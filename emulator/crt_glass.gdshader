shader_type canvas_item;
render_mode unshaded;

uniform vec2 glass_size = vec2(480.0, 360.0);
uniform float sheen_strength = 1.0;

void fragment() {
	vec2 corner = abs((UV - 0.5) * glass_size) - (glass_size * 0.5 - vec2(17.0));
	float glass_edge = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - 16.0;
	float aperture = 1.0 - smoothstep(-4.0, 0.0, glass_edge);

	// A soft reflection across the upper glass, bowed with the face of the tube.
	vec2 from_light = UV - vec2(0.24, -0.045);
	float light_pool = exp(-dot(from_light * vec2(2.4, 4.8), from_light * vec2(2.4, 4.8)));
	float bow = UV.y - 0.044 - 0.095 * pow(abs(UV.x - 0.5), 2.0);
	float rim = (1.0 - smoothstep(0.0, 0.03, abs(bow))) * (1.0 - smoothstep(0.1, 0.48, abs(UV.x - 0.41)));
	float opacity = aperture * (light_pool * 0.075 + rim * 0.046) * sheen_strength;
	COLOR = vec4(0.66, 0.69, 0.83, opacity);
}
