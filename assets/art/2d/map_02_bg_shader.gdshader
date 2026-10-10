shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform vec4 bg_dark_color : source_color = vec4(0.04, 0.06, 0.09, 1.0);
uniform vec4 bg_accent_color : source_color = vec4(0.11, 0.15, 0.22, 1.0);
uniform vec2 scroll_speed = vec2(0.015, 0.005);
uniform float opacity : hint_range(0.0, 1.0) = 0.48;

void fragment() {
	vec2 moving_uv = UV * 2.0 + TIME * scroll_speed;
	float noise_val = texture(noise_texture, moving_uv).r;
	vec4 mixed_color = mix(bg_dark_color, bg_accent_color, noise_val);
	COLOR = vec4(mixed_color.rgb, opacity);
}
