extern number time;
extern number strength;

float fh21(vec2 p) {
    p = fract(p * vec2(83.51, 287.13));
    p += dot(p, p + 19.81);
    return fract(p.x * p.y);
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    float diag = uv.x * 1.4 + uv.y * 0.9 + time * 0.25;
    float strip = sin(diag * 3.14159);
    float metallic = 0.5 + 0.5 * strip;

    float sweep = fract(diag * 0.5);
    sweep = smoothstep(0.42, 0.50, sweep) * (1.0 - smoothstep(0.50, 0.58, sweep));

    vec3 silver = vec3(0.78, 0.84, 0.95);
    vec3 highlightColor = vec3(1.0, 1.0, 1.05);

    float grain = fh21(floor(uv * 280.0));
    grain = (grain - 0.5) * 0.18;

    vec3 outRgb = base.rgb;
    outRgb = mix(outRgb, silver, strength * 0.30 * metallic);
    outRgb += highlightColor * sweep * strength * 0.55;
    outRgb += vec3(grain) * strength * 0.4;

    outRgb = clamp(outRgb * (1.0 + strength * 0.05), 0.0, 1.4);

    return vec4(outRgb, base.a) * colour;
}
