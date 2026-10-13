// shaders/desat.glsl — dessaturação da cena (morte do chefe, BossCinematic).
// Mistura a cor com a luminância, puxada pra um cinza levemente frio: a vida
// sai do salão por um instante. `amount` 0 = intacto, 1 = cinza.
extern float amount;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
{
    vec4 c = Texel(tex, uv);
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 g = vec3(l) * vec3(0.94, 0.95, 1.02);
    return vec4(mix(c.rgb, g, amount), c.a) * color;
}
