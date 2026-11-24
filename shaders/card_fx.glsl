extern number mode;
extern number progress;
extern number time;
extern vec4 card_rect;
extern vec2 canvas_px;
extern vec4 col_a;
extern vec4 col_b;
extern number seed;
extern number side;

float hash21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73) + seed * 0.137);
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

float lum(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 sampleCard(Image tex, vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return Texel(tex, card_rect.xy + uv * (card_rect.zw - card_rect.xy));
}

float outsideDist(vec2 uv, float aspect) {
    vec2 d = max(vec2(0.0), max(-uv, uv - 1.0));
    d.y *= aspect;
    return length(d);
}

float stroke(float d, float w) {
    return 1.0 - smoothstep(w, w * 2.2, abs(d));
}

float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec4 ash(Image tex, vec2 uv, float aspect) {
    float p = progress;
    vec2 nuv = uv * vec2(5.0, 5.0 * aspect);
    float n = fbm(nuv + vec2(0.0, time * 0.15));
    float f = uv.y * 0.55 + n * 0.45 + abs(uv.x - 0.5) * 0.12;
    float th = 1.02 - p * 1.3;
    if (f >= th) return vec4(0.0);
    float pre = clamp((f - (th - 0.35)) / 0.35, 0.0, 1.0);
    vec2 suv = uv;
    suv.x += sin(uv.y * 55.0 + time * 24.0) * 0.006 * pre;
    vec4 c = sampleCard(tex, suv);
    float g = lum(c.rgb);
    vec3 base = mix(c.rgb, vec3(g) * 0.85, clamp(p * 1.5, 0.0, 0.8));
    float charK = smoothstep(th - 0.24, th - 0.05, f);
    vec3 charcoal = vec3(0.10, 0.09, 0.085) + vec3(g) * 0.14;
    base = mix(base, charcoal, charK);
    float ridge = 1.0 - abs(vnoise(nuv * 3.1 + 7.0) * 2.0 - 1.0);
    base += col_b.rgb * smoothstep(0.86, 0.97, ridge) * charK * 0.9;
    float ember = smoothstep(th - 0.07, th - 0.005, f);
    float flick = 0.75 + 0.25 * sin(time * 30.0 + uv.x * 40.0);
    vec3 emberC = mix(col_b.rgb, col_a.rgb, ember) * (1.0 + 0.4 * flick);
    base = mix(base, emberC, ember);
    return vec4(base, c.a);
}

float rune(vec2 g, float sid) {
    float hw = 0.020;
    float hh = 0.030;
    float d = seg(g, vec2(0.0, -hh), vec2(0.0, hh));
    float h1 = hash21(vec2(sid, 3.0));
    float h2 = hash21(vec2(sid, 7.0));
    float h3 = hash21(vec2(sid, 11.0));
    float h4 = hash21(vec2(sid, 13.0));
    if (h1 > 0.40) d = min(d, seg(g, vec2(0.0, -hh * 0.2), vec2(hw, -hh)));
    if (h2 > 0.55) d = min(d, seg(g, vec2(0.0, -hh * 0.2), vec2(-hw, -hh)));
    if (h3 > 0.50) d = min(d, seg(g, vec2(0.0, hh * 0.25), vec2(hw, hh)));
    if (h4 > 0.60) d = min(d, seg(g, vec2(-hw, -hh * 0.35), vec2(hw, hh * 0.35)));
    if (h1 <= 0.40 && h2 <= 0.55) d = min(d, seg(g, vec2(0.0, -hh), vec2(hw, -hh * 0.4)));
    return d;
}

vec4 seal(Image tex, vec2 uv, float aspect, float pxw) {
    float p = progress;
    float drawK = smoothstep(0.0, 0.42, p);
    float stamp = smoothstep(0.42, 0.50, p) * (1.0 - smoothstep(0.50, 0.80, p));
    float fade = 1.0 - smoothstep(0.72, 1.0, p);
    vec2 c = vec2(0.5, 0.46);
    vec2 q = (uv - c) * vec2(1.0, aspect);
    float r = length(q);
    float a01 = fract(atan(q.y, q.x) / 6.28318 + 0.25);
    float ripR = (p - 0.46) * 1.6;
    float rip = exp(-abs(r - ripR) * 28.0) * step(0.46, p) * (1.0 - smoothstep(0.5, 0.9, p));
    vec2 dir = r > 0.0001 ? q / r : vec2(0.0);
    vec2 suv = uv - dir * vec2(1.0, 1.0 / aspect) * rip * 0.025;
    suv = c + (suv - c) * (1.0 - 0.035 * stamp);
    vec4 col = sampleCard(tex, suv);
    float out_d = outsideDist(uv, aspect);
    float w = pxw * 0.8;
    float shown = step(a01, drawK + 0.002);
    float head = exp(-abs(a01 - drawK) * 60.0) * (1.0 - step(0.999, drawK));
    float rings = min(abs(r - 0.40), abs(r - 0.30));
    rings = min(rings, abs(r - 0.14));
    float sectors = 10.0;
    float sid = floor(a01 * sectors);
    float sa = fract(a01 * sectors) - 0.5;
    vec2 g = vec2(sa * 6.28318 * 0.35 / sectors, r - 0.35);
    float gl = (abs(r - 0.35) < 0.045) ? rune(g, sid) : 1.0;
    float sp = abs(fract(a01 * 6.0 + 0.5) - 0.5) * (6.28318 / 6.0) * r;
    if (r < 0.14 || r > 0.30) sp = 1.0;
    vec2 qe = vec2(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y) * aspect);
    float edge = abs(min(qe.x, qe.y) - 0.045);
    float dmin = min(min(rings, gl), min(sp, edge));
    float core = stroke(dmin, w) * shown;
    float halo = exp(-dmin / (pxw * 3.5)) * shown * 0.55;
    float disc = 1.0 - smoothstep(0.40, 0.47, r);
    if (col.a < 0.01) {
        float glow = exp(-out_d * 38.0) * drawK * fade * 0.75 + exp(-out_d * 20.0) * stamp * 0.6;
        return vec4(col_b.rgb, glow);
    }
    vec3 base = col.rgb;
    base *= 1.0 - 0.38 * disc * drawK * fade;
    base = mix(base, base * col_b.rgb * 1.4, 0.30 * disc * drawK * fade);
    float lit = (core + halo + head * 0.8 * step(abs(r - 0.35), 0.06)) * fade;
    float bright = 1.0 + 0.8 * stamp;
    base += col_b.rgb * halo * fade * bright;
    base = mix(base, col_a.rgb * bright, clamp(core * fade, 0.0, 1.0));
    base += col_a.rgb * head * 0.6 * fade;
    base += col_a.rgb * stamp * 0.35 * disc * (1.0 - r / 0.47);
    base += col_b.rgb * rip * 0.6;
    return vec4(base, col.a);
}

