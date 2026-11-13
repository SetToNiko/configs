// mpv user shader for the lock screen (loaded by lock-saver.sh).
// Each CELL x CELL block of the wallpaper becomes one 5x5 glyph, picked by the
// block's brightness and drawn in the block's colour. Bright cells twinkle:
// each one flares to a denser, whiter glyph now and then on its own clock,
// and a few cells flicker to random glyphs.
// Edits apply on the next lock. Test without locking:
//   mpv --loop-file=inf --video-unscaled=yes --glsl-shader=ascii.glsl ~/.cache/lock/loop.mkv

//!HOOK MAIN
//!BIND HOOKED
//!DESC ascii lock screen

#define CELL    12.0  // cell size in pixels; multiples of 6 keep glyph pixels sharp
#define FPS     30.0  // frame rate of the clip made by wallpaper-rotate
#define FLICKER 0.01  // share of cells showing a random glyph at any moment
#define BOOST   1.4   // glyph brightness (glyphs only cover part of each cell)
#define GLOW    0.06  // faint copy of the image behind the glyphs; 0 for pure ASCII

// Twinkle: only cells brighter than TW_LOW take part, fully from TW_HIGH up
#define TW_LOW   0.45
#define TW_HIGH  0.75
#define TW_SPEED 0.8   // average twinkles per second per cell (roughly)
#define TW_SHARP 16.0  // higher = shorter, sparkier flashes
#define TW_LIFT  0.35  // how much a flash raises brightness (denser glyph)
#define TW_WHITE 0.7   // how far a flash pushes the colour toward white

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 5x5 glyph packed into 25 bits, row by row from the bottom-right corner.
// uv is the position inside the cell: a 6x6 grid of 5 glyph pixels + 1 gap.
float glyph(int bits, vec2 uv) {
    ivec2 g = ivec2(floor(uv * 6.0));
    if (g.x > 4 || g.y > 4)
        return 0.0;
    int i = 24 - (g.x + 5 * g.y);
    return float((bits >> i) & 1);
}

vec4 hook() {
    vec2 px   = HOOKED_pos * HOOKED_size;
    vec2 cell = floor(px / CELL);
    vec2 uv   = fract(px / CELL);
    vec3 col  = HOOKED_tex((cell + 0.5) * CELL * HOOKED_pt).rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    float t = float(frame) / FPS;

    // Each bright cell gets its own phase and speed; raising a sine to a high
    // power turns it into brief flashes with long quiet gaps between them.
    float phase = hash(cell) * 6.2832;
    float speed = TW_SPEED * (0.5 + hash(cell + 31.7));
    float spark = pow(max(sin(t * speed * 3.1416 + phase), 0.0), TW_SHARP);
    spark *= smoothstep(TW_LOW, TW_HIGH, lum);
    lum += TW_LIFT * spark;
    col  = mix(col, vec3(1.0), TW_WHITE * spark);

    float tick = floor(t * 6.0);
    if (hash(cell + tick) > 1.0 - FLICKER)
        lum = hash(cell * 1.7 + tick);
    lum = clamp(lum, 0.0, 1.0);

    // darkest to brightest:  . : * o & 8 @ #
    int bits = 0;
    if (lum > 0.10) bits = 4096;
    if (lum > 0.20) bits = 65600;
    if (lum > 0.30) bits = 163153;
    if (lum > 0.40) bits = 15255086;
    if (lum > 0.50) bits = 13121101;
    if (lum > 0.60) bits = 15252014;
    if (lum > 0.70) bits = 13195790;
    if (lum > 0.80) bits = 11512810;

    return vec4(col * (glyph(bits, uv) * BOOST * (1.0 + 0.5 * spark) + GLOW), 1.0);
}
