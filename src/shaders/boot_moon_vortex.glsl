extern number t;
extern vec2 moon_uv;
extern vec2 tex_size;
extern number radius_px;
extern number strength;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec2 ap = floor(uv * tex_size) + 0.5;
    vec2 mp = moon_uv * tex_size;
    vec2 d = ap - mp;
    number r = length(d) / max(radius_px, 1.0);
    if (r > 1.0) discard;

    vec4 px = Texel(tex, uv);

    number theta = atan(d.y, d.x);
    number phase = 2.0 * theta + 5.0 * log(max(r, 0.05)) - t * 2.4;
    number arm = sin(phase);
    number arms = smoothstep(0.35, 0.75, arm);
    number fall = 1.0 - smoothstep(0.20, 0.95, r);
    number shimmer = 0.85 + 0.15 * sin(phase * 3.0 + t * 1.7);

    number gaps = 1.0 - arms;
    px.rgb *= 1.0 - gaps * fall * strength * 0.30
        * vec3(0.85, 1.0, 1.15);
    vec3 glowCol = mix(vec3(1.0, 0.82, 0.48), vec3(1.0, 0.98, 0.90), fall);
    px.rgb += glowCol * arms * fall * shimmer * strength * 0.15;

    number eye = 1.0 - smoothstep(0.03, 0.17, r);
    px.rgb *= 1.0 - 0.50 * eye * strength;
    number rim = smoothstep(0.10, 0.16, r) * (1.0 - smoothstep(0.16, 0.24, r));
    px.rgb += vec3(1.0, 0.95, 0.80) * rim * strength * 0.35;

    return px * colour;
}
