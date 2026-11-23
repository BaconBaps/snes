shader_type canvas_item;
render_mode unshaded;

uniform vec2 glass_size = vec2(480.0, 360.0);
uniform float brightness = 1.0;
uniform bool switching_input = false;

float noise_at(vec2 point) {
	vec3 hash = fract(vec3(point.xyx) * 0.1031);
	hash += dot(hash, hash.yzx + 33.33);
	return fract((hash.x + hash.y) * hash.z);
}

void fragment() {
	vec2 pixel = UV * glass_size;
	float frame = floor(TIME * 24.0);
	vec2 grain_cell = floor(pixel / vec2(1.5, 1.25));
	float grain = noise_at(grain_cell + vec2(frame * 13.0, frame * 29.0));
	float soft_grain = noise_at(floor(grain_cell / 2.0) + vec2(frame * 7.0, frame * 11.0));
	float row = noise_at(vec2(floor(pixel.y), frame));
	float level = 0.09 + grain * 0.24 + soft_grain * 0.085 + row * 0.025;
	if (switching_input) {
		level += 0.055;
	}
	vec2 edge = UV * 2.0 - 1.0;
	level *= (1.0 - 0.18 * dot(edge, edge)) * brightness;
	vec2 corner = abs((UV - 0.5) * glass_size) - (glass_size * 0.5 - vec2(17.0));
	float distance_to_glass = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - 16.0;
	float aperture = 1.0 - smoothstep(-4.0, 0.0, distance_to_glass);
	COLOR = vec4(level * vec3(0.91, 0.95, 1.0), aperture);
}
