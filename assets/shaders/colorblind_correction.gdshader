// Correcao de cores para daltonismo (daltonizacao).
//
// Adaptado para o Godot 4 do "Colorblindness correction shader"
// de Vildravn, publicado em godotshaders.com sob licenca CC0:
// https://godotshaders.com/shader/colorblindness-correction-shader/
// O algoritmo original vem de daltonize.org.
//
// Mudancas em relacao ao original: SCREEN_TEXTURE (Godot 3)
// virou um uniform com hint_screen_texture, e o resultado e
// limitado a faixa 0..1.
//
// Como funciona: simula como a cor seria vista com o tipo de
// daltonismo escolhido, mede o que se perde nessa simulacao e
// desloca essa diferenca para canais que a pessoa distingue.
// Vermelho e verde, por exemplo, passam a diferir tambem em
// brilho e em azul.

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// 0 - Protanopia (vermelho quase ausente)
// 1 - Deuteranopia (verde quase ausente)
// 2 - Tritanopia (azul quase ausente)
uniform int mode : hint_range(0, 2) = 0;

// 0 nao muda nada; 1 aplica a correcao inteira.
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = textureLod(screen_texture, SCREEN_UV, 0.0);

	float L = (17.8824 * tex.r) + (43.5161 * tex.g) + (4.11935 * tex.b);
	float M = (3.45565 * tex.r) + (27.1554 * tex.g) + (3.86714 * tex.b);
	float S = (0.0299566 * tex.r) + (0.184309 * tex.g) + (1.46709 * tex.b);

	float l = L;
	float m = M;
	float s = S;

	if (mode == 0) {
		l = 2.02344 * M - 2.52581 * S;
	} else if (mode == 1) {
		m = 0.494207 * L + 1.24827 * S;
	} else {
		s = -0.395913 * L + 0.801109 * M;
	}

	vec3 error;
	error.r = (0.0809444479 * l) + (-0.130504409 * m) + (0.116721066 * s);
	error.g = (-0.0102485335 * l) + (0.0540193266 * m) + (-0.113614708 * s);
	error.b = (-0.000365296938 * l) + (-0.00412161469 * m) + (0.693511405 * s);

	vec3 diff = tex.rgb - error;
	vec3 correction = vec3(
		0.0,
		(diff.r * 0.7) + (diff.g * 1.0),
		(diff.r * 0.7) + (diff.b * 1.0)
	);

	// A transparencia mistura a tela corrigida com a original.
	COLOR = vec4(clamp(tex.rgb + correction, 0.0, 1.0), intensity);
}
