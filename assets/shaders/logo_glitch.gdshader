shader_type canvas_item;

// Logo do menu com a "invasao" da E.V.E. Faixas horizontais da
// imagem pulam de lugar e trocam pela logo invadida, com as
// cores separadas nas bordas (aberracao cromatica).
//   glitch: 0 = logo parada; 1 = defeitos no maximo.
//   invaded: 0 = logo normal por baixo; 1 = logo invadida.

uniform sampler2D alt_texture : filter_linear;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float invaded : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 16.0);
	float band = floor(UV.y * 18.0);
	bool hit = hash(vec2(band, frame)) < glitch * 0.6;

	vec2 uv = UV;
	if (hit) {
		uv.x += (hash(vec2(frame, band)) - 0.5) * 0.12 * glitch;
	}

	// Na logo normal, algumas faixas atingidas mostram a
	// invadida; na invadida, algumas mostram a normal.
	bool swap = hit && hash(vec2(band + 7.0, frame)) < 0.5;
	bool alt = invaded > 0.5 ? !swap : swap;

	// TEXTURE so existe dentro de fragment(), por isso as
	// leituras ficam aqui e nao em uma funcao auxiliar.
	vec4 color = alt ? texture(alt_texture, uv) : texture(TEXTURE, uv);

	if (glitch > 0.0) {
		float offset = 0.006 * glitch;
		vec2 right = uv + vec2(offset, 0.0);
		vec2 left = uv - vec2(offset, 0.0);
		vec4 red = alt ? texture(alt_texture, right) : texture(TEXTURE, right);
		vec4 blue = alt ? texture(alt_texture, left) : texture(TEXTURE, left);
		float edge_alpha = max(red.a, blue.a) * glitch * 0.8;
		color = vec4(red.r, color.g, blue.b, max(color.a, edge_alpha));
	}

	COLOR = color;
}
