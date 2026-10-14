extern number time;
extern number strength;

float ph21(vec2 p) {
    p = fract(p * vec2(133.71, 271.09));
    p += dot(p, p + 41.13);
    return fract(p.x * p.y);
}

vec3 grimoireRamp(float t) {
    t = fract(t) * 5.0;
    int i = int(floor(t));
    float f = smoothstep(0.0, 1.0, fract(t));

    vec3 amber  = vec3(0.831, 0.690, 0.376);
    vec3 ochre  = vec3(0.690, 0.478, 0.220);
    vec3 rust   = vec3(0.545, 0.290, 0.118);
    vec3 violet = vec3(0.353, 0.227, 0.431);
    vec3 moss   = vec3(0.353, 0.455, 0.227);

    vec3 a, b;
    if (i == 0)      { a = amber;  b = ochre;  }
    else if (i == 1) { a = ochre;  b = rust;   }
    else if (i == 2) { a = rust;   b = violet; }
    else if (i == 3) { a = violet; b = moss;   }
    else             { a = moss;   b = amber;  }
    return mix(a, b, f);
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    vec2 cuv = uv - 0.5;
    float r = length(cuv);
    float t = (uv.x * 0.55 + uv.y * 0.35 - r * 0.45) * 2.1 + time * 0.13;
    vec3 ramp = grimoireRamp(t);

    vec3 tinted = base.rgb * (0.30 + 1.60 * ramp);
    vec3 outRgb = mix(base.rgb, tinted, clamp(strength, 0.0, 1.0));

    float diag = uv.x * 1.25 + uv.y * 0.85 - time * 0.30;
    float sweep = fract(diag);
    float dist = min(abs(sweep - 0.5), min(abs(sweep + 0.5), abs(sweep - 1.5)));
    float band = 1.0 - smoothstep(0.0, 0.19, dist);
    band *= band;
    vec3 glint = mix(grimoireRamp(t + 0.12), vec3(1.0), 0.45);
    outRgb += glint * band * strength * 0.58;

    float grain = ph21(floor(uv * 240.0));
    outRgb += vec3((grain - 0.5) * 0.16) * band * strength;

    outRgb = clamp(outRgb, 0.0, 1.35);
    return vec4(outRgb, base.a) * colour;
}
