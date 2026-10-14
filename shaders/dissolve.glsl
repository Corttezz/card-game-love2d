extern number dissolve;
extern number time;
extern vec4 texture_details;
extern vec2 image_details;
extern bool shadow;
extern vec4 burn_colour_1;
extern vec4 burn_colour_2;
extern vec2 noise_scale;

float dh21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 41.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = dh21(i);
    float b = dh21(i + vec2(1.0, 0.0));
    float c = dh21(i + vec2(0.0, 1.0));
    float d = dh21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.55;
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p = p * 2.07 + vec2(11.3, 7.7);
        amp *= 0.5;
    }
    return clamp(v, 0.0, 1.0);
}

vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc) {
    vec4 px = Texel(tex, tc);

    if (dissolve < 0.001) {
        if (shadow) return vec4(0.0, 0.0, 0.0, px.a * 0.3);
        return px * colour;
    }

    vec2 quadSize = max(texture_details.zw, vec2(1.0));
    vec2 uv = (tc * image_details - texture_details.xy) / quadSize;
    uv = clamp(uv, 0.0, 1.0);

    vec2 cuv = uv - 0.5;
    float radial = length(cuv) * 1.42;

    vec2 nscale = (noise_scale.x > 0.0) ? noise_scale : vec2(5.5, 5.5);
    vec2 nuv = uv * nscale + vec2(time * 0.07, time * 0.045);
    float n = fbm(nuv);

    n += 0.08 * sin(uv.x * 9.0 + time * 0.6) * cos(uv.y * 7.0 - time * 0.5);
    n = clamp(n, 0.0, 1.0);

    float biased = dissolve + (radial - 0.5) * 0.35 * dissolve;
    float threshold = biased;

    float band = 0.10 + 0.06 * (1.0 - abs(dissolve - 0.5) * 2.0);

    float mask = smoothstep(threshold - 0.01, threshold + 0.01, n);

    if (shadow) {
        return vec4(0.0, 0.0, 0.0, px.a * mask * 0.3);
    }

    vec3 base = px.rgb;
    if (burn_colour_2.a > 0.01) {
        base = mix(base, burn_colour_2.rgb, dissolve * 0.45 * burn_colour_2.a);
    } else if (burn_colour_1.a > 0.01) {
        base = mix(base, burn_colour_1.rgb, dissolve * 0.35 * burn_colour_1.a);
    }

    float bandT = clamp((n - threshold) / band, 0.0, 1.0);
    float bandIntensity = (1.0 - bandT) * (1.0 - bandT);

    if (burn_colour_1.a > 0.01 && mask > 0.01 && bandIntensity > 0.01) {
        vec3 burnRgb = burn_colour_1.rgb;
        if (burn_colour_2.a > 0.01) {
            burnRgb = mix(burn_colour_1.rgb, burn_colour_2.rgb, bandT);
        }
        base = mix(base, burnRgb, bandIntensity * burn_colour_1.a);
    }

    return vec4(base, px.a * mask) * colour;
}
