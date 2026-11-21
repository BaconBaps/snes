shader_type canvas_item;
render_mode unshaded;

uniform bool rgb565 = true;
uniform bool scanlines = false;
uniform int preset = 1;
uniform vec2 glass_size = vec2(480.0, 360.0);

void fragment() {
	// Snes9x delivers a little-endian 16-bit pixel in the R and G bytes.
	ivec2 packed_bytes = ivec2(round(texture(TEXTURE, UV).rg * 255.0));
	int pixel = packed_bytes.x | (packed_bytes.y << 8);
	int green_bits = rgb565 ? 6 : 5;
	int green_mask = (1 << green_bits) - 1;
	vec3 rgb = vec3(
		float((pixel >> (green_bits + 5)) & 31) / 31.0,
		float((pixel >> 5) & green_mask) / float(green_mask),
		float(pixel & 31) / 31.0
	);
	if (preset == 1) {
		vec2 edge = UV * 2.0 - 1.0;
		rgb *= (1.0 - 0.16 * dot(edge, edge)) * vec3(1.0, 0.97, 0.92);
	} else if (preset == 2) {
		// Overlap the phosphor stripes and keep their channel contrast subtle.
		float phase = (UV.x * glass_size.x - 0.5) * (TAU / 3.0);
		vec3 channels = phase - vec3(0.0, TAU / 3.0, TAU * 2.0 / 3.0);
		rgb *= 0.95 + 0.05 * cos(channels);
	}
	float scanline = scanlines && mod(floor(UV.y * 360.0), 4.0) == 0.0 ? 0.81 : 1.0;
	// Round and feather the aperture in room pixels.
	float radius = 16.0;
	vec2 corner = abs((UV - 0.5) * glass_size) - (glass_size * 0.5 - vec2(radius + 1.0));
	float distance_to_glass = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
	float aperture = 1.0 - smoothstep(-4.0, 0.0, distance_to_glass);
	COLOR = vec4(rgb * scanline, aperture);
}