vec4 mirror(Image tex, vec2 uv, float aspect) {
    float p = progress;
    float s = side > 0.0 ? uv.x : 1.0 - uv.x;
    float front = p * 1.7 - 0.12;
    float jag = (vnoise(vec2(uv.y * 18.0, time * 3.0)) - 0.5) * 0.06;
    float d = front + jag - s;
    if (d < 0.0) return vec4(0.0);
    float seamK = 1.0 - smoothstep(0.0, 0.05, d);
    float silver = 1.0 - smoothstep(0.0, 0.38, d);
    float band = floor(uv.y * 40.0);
    float glitch = step(0.72, vnoise(vec2(band, floor(time * 14.0)))) * silver;
    vec2 suv = uv + vec2((side > 0.0 ? -1.0 : 1.0) * glitch * 0.035, 0.0);
    vec4 c = sampleCard(tex, suv);
    float g = lum(c.rgb);
    vec3 chrome = vec3(0.50 + 0.65 * g) * vec3(0.90, 0.96, 1.06);
    float hue = fract(uv.y * 1.7 + s * 2.3 + time * 0.6);
    vec3 iri = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
    vec3 base = mix(c.rgb, chrome + iri * 0.28, silver * 0.88);
    base = mix(base, col_a.rgb * 0.85 + iri * 0.45, seamK);
    float sh = (p - 0.72) / 0.28 * 1.7 - 0.35;
    float shine = exp(-abs(uv.x * 0.75 + uv.y * 0.55 - sh) * 26.0) * step(0.72, p) * (1.0 - step(1.0, p));
    base += col_b.rgb * shine * 0.7;
    return vec4(base, c.a);
}

