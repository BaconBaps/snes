shader_type canvas_item;
render_mode unshaded;

uniform vec2 screen_origin;
uniform vec2 screen_size;

void fragment() {
	vec2 point = UV * vec2(1152.0, 607.0);
	vec2 local = point - screen_origin;
	if (all(greaterThanEqual(local, vec2(0.0))) && all(lessThan(local, screen_size))) {
		COLOR.a = 0.0;
	}
}
