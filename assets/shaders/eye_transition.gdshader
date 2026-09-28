shader_type canvas_item;

// Transicao das chamadas dos antagonistas: um olho em pixel art,
// no mesmo estilo da ilustracao da anomalia, que abre no meio da
// tela escura. Para entrar na chamada, a imagem mergulha na
// pupila, que fica transparente e revela a cena por tras. Para
// sair, o caminho e o inverso e o olho fecha.

// 0: palpebras fechadas; 1: olho aberto.
uniform float open : hint_range(0.0, 1.0) = 0.0;
// 1: tamanho normal. Valores grandes aproximam a pupila.
uniform float zoom = 1.0;
// 1: a pupila deixa ver o que esta atras do olho.
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
// Intensidade dos defeitos de imagem.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// Para onde o olho olha, em unidades da altura da tela.
uniform vec2 look = vec2(0.0);

uniform float pixel_size = 6.0;

uniform vec4 sclera_color : source_color = vec4(0.98, 0.95, 0.86, 1.0);
uniform vec4 sclera_shade : source_color = vec4(0.78, 0.7, 0.8, 1.0);
uniform vec4 iris_color : source_color = vec4(0.9, 0.2, 0.24, 1.0);
uniform vec4 iris_dark : source_color = vec4(0.55, 0.08, 0.16, 1.0);
uniform vec4 lid_color : source_color = vec4(0.03, 0.0, 0.03, 1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 glitch_a : source_color = vec4(0.86, 0.24, 0.78, 1.0);
uniform vec4 glitch_b : source_color = vec4(0.24, 0.86, 0.94, 1.0);

const float EYE_HALF_WIDTH = 0.42;
const float EYE_HALF_HEIGHT = 0.2;
const float IRIS_RADIUS = 0.13;
const float PUPIL_HALF_WIDTH = 0.024;
const float PUPIL_HALF_HEIGHT = 0.1;
const float OUTLINE = 0.014;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

	// Blocos de pixel_size: o olho inteiro sai pixelado.
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	vec2 pixel = block * pixel_size + pixel_size * 0.5;

	// Faixas horizontais que pulam de lugar.
	float frame = floor(TIME * 14.0);
	float band = floor(pixel.y / (pixel_size * 3.0));
	if (hash(vec2(band, frame)) > 0.82) {
		pixel.x += (hash(vec2(frame, band)) - 0.5) * glitch * 0.3 * resolution.y;
	}

	vec2 p = (pixel - resolution * 0.5) / resolution.y;
	p /= zoom;

	float nx = p.x / EYE_HALF_WIDTH;
	float lid = open * EYE_HALF_HEIGHT * max(0.0, 1.0 - nx * nx);
	float lid_outline = lid + OUTLINE * open;

	vec3 color = lid_color.rgb;
	float alpha = 1.0;

	bool inside = abs(nx) < 1.0 && abs(p.y) < lid;
	bool outline = !inside && abs(nx) < 1.06 && abs(p.y) < lid_outline && open > 0.02;

	if (inside) {
		// Sombra da palpebra perto das bordas do olho.
		float depth = abs(p.y) / max(lid, 0.0001);
		color = mix(sclera_color.rgb, sclera_shade.rgb, step(0.72, depth));

		vec2 q = p - look;
		float r = length(q);

		if (r < IRIS_RADIUS) {
			color = mix(iris_color.rgb, iris_dark.rgb, step(IRIS_RADIUS * 0.62, r));

			if (r > IRIS_RADIUS - OUTLINE) {
				color = outline_color.rgb;
			}

			vec2 slit = q / vec2(PUPIL_HALF_WIDTH, PUPIL_HALF_HEIGHT);
			if (dot(slit, slit) < 1.0) {
				color = outline_color.rgb;
				alpha = 1.0 - reveal;
			}

			// Brilho no canto da iris.
			vec2 shine = q - vec2(-0.05, 0.05);
			if (length(shine) < 0.018) {
				color = vec3(1.0);
			}
		}
	} else if (outline) {
		color = outline_color.rgb;
	} else if (glitch > 0.0) {
		// Pixels soltos corrompidos em volta do olho.
		float spark = hash(block + frame);
		if (spark > 1.0 - 0.012 * glitch) {
			color = hash(block * 1.7 + frame) > 0.5 ? glitch_a.rgb : glitch_b.rgb;
		}
	}

	COLOR = vec4(color, alpha);
}