vec4 wind(Image tex, vec2 uv, float aspect) {
    float p = progress;
    float amp = smoothstep(0.0, 0.30, p);
    float tr = side > 0.0 ? 1.0 - uv.x : uv.x;
    vec2 suv = uv;
    suv.y += sin(tr * 8.0 - time * 20.0) * 0.035 * amp * tr;
    suv.x += sin(uv.y * 6.0 + time * 15.0) * 0.012 * amp * tr;
    vec4 c = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        float k = float(i) / 3.0;
        c += sampleCard(tex, suv + vec2(side * k * 0.06 * amp, 0.0));
    }
    c /= 4.0;
    float g = lum(c.rgb);
    vec3 sep = vec3(g * 1.06, g * 0.84, g * 0.66);
    vec3 base = mix(c.rgb, sep * col_a.rgb * 1.5, 0.55 * amp);
    float crease = (fract(uv.x * 2.6 + uv.y * 1.9 + 0.3) - 0.5) + (fract(uv.x * -1.7 + uv.y * 2.4) - 0.5) * 0.7;
    base *= 1.0 + crease * 0.38 * amp;
    float curl = smoothstep(0.55, 1.0, tr) * amp;
    base = mix(base, col_b.rgb, curl * 0.45);
    return vec4(base, c.a);
}

vec4 dawn(Image tex, vec2 uv, float aspect) {
    float p = progress;
    float bandY = 1.15 - p * 1.45;
    float wav = (vnoise(vec2(uv.x * 7.0, time * 2.0)) - 0.5) * 0.05;
    float dy = uv.y - (bandY + wav);
    vec4 c = sampleCard(tex, uv);
    float out_d = outsideDist(uv, aspect);
    float rise = sin(3.14159 * clamp(p, 0.0, 1.0));
    if (c.a < 0.01) {
        float rim = exp(-out_d * 42.0) * rise * 0.8;
        float rays = 0.0;
        if (uv.y < 0.0) {
            rays = smoothstep(0.55, 0.85, fbm(vec2(uv.x * 9.0, time * 0.8))) * exp(uv.y * aspect * 14.0) * rise;
        }
        return vec4(col_a.rgb, clamp(rim + rays * 0.8, 0.0, 1.0));
    }
    float lit = smoothstep(-0.02, 0.06, dy);
    float g = lum(c.rgb);
    vec3 shade = vec3(g) * vec3(0.22, 0.20, 0.30);
    vec3 base = mix(shade, c.rgb, lit);
    float crest = exp(-abs(dy) * 30.0) * (1.0 - smoothstep(0.85, 1.0, p));
    base += col_a.rgb * crest * 1.1;
    base = mix(base, base * col_b.rgb * 1.3, 0.30 * lit * rise);
    vec2 cell = floor(uv * vec2(24.0, 24.0 * aspect));
    float h = hash21(cell);
    float sparkle = step(0.92, h) * crest * (0.5 + 0.5 * sin(time * 20.0 + h * 40.0));
    base += vec3(1.0, 0.97, 0.85) * sparkle;
    base = mix(base, c.rgb, smoothstep(0.85, 1.0, p));
    return vec4(base, c.a);
}

vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc) {
    vec2 pxc = (floor(tc * canvas_px) + 0.5) / canvas_px;
    vec2 span = card_rect.zw - card_rect.xy;
    vec2 uv = (pxc - card_rect.xy) / span;
    float cardW = span.x * canvas_px.x;
    float aspect = (span.y * canvas_px.y) / max(0.0001, cardW);
    float pxw = 1.0 / max(1.0, cardW);
    vec4 r;
    if (mode < 1.5) {
        r = ash(tex, uv, aspect);
    } else if (mode < 2.5) {
        r = seal(tex, uv, aspect, pxw);
    } else if (mode < 3.5) {
        r = mirror(tex, uv, aspect);
    } else if (mode < 4.5) {
        r = wind(tex, uv, aspect);
    } else {
        r = dawn(tex, uv, aspect);
    }
    return r * colour;
}
