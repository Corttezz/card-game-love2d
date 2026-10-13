// shaders/card_perspective.glsl
// Perspective warp estilo Balatro pra cartas — aplica deformação per-vertex
// baseada em mouse position + hover intensity + wobble idle sutil.
//
// Uso: draw com love.graphics.draw(mesh, ...) com este shader ativo.
// Mesh deve ter tessellação suficiente (~8×12 = 96 verts) pra distorção suave.
//
// Uniforms:
//   mouse    (vec2)   — posição do mouse em [-1, 1] relativo ao centro da carta
//                      (-1,-1 top-left; +1,+1 bottom-right; 0,0 = centro/neutro)
//   hover    (number) — intensidade 0..1 do efeito (smoothed)
//   time     (number) — segundos acumulados pro wobble
//   cardSize (vec2)   — largura/altura do canvas em pixels
//   quadOn   (number) — 1 = modo QUADRILÁTERO (Loja v3c: carta no cavalete
//                      em perspectiva real). A carta inteira é mapeada pela
//                      homografia hRow0..2 (quadrado unitário → 4 cantos em
//                      coordenadas do mundo); o press/wobble somam por cima.
//                      0 = comportamento antigo. CardMesh.setUniforms zera
//                      SEMPRE (o shader é compartilhado: quem não usa o modo
//                      nunca herda o quadrilátero da loja).

extern vec2 mouse;
extern number hover;
extern number time;
extern vec2 cardSize;
extern number quadOn;
extern vec3 hRow0;
extern vec3 hRow1;
extern vec3 hRow2;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // UV local do vertex [0..1]
    vec2 uv = vertex_position.xy / cardSize;
    // Centrado [-0.5, 0.5]
    vec2 centered = uv - vec2(0.5);

    // Projeção do vertex no vetor mouse: vertex "atrás" do mouse (mesmo lado)
    // tem proj positiva; vertex oposto tem proj negativa.
    float proj = dot(centered, mouse);

    // Press effect: canto COM mouse AFUNDA (contrai em direção ao centro);
    // canto oposto LEVANTA (se afasta). Sinal NEGATIVO inverte a direção.
    // Amplitude 0.12 — Balatro-like sutil, não exagera.
    float pressAmount = -proj * hover * 0.12;

    // Wobble idle sutil — só quando hover > 0.
    float wobble = sin(time * 2.0 + centered.x * 4.0) * 0.005 * hover
                 + cos(time * 1.7 + centered.y * 4.0) * 0.005 * hover;

    // Vertex próximo do mouse: pressAmount negativo → vertex CONTRAI (move pro centro).
    // Vertex oposto: pressAmount positivo → vertex EXPANDE (afasta do centro).
    vec2 warped = vertex_position.xy + centered * cardSize * (pressAmount + wobble);

    if (quadOn > 0.5) {
        vec3 q = vec3(warped / cardSize, 1.0);
        float w = dot(hRow2, q);
        warped = vec2(dot(hRow0, q), dot(hRow1, q)) / w;
    }

    return transform_projection * vec4(warped, vertex_position.zw);
}
#endif

#ifdef PIXEL
// Fragment passa direto — combinação com holo/glow acontece em outro pass.
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    return Texel(tex, uv) * color;
}
#endif
