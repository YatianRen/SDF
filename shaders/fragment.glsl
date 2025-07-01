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

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

void main() {
    vec2 pixel = 1.0 / u_resolution.xy;
    vec2 st = st0 + 0.5;
    vec2 posMouse = mx * vec2(1., -1.) + 0.5;
    
    float circleSize = 0.0001;
    float circleEdge = 0.6;
    float strokeWidth = 0.10;
    float baseStrokeEdge = 0.00;
    
    // SDF for the cursor globe
    float dGlobe = sdCircle(st, posMouse) - circleSize;
    float globeMask = 1.0 - smoothstep(0.0, circleEdge, dGlobe);
    
    // Lemniscate of Bernoulli
    vec2 p = st - 0.5;
    float a = 0.5; // size
    float dLemniscate = sdLemniscate(p, a);

    // Modulate the stroke's edge softness by the globe's SDF
    float modulatedEdge = baseStrokeEdge + 0.5 * globeMask * circleEdge;
    float strokeMask = stroke(dLemniscate, 0.0, strokeWidth, modulatedEdge);

    // st: normalized coordinates (0,0) top-left, (1,1) bottom-right
    vec2 start = vec2(0.2, 0.2); // gradient starts here
    vec2 end   = vec2(0.8, 0.8); // gradient ends here

    float gradT = dot((st - start), normalize(end - start)) / length(end - start);
    gradT = clamp(gradT, 0.0, 1.0);

    // Interpolate the gradient colors
    vec3 color1 = vec3(0.63, 0.48, 0.99);   // #A07AFC
    vec3 color2 = vec3(1.0, 0.84, 0.8);   // #FFD5CC
    vec3 color3 = vec3(0.6, 0.63, 1.0); //  #99A1FF

    vec3 strokeColor;
    if (gradT < 0.5) {
        strokeColor = mix(color1, color2, gradT * 2.0);
    } else {
        strokeColor = mix(color2, color3, (gradT - 0.5) * 2.0);
    }

    // For color compositing
    vec3 colorShape = strokeColor;
    vec3 colorGlobe = vec3(0.0); // fully transparent (black, but alpha will be 0)

    // Globe alpha: 0 everywhere (fully transparent)
    float globeAlpha = 0.0;

    // Start with black background
    vec3 color = vec3(0.0);
    // Add globe color everywhere, with alpha for transparency (no effect)
    color = mix(color, colorGlobe, globeAlpha);
    // Add stroke, modulated by globe
    color = mix(color, colorShape, strokeMask);

    gl_FragColor = vec4(color, 1.0);
}