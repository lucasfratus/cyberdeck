shader_type canvas_item;

// Materializacao de um inimigo: com amount em 1 o sprite e uma
// silhueta vermelha picotada, com faixas deslocadas e cores
// separadas. Em 0 aparece normal. Usado na entrada do chefe.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 silhouette_color : source_color = vec4(1.0, 0.2, 0.3, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 18.0);
	float band = floor(UV.y * 24.0);
	vec2 uv = UV;

	// Faixas horizontais que pulam de lugar.
	if (hash(vec2(band, frame)) < amount * 0.7) {
		uv.x += (hash(vec2(frame, band)) - 0.5) * 0.35 * amount;
	}

	float split = 0.03 * amount;
	vec4 base = texture(TEXTURE, uv);
	float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	vec4 color = vec4(r, base.g, b, base.a);

	// Silhueta: a cor cede lugar ao vermelho conforme amount.
	color.rgb = mix(color.rgb, silhouette_color.rgb, smoothstep(0.35, 0.9, amount));

	// Blocos que ainda nao se formaram ficam transparentes.
	vec2 block = floor(UV * 32.0);
	if (hash(block + frame * 0.01) < amount * 0.85) {
		color.a = 0.0;
	}

	COLOR = color * tint;
}
