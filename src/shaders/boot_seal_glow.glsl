extern vec2 center;
extern number radius;
extern number strength;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 px = Texel(tex, uv);

    number d = length(sc - center) / max(radius, 1.0);
    number m = 1.0 - smoothstep(0.55, 1.0, d);

    number lum = dot(px.rgb, vec3(0.35, 0.5, 0.15));
    number hi = max(0.0, lum - 0.18) / 0.82;

    vec3 glow = vec3(1.0, 0.84, 0.48) * hi * m * strength;
    return vec4(glow, 1.0) * colour;
}
