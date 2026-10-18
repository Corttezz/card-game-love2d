uniform vec3 fog;
uniform vec4 depth;
uniform vec2 texel;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
{
    vec4 p = Texel(tex, uv);
    if (depth.z > 0.5) {
        vec2 cell = texel * 2.0;
        vec2 g = (floor(uv / cell) + 0.5) * cell;
        vec2 h = texel * 0.5;
        vec4 a = Texel(tex, g - h);
        vec4 b = Texel(tex, g + vec2(h.x, -h.y));
        vec4 c = Texel(tex, g + vec2(-h.x, h.y));
        vec4 d = Texel(tex, g + h);
        float wa = a.a + b.a + c.a + d.a;
        vec3 rgb = a.a > 0.5 ? a.rgb : (b.a > 0.5 ? b.rgb : (c.a > 0.5 ? c.rgb : d.rgb));
        p = vec4(rgb, step(2.0, wa));
    }
    float l = dot(p.rgb, vec3(0.299, 0.587, 0.114));
    p.rgb = mix(vec3(l), p.rgb, depth.y);
    p.rgb = mix(p.rgb, fog, depth.x * clamp(1.3 - 0.6 * l, 0.6, 1.3));
    p.rgb *= 1.0 + depth.w * (0.5 - uv.y) * 2.0;
    return vec4(p.rgb * color.rgb, p.a * color.a);
}
