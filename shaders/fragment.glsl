varying vec2 v_texcoord;

uniform vec2 u_mouse;
uniform vec2 u_resolution;
uniform float u_pixelRatio;

/* common constants */
#ifndef PI
#define PI 3.1415926535897932384626433832795
#endif
#ifndef TWO_PI
#define TWO_PI 6.2831853071795864769252867665590
#endif

/* Coordinate and unit utils */
#ifndef FNC_COORD
#define FNC_COORD
vec2 coord(in vec2 p) {
    p = p / u_resolution.xy;
    // correct aspect ratio
    if (u_resolution.x > u_resolution.y) {
        p.x *= u_resolution.x / u_resolution.y;
        p.x += (u_resolution.y - u_resolution.x) / u_resolution.y / 2.0;
    } else {
        p.y *= u_resolution.y / u_resolution.x;
        p.y += (u_resolution.x - u_resolution.y) / u_resolution.x / 2.0;
    }
    // centering
    p -= 0.5;
    p *= vec2(-1.0, 1.0);
    return p;
}
#endif

#define st0 coord(gl_FragCoord.xy)
#define mx coord(u_mouse * u_pixelRatio)

/* signed distance functions */
float sdCircle(in vec2 st, in vec2 center) {
    return length(st - center) * 2.0;
}

/* Lemniscate of Bernoulli SDF using polar form: r^2 = a^2 * cos(2*theta) */
float sdLemniscate(vec2 p, float a) {
    float r = length(p);
    float theta = atan(p.y, p.x);
    float cos2theta = cos(2.0 * theta);

    // Only draw where cos(2theta) >= 0 (horizontal lobes)
    if (cos2theta < 0.0) return 1e5;

    float r_curve = a * sqrt(cos2theta);
    return r - r_curve;
}

/* antialiased step function */
float aastep(float threshold, float value) {
    float afwidth = length(vec2(dFdx(value), dFdy(value))) * 0.70710678118654757;
    return smoothstep(threshold - afwidth, threshold + afwidth, value);
}

/* Signed distance drawing methods */
float fill(in float x) { return 1.0 - aastep(0.0, x); }
float fill(float x, float size, float edge) {
    return 1.0 - smoothstep(size - edge, size + edge, x);
}

float stroke(in float d, in float t) { return (1.0 - aastep(t, abs(d))); }
float stroke(float x, float size, float w, float edge) {
    float d = smoothstep(size - edge, size + edge, x + w * 0.5) - smoothstep(size - edge, size + edge, x - w * 0.5);
    return clamp(d, 0.0, 1.0);
}

void main() {
    vec2 pixel = 1.0 / u_resolution.xy;
    vec2 st = st0 + 0.5;
    vec2 posMouse = mx * vec2(1., -1.) + 0.5;
    
    /* sdf Circle params for interaction */
    float circleSize = 0.005;
    float circleEdge = 0.50;
    
    /* sdf Circle for interaction */
    float sdfCircle = fill(
        sdCircle(st, posMouse),
        circleSize,
        circleEdge
    );
    
    // 1. Globe mask: 1 inside the globe, 0 outside, soft edge
    float globeMask = 1.0 - smoothstep(0.0, 0.1, sdCircle(st, posMouse));
    
    // 2. Gradient mask: 1 at the edge of the infinity shape, 0 far away
    float gradientMask = smoothstep(0.02, 0.25, abs(sdfCircle)); // 0.02 is near the edge, 0.25 is farther out
    
    // Lemniscate of Bernoulli
    vec2 p = st - 0.5;
    float a = 0.5; // size
    float d = sdLemniscate(p, a);

    // Use stroke for outline, modulated by sdfCircle (interaction)
    float sdf = stroke(d, 0.0, 0.08, sdfCircle) * 1.4;
    
    vec3 backgroundColor = vec3(0.0);
    vec3 glowColor1 = vec3(0.6, 0.63, 1.0);     // #99A1FF
    vec3 glowColor2 = vec3(1.0, 0.84, 0.8);     // #FFD5CC
    vec3 glowColor3 = vec3(0.63, 0.48, 0.99);   // #A07AFC
    vec3 strokeColor = vec3(1.0, 1.0, 1.0);     // white

    float glow = smoothstep(0.0, 0.5, sdf); // controls glow width

    // Create a gradient: 0.0 -> glowColor1, 0.5 -> glowColor2, 1.0 -> glowColor3
    vec3 glowGradient;
    if (glow < 0.5) {
        glowGradient = mix(glowColor1, glowColor2, glow * 2.0);
    } else {
        glowGradient = mix(glowColor2, glowColor3, (glow - 0.5) * 2.0);
    }

    // 3. Colors
    vec3 globeColor = vec3(0.7, 0.2, 1.0); // purple
    vec3 gradientColor = glowGradient;      // your multi-color gradient

    // 4. Start with background
    vec3 color = backgroundColor;

    // 5. Add globe color inside the globe
    color = mix(color, globeColor, globeMask);

    // 6. Add gradient color at the boundary of the infinity shape
    color = mix(color, gradientColor, gradientMask);

    // 7. Add the white stroke for the infinity shape
    color = mix(color, strokeColor, smoothstep(0.95, 1.0, sdf));
    
    gl_FragColor = vec4(color.rgb, 1.0);
}