extern vec2 size;
extern number seed;
extern number mode;
extern vec3 folds;
extern vec4 stains[4];
extern vec3 paper_light;
extern vec3 paper_base;
extern vec3 paper_dark;
extern vec3 rim_color;

float permute(float x) {
    x = mod(x, 289.0);
    return mod((34.0 * x + 1.0) * x, 289.0);
}

float hash21(vec2 i) {
    float h = permute(permute(i.x + seed) + i.y + floor(seed * 0.37));
    return fract(permute(h + 17.0) * 0.0345678 + h * 0.00346);
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

const mat2 ROT = mat2(0.8, -0.6, 0.6, 0.8);

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p = ROT * p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

vec2 grad(vec2 i) {
    float a = hash21(i) * 6.2831853;
    return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = dot(grad(i), f);
    float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float creases(vec2 p) {
    float v = 0.0;
    float a = 0.6;
    for (int i = 0; i < 4; i++) {
        v += a * abs(gnoise(p));
        p = ROT * p * 2.07 + vec2(5.3, 11.9);
        a *= 0.48;
    }
    return v;
}

float soft(vec2 p) {
    return gnoise(p) + 0.5 * gnoise(ROT * p * 2.1 + vec2(3.0, 1.0));
}

float tent(float d, float w) {
    return max(0.0, 1.0 - abs(d) / w);
}

float tornDepth(float t, float salt, float base, float deep) {
    float n = fbm(vec2(t / 34.0, salt * 3.7));
    float fine = vnoise(vec2(t / 3.0, salt * 5.1 + 7.0));
    float chip = pow(vnoise(vec2(t / 11.0, salt * 4.3 + 2.0)), 6.0);
    float bite = pow(vnoise(vec2(t / 80.0, salt * 2.3 + 13.0)), 4.0);
    return base + (n * 15.0 + fine * 3.0 + chip * 12.0 + bite * 34.0) * deep;
}

float edgeField(vec2 p) {
    float l = p.x - tornDepth(p.y, 1.0, 1.0, 0.65);
    float r = size.x - p.x - tornDepth(p.y, 2.0, 1.0, 0.6);
    float mid = 1.0 - smoothstep(0.2, 0.3, abs(p.x / size.x - 0.5));
    float t = p.y - tornDepth(p.x, 3.0, 0.5, mix(0.26, 0.09, mid));
    float nd = min(64.0, size.y * 0.065);
    float ny = clamp((size.y - p.y) / nd, 0.0, 1.0);
    float nx = size.x * 0.63 + ny * 9.0 + (vnoise(vec2(p.y / 3.0, 31.0)) - 0.5) * 4.0;
    float notch = pow(tent(p.x - nx, 13.0), 1.6) * nd;
    float b = size.y - p.y - tornDepth(p.x, 4.0, 1.5, 1.0) - notch;
    float cut = min(70.0, size.y * 0.07);
    float corner = (p.x + (size.y - p.y) - cut - fbm(vec2(p.x / 9.0, 5.0)) * 22.0) * 0.7071;
    return min(min(min(l, r), min(t, b)), corner);
}

float panel(float v, float a, float b) {
    return sin(3.14159 * clamp((v - a) / max(1.0, b - a), 0.0, 1.0));
}

float bulge(vec2 p) {
    float bx = p.x < folds.x ? panel(p.x, 0.0, folds.x) : (p.x < folds.y ? panel(p.x, folds.x, folds.y) : panel(p.x, folds.y, size.x));
    float by = p.y < folds.z ? panel(p.y, 0.0, folds.z) : panel(p.y, folds.z, size.y);
    return bx * by;
}

vec3 foldDist(vec2 p) {
    float d1 = p.x - folds.x + soft(vec2(p.y / 170.0, 21.0)) * 9.0 + gnoise(vec2(p.y / 26.0, 2.0)) * 1.6;
    float d2 = p.x - folds.y + soft(vec2(p.y / 180.0, 23.0)) * 9.0 + gnoise(vec2(p.y / 24.0, 4.0)) * 1.6;
    float d3 = p.y - folds.z + soft(vec2(p.x / 190.0, 25.0)) * 8.0 + gnoise(vec2(p.x / 28.0, 6.0)) * 1.4;
    return vec3(d1, d2, d3);
}

vec3 foldDepth(vec2 p) {
    return vec3(0.55 + 0.6 * fbm(vec2(p.y / 230.0, 41.0)),
                0.55 + 0.6 * fbm(vec2(p.y / 230.0, 43.0)),
                0.55 + 0.6 * fbm(vec2(p.x / 260.0, 45.0)));
}

float crumpleZone(vec2 p) {
    return smoothstep(0.42, 0.68, fbm(p / 420.0 + vec2(3.1, 7.7)));
}

float ridge(float d, float w) {
    return exp(-abs(d) / w);
}

float heightAt(vec2 p) {
    vec3 fd = foldDist(p);
    vec3 fk = foldDepth(p);
    float h = ridge(fd.x, 6.0) * 0.75 * fk.x - ridge(fd.y, 6.0) * 0.7 * fk.y - ridge(fd.z, 5.5) * 0.75 * fk.z;
    h += bulge(p) * 0.35;
    h -= creases(p / 85.0) * (0.25 + 0.9 * crumpleZone(p));
    h += soft(p / 260.0) * 0.18;
    float d0 = min(min(p.x, p.y), min(size.x - p.x, size.y - p.y));
    float curl = max(0.0, 1.0 - d0 / 44.0);
    h += curl * curl * 0.8;
    return h;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * size;
    float e = edgeField(p);
    float alpha = smoothstep(-0.6, 0.9, e);
    float eps = 1.5;
    float hx = heightAt(p + vec2(eps, 0.0)) - heightAt(p - vec2(eps, 0.0));
    float hy = heightAt(p + vec2(0.0, eps)) - heightAt(p - vec2(0.0, eps));
    vec2 g = vec2(hx, hy) / (2.0 * eps);
    vec3 fd = foldDist(p);
    float brk = 0.35 + 0.65 * smoothstep(0.3, 0.62, fbm(p / 38.0 + vec2(2.0, 8.0)));
    float line = max(max(tent(fd.x, 1.4), tent(fd.y, 1.4)), tent(fd.z, 1.4)) * brk;
    float zone = crumpleZone(p);
    float worn = (1.0 - smoothstep(0.0, 0.05, abs(gnoise(p / 85.0)))) * zone;
    if (mode > 0.5) {
        float w = clamp(line * 0.85 + worn * 0.6, 0.0, 1.0);
        return vec4(w, clamp(g * 4.0, -1.0, 1.0) * 0.5 + 0.5, alpha);
    }
    float low = fbm(p / 260.0 + vec2(1.7, 4.2));
    vec3 col = mix(paper_light, paper_base, smoothstep(0.28, 0.72, low));
    float mott = fbm(p / 45.0 + vec2(4.0, 9.0));
    col = mix(col, paper_dark, smoothstep(0.55, 0.85, mott) * 0.35);
    float fiber = vnoise(vec2(p.x / 2.5, p.y / 38.0) + vec2(31.0, 0.0));
    col *= 0.975 + fiber * 0.045;
    for (int k = 0; k < 4; k++) {
        vec4 s = stains[k];
        if (s.z > 0.0) {
            float q = length((p - s.xy) / vec2(s.z, s.z * 0.78)) + (fbm(p / 30.0 + vec2(float(k) * 7.0, 3.0)) - 0.5) * 0.45;
            float inside = 1.0 - smoothstep(0.85, 1.0, q);
            float ring = exp(-pow((q - 0.98) / 0.035, 2.0));
            col = mix(col, paper_dark * vec3(0.9, 0.82, 0.72), clamp(inside * 0.2 + ring * 0.55, 0.0, 1.0) * s.w);
        }
    }
    float fox = smoothstep(0.3, 0.48, gnoise(p / 6.0 + vec2(50.0, 20.0))) * smoothstep(0.5, 0.78, fbm(p / 120.0 + vec2(9.0, 1.0)));
    col = mix(col, rim_color * 0.85, fox * 0.5);
    col = mix(col, paper_dark * 0.8, line * 0.32 + worn * 0.14);
    float age = 1.0 - smoothstep(0.0, 30.0 + fbm(p / 25.0) * 34.0, e);
    col = mix(col, rim_color, age * 0.6);
    float burn = 1.0 - smoothstep(0.0, 3.5, e);
    col = mix(col, rim_color * 0.5, burn * 0.85);
    vec3 n = normalize(vec3(-g * 7.0, 1.0));
    vec3 light = normalize(vec3(-0.45, -0.65, 0.9));
    float shade = dot(n, light) / light.z;
    col *= clamp(mix(1.0, shade, 0.85), 0.6, 1.2);
    col *= 1.0 - 0.14 * smoothstep(0.3, 0.75, length(uv - 0.5));
    return vec4(col, alpha);
}
