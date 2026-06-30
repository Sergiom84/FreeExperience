#version 460 core
#include <flutter/runtime_effect.glsl>

// Océano raymarched para la bienvenida (atardecer). Técnica de altura por
// octavas + trazado por bisección (estilo "Seascape"), reescrita y reducida a
// una sola paleta. Pensado para correr a pantalla completa en móvil.

precision highp float;

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

const int TRACE = 7;
const int OCT_GEO = 3;
const int OCT_NRM = 4;

const mat2 OCTM = mat2(1.6, 1.2, -1.2, 1.6);
const float SEA_HEIGHT = 0.6;
const float SEA_CHOPPY = 4.0;
const float SEA_FREQ = 0.16;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i), b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float snoise(vec2 p) { return noise(p) * 2.0 - 1.0; }

float seaOctave(vec2 uv, float choppy) {
  uv += snoise(uv);
  vec2 wv = 1.0 - abs(sin(uv));
  vec2 swv = abs(cos(uv));
  wv = mix(wv, swv, wv);
  return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

float seaMap(vec3 p, float t, int oct) {
  float freq = SEA_FREQ, amp = SEA_HEIGHT, choppy = SEA_CHOPPY;
  vec2 uv = p.xz; uv.x *= 0.75;
  float h = 0.0;
  for (int i = 0; i < 8; i++) {
    if (i >= oct) break;
    float d = seaOctave((uv + t) * freq, choppy);
    d += seaOctave((uv - t) * freq, choppy);
    h += d * amp;
    uv *= OCTM; freq *= 1.9; amp *= 0.22;
    choppy = mix(choppy, 1.0, 0.2);
  }
  return p.y - h;
}

vec3 seaNormal(vec3 p, float eps, float t) {
  vec3 n;
  n.y = seaMap(p, t, OCT_NRM);
  n.x = seaMap(vec3(p.x + eps, p.y, p.z), t, OCT_NRM) - n.y;
  n.z = seaMap(vec3(p.x, p.y, p.z + eps), t, OCT_NRM) - n.y;
  n.y = eps;
  return normalize(n);
}

void heightTrace(vec3 ori, vec3 dir, float t, out vec3 p) {
  float tm = 0.0, tx = 1000.0;
  float hx = seaMap(ori + dir * tx, t, OCT_GEO);
  if (hx > 0.0) { p = ori + dir * tx; return; }
  float hm = seaMap(ori, t, OCT_GEO);
  float tmid = 0.0;
  for (int i = 0; i < TRACE; i++) {
    tmid = mix(tm, tx, hm / (hm - hx));
    p = ori + dir * tmid;
    float hmid = seaMap(p, t, OCT_GEO);
    if (hmid < 0.0) { tx = tmid; hx = hmid; } else { tm = tmid; hm = hmid; }
  }
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - uSize * 0.5) / uSize.y;
  uv.y = -uv.y; // Flutter es Y-down; arriba = positivo.

  float t = 1.0 + uTime * 0.8;

  // Paleta atardecer.
  vec3 skyTop = vec3(0.10, 0.06, 0.24);
  vec3 skyHor = vec3(0.98, 0.46, 0.16);
  vec3 seaBase = vec3(0.05, 0.04, 0.10);
  vec3 seaWater = vec3(0.80, 0.45, 0.22);
  vec3 sunCol = vec3(1.0, 0.78, 0.35);
  vec3 sunDir = normalize(vec3(0.0, 0.10, -1.0));

  // Cámara mirando ligeramente hacia abajo; horizonte ~58%.
  vec3 ori = vec3(0.0, 3.5, uTime * 0.5);
  vec3 rd = normalize(vec3(uv.x, uv.y + 0.08, -1.6));

  // Cielo.
  float elev = clamp(rd.y, 0.0, 1.0);
  vec3 sky = mix(skyHor, skyTop, pow(elev, 0.42));
  float sd = max(dot(rd, sunDir), 0.0);
  sky += sunCol * pow(sd, 380.0) * 5.0;
  sky += sunCol * pow(sd, 22.0) * 0.25;
  sky += sunCol * pow(sd, 5.0) * 0.09;
  sky += sunCol * exp(-abs(rd.y) * 22.0) * 0.11;
  // Estrellas en la parte alta.
  float sn = hash(floor(rd.xy * 300.0));
  float star = pow(clamp(sn - 0.9955, 0.0, 1.0) * 222.0, 2.0);
  star *= 0.7 + 0.3 * sin(uTime * 1.5 + sn * 30.0);
  sky += vec3(star) * smoothstep(0.06, 0.25, rd.y) * 0.8;

  vec3 col;
  if (rd.y < -0.005) {
    vec3 p;
    heightTrace(ori, rd, t, p);
    vec3 dist = p - ori;
    float eps = dot(dist, dist) * 0.1 / uSize.x;
    vec3 n = seaNormal(p, eps, t);
    float fres = pow(1.0 - max(dot(n, -rd), 0.0), 3.0) * 0.65;

    vec3 refl = reflect(rd, n);
    float rel = clamp(refl.y, 0.0, 1.0);
    vec3 reflSky = mix(skyHor, skyTop, pow(rel, 0.42));
    float rsun = max(dot(refl, sunDir), 0.0);
    reflSky += sunCol * pow(rsun, 140.0) * 3.0;
    reflSky += sunCol * pow(rsun, 18.0) * 0.1;

    float diff = pow(dot(n, sunDir) * 0.4 + 0.6, 80.0);
    vec3 refr = seaBase + diff * seaWater * 0.12;
    vec3 water = mix(refr, reflSky, fres);

    float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
    water += seaWater * (p.y - SEA_HEIGHT) * 0.18 * atten;

    float spec = pow(max(dot(reflect(-sunDir, n), -rd), 0.0), 60.0);
    water += sunCol * spec;

    // Centelleo.
    float gl = noise(p.xz * 18.0 + vec2(uTime * 0.55, uTime * 0.22));
    water += sunCol * smoothstep(0.94, 1.0, gl) * 0.09;

    // Niebla hacia el horizonte.
    water = mix(water, skyHor, 1.0 - exp(-length(dist) * 0.012 * 1.6));

    float seaMix = pow(smoothstep(0.0, -0.05, rd.y), 0.3);
    col = mix(sky, water, seaMix);
  } else {
    col = sky;
  }

  col = pow(clamp(col, 0.0, 1.0), vec3(0.78));
  fragColor = vec4(col, 1.0);
}
