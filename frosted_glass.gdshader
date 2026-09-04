shader_type canvas_item;

// Frosted-glass backdrop: blurs whatever is behind the rect and tints it dark.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 8.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.05, 0.05, 0.10, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur;
	vec4 acc = vec4(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			acc += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * ps);
		}
	}
	acc /= 25.0;
	COLOR = vec4(mix(acc.rgb, tint.rgb, tint_amount), 1.0);
}
