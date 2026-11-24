extern Image relief;
extern vec4 sheet;
extern vec2 ink_px;
extern number amp;
extern number wear;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * ink_px;
    vec2 su = (p - sheet.xy) / sheet.zw;
    if (su.x < 0.0 || su.y < 0.0 || su.x > 1.0 || su.y > 1.0) return vec4(0.0);
    vec4 r = Texel(relief, su);
    vec2 g = (r.gb - 0.5) * 2.0;
    vec2 off = clamp(g * amp, vec2(-3.0), vec2(3.0));
    vec4 ink = Texel(tex, uv - off / ink_px);
    float lit = clamp(1.0 + dot(g, vec2(-0.45, -0.65)) * 0.4, 0.78, 1.15);
    ink.rgb = min(ink.rgb * lit, vec3(ink.a));
    ink *= r.a * (1.0 - r.r * wear);
    return ink * color;
}
