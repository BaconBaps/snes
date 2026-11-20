vec4 crt_picture(vec2 packed_color, vec2 uv, bool is_rgb565, bool show_scanlines, int display_preset, vec2 aperture_size) {
	// Snes9x delivers a little-endian 16-bit pixel in the R and G bytes.
	ivec2 packed_bytes = ivec2(round(packed_color * 255.0));
	int pixel = packed_bytes.x | (packed_bytes.y << 8);
	int green_bits = is_rgb565 ? 6 : 5;
	int green_mask = (1 << green_bits) - 1;
	vec3 rgb = vec3(
		float((pixel >> (green_bits + 5)) & 31) / 31.0,
		float((pixel >> 5) & green_mask) / float(green_mask),
		float(pixel & 31) / 31.0
	);
	if (display_preset == 1) {
		vec2 edge = uv * 2.0 - 1.0;
		rgb *= (1.0 - 0.16 * dot(edge, edge)) * vec3(1.0, 0.97, 0.92);
	} else if (display_preset == 2) {
		int phosphor = int(floor(uv.x * 480.0)) % 3;
		vec3 mask = phosphor == 0 ? vec3(1.0, 0.78, 0.78) : (
			phosphor == 1 ? vec3(0.78, 1.0, 0.78) : vec3(0.78, 0.78, 1.0));
		rgb *= mask;
	}
	float scanline = show_scanlines && mod(floor(uv.y * 360.0), 4.0) == 0.0 ? 0.81 : 1.0;
	// Round and feather the aperture in room pixels.
	float radius = 16.0;
	vec2 corner = abs((uv - 0.5) * aperture_size) - (aperture_size * 0.5 - vec2(radius + 1.0));
	float distance_to_glass = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
	float aperture = 1.0 - smoothstep(-4.0, 0.0, distance_to_glass);
	return vec4(rgb * scanline, aperture);
}
