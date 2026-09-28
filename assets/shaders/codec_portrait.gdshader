shader_type canvas_item;

// Retrato das chamadas: a imagem vira monocromatica na cor do
// personagem, com linhas de varredura, chuvisco, um leve
// tremor horizontal e uma faixa clara que rola de cima para
// baixo, como um monitor de transmissao.

uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.3, 1.0);

// 1.0 para quem esta falando; menor para quem esta ouvindo.
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

// Quanto da cor original sobrevive ao tingimento.
uniform float color_keep : hint_range(0.0, 1.0) = 0.15;

uniform float scanline_strength = 0.35;
uniform float noise_amount = 0.07;
uniform float jitter = 0.003;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Tremor: cada faixa horizontal desloca um pouco, trocando
	// de posicao algumas vezes por segundo.
	float band = floor(uv.y * 90.0);
	uv.x += (hash(vec2(band, floor(TIME * 12.0))) - 0.5) * jitter;

	vec4 source = texture(TEXTURE, uv);
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint.rgb * pow(luma, 0.8) * 1.7;
	vec3 color = mix(tinted, source.rgb, color_keep);

	float scan = mod(floor(FRAGCOORD.y), 3.0) < 1.0 ? 1.0 - scanline_strength : 1.0;
	float grain = (hash(uv * 512.0 + fract(TIME) * 37.0) - 0.5) * noise_amount;
	float roll = exp(-pow((fract(UV.y - TIME * 0.12) - 0.5) * 14.0, 2.0)) * 0.08;

	color = (color * scan + grain + tint.rgb * roll) * brightness;
	COLOR = vec4(color, source.a);
}
