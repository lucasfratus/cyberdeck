shader_type canvas_item;

// Fundo animado da interface, no estilo de monitor de terminal:
// grade discreta, linhas de varredura finas, uma faixa de brilho
// que desce devagar, cintilacao leve e bordas escurecidas.
// Fica atras de tudo, entao nao interfere na leitura das cartas.

uniform vec4 base_color : source_color = vec4(0.02, 0.05, 0.03, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.45, 1.0);

// Grade, em pixels da tela.
uniform float grid_size = 32.0;
uniform float grid_intensity = 0.05;

// Linhas de varredura finas: uma linha escura a cada 3 pixels.
uniform float scanline_intensity = 0.06;

// Faixa de brilho que atravessa a tela de cima para baixo.
uniform float sweep_speed = 0.06;
uniform float sweep_intensity = 0.05;

uniform float flicker_intensity = 0.012;
uniform float vignette_strength = 0.9;

void fragment() {
	vec2 pixel = FRAGCOORD.xy;

	vec2 cell = mod(pixel, grid_size);
	float grid = min(step(cell.x, 1.0) + step(cell.y, 1.0), 1.0);

	float scanline = mod(floor(pixel.y), 3.0) < 1.0 ? 1.0 : 0.0;

	float sweep_position = fract(TIME * sweep_speed);
	float sweep_distance = SCREEN_UV.y - sweep_position;
	float sweep = exp(-sweep_distance * sweep_distance * 600.0);

	float flicker = 1.0 + flicker_intensity
		* sin(TIME * 55.0) * sin(TIME * 7.3);

	vec2 centered = SCREEN_UV - vec2(0.5);
	float vignette = 1.0 - clamp(
		dot(centered, centered) * vignette_strength, 0.0, 1.0
	);

	vec3 color = base_color.rgb;
	color += glow_color.rgb * grid * grid_intensity;
	color += glow_color.rgb * sweep * sweep_intensity;
	color *= 1.0 - scanline * scanline_intensity;
	color *= flicker * vignette;

	COLOR = vec4(color, 1.0);
}
