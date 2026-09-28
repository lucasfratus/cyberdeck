shader_type canvas_item;

// Camada por cima da partida que imita um monitor CRT: linhas
// de varredura fracas e bordas escurecidas. Desenha so preto
// com transparencia, sem ler a tela, entao e barata.
// Passa por cima das cartas: manter os valores baixos.

uniform float scanline_intensity = 0.04;
uniform float vignette_strength = 0.7;

void fragment() {
	float scanline = mod(floor(FRAGCOORD.y), 3.0) < 1.0 ? 1.0 : 0.0;

	vec2 centered = SCREEN_UV - vec2(0.5);
	float vignette = clamp(
		dot(centered, centered) * vignette_strength, 0.0, 1.0
	);

	float darkness = max(scanline * scanline_intensity, vignette);

	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
