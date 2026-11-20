shader_type canvas_item;
render_mode unshaded;

uniform bool rgb565 = true;
uniform bool scanlines = false;
uniform int preset = 1;
uniform vec2 glass_size = vec2(480.0, 360.0);

#include "res://emulator/crt_picture.gdshaderinc"

void fragment() {
	COLOR = crt_picture(texture(TEXTURE, UV).rg, UV, rgb565, scanlines, preset, glass_size);
}
