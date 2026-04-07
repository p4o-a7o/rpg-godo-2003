// Thanks to https://www.youtube.com/@clecioespindolagamedev.

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 screen_size = vec2(320, 240);

uniform float progress : hint_range(0,1) = 0;
uniform float pixel_size_diamante = 15.0;

uniform int type : hint_range(0,7) = 0;
uniform bool reversed = false;

uniform float max_pixel_size : hint_range(2.0, 100.0) = 30.55;

// The previous background, transparent if there was none.
uniform sampler2D previous_background : source_color, hint_default_transparent;
// The next background, transparent if there is none.
uniform sampler2D next_background : source_color, hint_default_black;
// The texture used to determine how far along the progress has to be for bending in the new background.
uniform sampler2D wipe_texture : source_color;
// The size of the trailing smear of the transition.
uniform float feather : hint_range(0.0, 1.0, 0.0001) = 0.1;

void fragment() {
	//Tipo Diamante Pixel
	if (type == 0) {
		float xFraction = fract(FRAGCOORD.x / pixel_size_diamante);
		float yFraction = fract(FRAGCOORD.y / pixel_size_diamante);

		float xDistance = abs(xFraction - 0.5);
		float yDistance = abs(yFraction - 0.5);

		if (reversed) {
			if (xDistance + yDistance + UV.x + UV.y <= progress * 4.0) {
				discard;
			}
		} else {
			if (xDistance + yDistance + UV.x + UV.y > progress * 4.0) {
				discard;
			}
		}
	}
	//Tipo Circulo no Centro
	else if (type == 1) {
		float ratio = screen_size.x / screen_size.y;

		if (!reversed) {
			if (distance(vec2(0.5), vec2(mix(vec2(0.5).x, UV.x, ratio), UV.y)) <= 1.02 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		} else {
			if (distance(vec2(0.5), vec2(mix(vec2(0.5).x, UV.x, ratio), UV.y)) > 1.02 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		}
	}
	//Tipo Corte Vertical
	else if (type == 2) {
		if (reversed) {
			if (distance(vec2(0.5, 0.5), vec2(UV.x, UV.x)) >= 0.71 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		} else {
			if (distance(vec2(0.5, 0.5), vec2(UV.x, UV.x)) < 0.71 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		}
	}

	//Tipo Corte Horizontal
	else if (type == 3) {
		if (reversed) {
			if (distance(vec2(0.5, 0.5), vec2(UV.y, UV.y)) >= 0.71 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		} else {
			if (distance(vec2(0.5, 0.5), vec2(UV.y, UV.y)) < 0.71 * (1.0 - progress)) {
				COLOR.a = 0.0;
			}
		}
	}

	//Tipo Fade
	else if (type == 4) {
		if (reversed) {
			COLOR.a = 1.0 - progress;
		} else {
			COLOR.a = progress;
		}
	}

	// Pixelize
	else if (type == 5) {
		const vec2 pixelate_center = vec2(0.5, 0.5);
		const float maximum_block_size = 8.0;
		const vec2 block_offset = vec2(0.5, 0.5);

		// Get screen texture coordinates
		vec2 uv = SCREEN_UV;

		// Block size, always a multiple of 2 (Pixel Aligned)
		float anim_block_size = floor(pow(2.0, maximum_block_size * progress));

		// Calculate screen resolution (inverse of pixel size)
		vec2 screen_resolution = 1.0 / SCREEN_PIXEL_SIZE;

		// UV Calculations
		vec2 final_uv = uv;                      // Use screen UVs
		final_uv -= pixelate_center;             // Offset by the pixelation center
		final_uv *= screen_resolution;           // Convert to 0..Resolution UVs for pixelation
		final_uv /= anim_block_size;             // Divide by current block size
		final_uv = floor(final_uv) + block_offset; // Use floor() to get aligned pixels
		final_uv *= anim_block_size;             // Multiply by current block size
		final_uv /= screen_resolution;           // Convert back to 0..1 UVs for texture sampling
		final_uv += pixelate_center;             // Revert the offset by the pixelation center

		// Sample the screen texture with our pixelated UVs
		vec4 pixelated = texture(SCREEN_TEXTURE, final_uv);

		// Output the pixelated result
		COLOR = pixelated;
	}

	// Push up
	else if (type == 6) {
		vec2 final_offset = vec2(0,-1);
		vec2 uv = UV + final_offset * progress*vec2(-1, -1);

		if (uv.x < 1.0 && uv.x > 0.0 && uv.y < 1.0 && uv.y > 0.0){
			COLOR = texture(previous_background, uv, 1);
		} else {
			COLOR = texture(next_background, uv-final_offset*vec2(-1,-1));
		}
	}

	// Swipe
	else if (type == 7) {
		vec2 frag_coord = UV;

		// get the blend factor between the previous and next background.
		float alpha = (texture(wipe_texture, frag_coord).r) - progress;
		float blend_factor = 1. - smoothstep(0., feather, alpha + (feather * (1. -progress)));

		vec4 old_frag = texture(previous_background, UV);
		vec4 new_frag = texture(next_background, UV);

		COLOR = mix(old_frag, new_frag, blend_factor);
	}
}
