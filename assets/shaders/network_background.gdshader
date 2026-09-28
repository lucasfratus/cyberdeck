shader_type canvas_item;

// Fundo dos dialogos fora da partida: a "Rede". Nos que se
// movem devagar, ligados por linhas que aparecem quando dois
// nos se aproximam, sobre um gradiente azul escuro. As cores
// frias separam esses momentos da partida, que e verde.
// O desenho e feito em blocos de pixel_size pixels, no mesmo
// estilo pixelado do resto do jogo.

uniform vec4 top_color : source_color = vec4(0.02, 0.02, 0.07, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.06, 0.12, 1.0);
uniform vec4 node_color : source_color = vec4(0.45, 0.62, 1.0, 1.0);
uniform vec4 link_color : source_color = vec4(0.3, 0.42, 0.95, 1.0);

// Tamanho medio da celula de cada no, em pixels da tela.
uniform float cell_size = 110.0;
uniform float pixel_size = 3.0;
uniform float speed = 0.05;
uniform float link_intensity = 0.22;
uniform float node_intensity = 0.9;
uniform float vignette_strength = 1.1;

vec2 hash2(vec2 p) {
	p = vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	);
	return fract(sin(p) * 43758.5453);
}

// Posicao do no da celula, oscilando em volta do centro.
vec2 node_in(vec2 cell) {
	vec2 h = hash2(cell);
	vec2 phase = h * 6.2831;
	return cell + 0.5 + 0.36 * vec2(
		sin(TIME * speed * 6.2831 * (0.6 + h.x) + phase.x),
		cos(TIME * speed * 6.2831 * (0.6 + h.y) + phase.y)
	);
}

// Distancia do ponto p ao segmento ab.
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float link(vec2 p, vec2 a, vec2 b, float line_width) {
	float len = length(a - b);
	float fade = smoothstep(1.5, 0.7, len);
	return fade * step(segment(p, a, b), line_width);
}

void fragment() {
	vec2 pixel = floor(FRAGCOORD.xy / pixel_size) * pixel_size;
	vec2 uv = pixel / cell_size;
	vec2 cell = floor(uv);

	vec2 nodes[9];
	int k = 0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			nodes[k] = node_in(cell + vec2(float(x), float(y)));
			k++;
		}
	}

	float line_width = pixel_size * 0.6 / cell_size;
	float links = 0.0;

	// Do no central para os oito vizinhos.
	for (int i = 0; i < 9; i++) {
		if (i != 4) {
			links += link(uv, nodes[4], nodes[i], line_width);
		}
	}

	// Entre vizinhos laterais, para fechar os triangulos.
	links += link(uv, nodes[1], nodes[3], line_width);
	links += link(uv, nodes[1], nodes[5], line_width);
	links += link(uv, nodes[7], nodes[3], line_width);
	links += link(uv, nodes[7], nodes[5], line_width);

	float glow = 0.0;
	float core = 0.0;
	for (int i = 0; i < 9; i++) {
		float d = length(uv - nodes[i]) * cell_size;

		// Cada no pisca devagar em um ritmo proprio.
		float pulse = 0.7 + 0.3 * sin(TIME * 1.3 + hash2(floor(nodes[i])).x * 6.2831);
		core += step(d, pixel_size * 1.6) * pulse;
		glow += exp(-d * d / 180.0) * 0.35 * pulse;
	}

	vec3 color = mix(top_color.rgb, bottom_color.rgb, SCREEN_UV.y);
	color += link_color.rgb * min(links, 1.0) * link_intensity;
	color += node_color.rgb * (min(core, 1.0) + glow) * node_intensity;

	vec2 centered = SCREEN_UV - vec2(0.5);
	color *= 1.0 - clamp(dot(centered, centered) * vignette_strength, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
