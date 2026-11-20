shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D game_picture : filter_nearest, repeat_disable;
uniform bool playing = false;
uniform bool preview = false;
uniform bool rgb565 = true;
uniform bool scanlines = false;
uniform int preset = 1;
uniform bool room_lit = true;

#include "res://emulator/crt_picture.gdshaderinc"

void fragment() {
	vec3 glass = vec3(0.041, 0.049, 0.075) * (room_lit ? 1.0 : 0.32);
	if (playing) {
		vec4 picture = crt_picture(texture(game_picture, UV).rg, UV, rgb565, scanlines, preset, vec2(480.0, 360.0));
		glass = mix(glass, picture.rgb, picture.a);
	} else if (preview) {
		float skyline = 0.71 + sin(UV.x * 21.0) * 0.053 + sin(UV.x * 46.0) * 0.034;
		vec3 sky = mix(vec3(0.098, 0.15, 0.30), vec3(0.35, 0.19, 0.32), UV.y);
		float moon = 1.0 - smoothstep(0.09, 0.096, length((UV - vec2(0.74, 0.34)) * vec2(1.33, 1.0)));
		glass = mix(sky, vec3(0.93, 0.67, 0.49), moon);
		glass = mix(glass, vec3(0.12, 0.17, 0.22), smoothstep(skyline, skyline + 0.005, UV.y));
	} else {
		float reflection = 1.0 - smoothstep(0.0, 0.08, abs(UV.y + UV.x * 0.38 - 0.18));
		glass += reflection * vec3(0.022, 0.027, 0.038) * (room_lit ? 1.0 : 0.2);
	}
	ALBEDO = glass;
}
