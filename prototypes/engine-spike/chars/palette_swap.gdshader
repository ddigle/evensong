shader_type canvas_item;
// Palette swap for one sprite sheet (res://chars/). A texel whose RGB equals src_colors[i]
// (within `tolerance`) is drawn with dst_colors[i]; alpha and modulate are kept.
// The swap only applies to frame-local rows band.x..band.y, because our AI frames are not
// indexed and reuse the tunic beige in the face and hair (notes/chars.md).
// The CPU reference is Compose.apply_palette() in compose.gd: keep the two in step.

const int MAX_SWAP = 16;

uniform int swap_count = 0;
uniform vec4 src_colors[16];
uniform vec4 dst_colors[16];
uniform float tolerance = 0.002;
// Sheet layout, to find the row inside the current frame: (hframes, vframes) and frame height.
uniform vec2 frame_grid = vec2(1.0, 1.0);
uniform float frame_height = 32.0;
uniform vec2 band = vec2(0.0, 4096.0);

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float local_y = floor(fract(UV.y * frame_grid.y) * frame_height);
	if (tex.a > 0.0 && local_y >= band.x && local_y <= band.y) {
		for (int i = 0; i < MAX_SWAP; i++) {
			if (i >= swap_count) {
				break;
			}
			vec3 d = abs(tex.rgb - src_colors[i].rgb);
			if (max(d.r, max(d.g, d.b)) <= tolerance) {
				tex.rgb = dst_colors[i].rgb;
				break;
			}
		}
	}
	COLOR = tex * vertex_color;
}
