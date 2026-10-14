extern vec3 flatColor;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float a = Texel(tex, uv).a;
    if (a < 0.5) discard;
    return vec4(flatColor, 1.0);
}
