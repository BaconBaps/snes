shader_type canvas_item;
render_mode unshaded;

uniform bool rgb565 = true;

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
	float scanline = mod(floor(UV.y * 246.0), 4.0) == 0.0 ? 0.81 : 1.0;
	COLOR = vec4(rgb * scanline, 1.0);
}
