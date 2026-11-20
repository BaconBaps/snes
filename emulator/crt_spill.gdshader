shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec3 light_color = vec3(0.0);

void fragment() {
	vec2 point = UV * vec2(793.0, 607.0);
	vec2 edge = max(abs(point - vec2(393.0, 221.0)) - vec2(240.0, 180.0), vec2(0.0));
	float bezel = 1.0 - smoothstep(1.0, 109.0, length(edge));
	float floor_light = 1.0 - smoothstep(0.0, 1.0, length((point - vec2(411.0, 482.0)) / vec2(295.0, 125.0)));
	float falloff = bezel * 0.24 + floor_light * 0.39;
	COLOR = vec4(light_color, falloff);
}
