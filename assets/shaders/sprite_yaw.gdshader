shader_type canvas_item;

// Vira um sprite de frente um pouco para o lado, sem desenhar
// outra imagem. O lado de dentro da virada encolhe e o de fora
// cresce um pouco na altura, como em perspectiva.
//   yaw > 0: olha para a direita. yaw < 0: para a esquerda.

uniform float yaw : hint_range(-0.6, 0.6) = 0.0;

// Cor do vertice com o modulate do no. No fragment, COLOR ja
// vem multiplicado pela textura, entao ela e guardada antes.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float amount = abs(yaw);

	// Compressao horizontal para o lado da virada.
	float x = yaw >= 0.0 ? uv.x : 1.0 - uv.x;
	float p = 1.0 - amount;
	x = 1.0 - pow(1.0 - x, p);
	uv.x = yaw >= 0.0 ? x : 1.0 - x;

	// O lado mais perto da camera fica um pouco mais alto.
	float near = yaw >= 0.0 ? (1.0 - UV.x) : UV.x;
	float height = 1.0 + amount * 0.25 * (near - 0.5);
	uv.y = 0.5 + (uv.y - 0.5) / height;

	vec4 color = texture(TEXTURE, uv);
	if (uv.y < 0.0 || uv.y > 1.0) {
		color.a = 0.0;
	}
	COLOR = color * tint;
}
