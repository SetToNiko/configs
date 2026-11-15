// mpv user shader for the lock screen (loaded by lock-saver.sh).
// Each CELL x CELL block of the wallpaper becomes one 5x5 glyph, picked by the
// block's brightness and drawn in the theme colour closest to the block's
// colour. Bright cells twinkle in place: each one flares to a denser glyph
// in fg0 now and then on its own clock. Nothing else moves.
// lock-saver.sh fills in the theme palette (see THEME below) from
// ~/.config/colors/colors.sh each time the screen locks, so edits here and
// theme switches both apply on the next lock. wallpaper-rotate also uses
// this shader, with WALLPAPER defined, to render the desktop background: a
// still in the image's own colours. With DISSOLVE also defined (set by
// lock-saver for ascii-power), that still breaks apart over DISSOLVE seconds
// in the same jagged way the lock screen reveal builds up. Test without locking:
//   lock-saver           (run from a terminal; opens a window, Ctrl+C to quit)

//!HOOK MAIN
//!BIND HOOKED
//!DESC ascii lock screen

#define CELL    12.0  // cell size in pixels; multiples of 6 keep glyph pixels sharp
#define FPS     30.0  // frame rate of the clip made by wallpaper-rotate
#define BOOST   1.4   // glyph brightness (glyphs only cover part of each cell)
#define GLOW    0.06  // faint copy of the image behind the glyphs; 0 for pure ASCII

// Desktop background (WALLPAPER): no glow, a glyph in every cell, each in its
// cell's own hue at a readable brightness; glyph density shows light and dark.
#define WP_MIN   0.20  // brightness floor, so even black areas get a "."
#define WP_GAMMA 0.60  // below 1 lifts the shadows into denser glyphs
#define WP_DIM   0.65  // glyph brightness in the darkest cells (1.0 in the brightest)

// Theme palette. lock-saver.sh replaces the THEME line with the current
// scheme's colours (and the reveal or dissolve time); the fallback below is
// used when the shader runs on its own.
// THEME
#ifndef THEME_N
#define THEME_N  4
#define THEME_FG vec3(0.85)
const vec3 THEME[THEME_N] = vec3[](vec3(0.35), vec3(0.5), vec3(0.65), vec3(0.85));
#endif

// Twinkle: only cells brighter than TW_LOW take part, fully from TW_HIGH up
#define TW_LOW   0.33
#define TW_HIGH  0.60
#define TW_SPEED 1.0   // average twinkles per second per cell (roughly)
#define TW_SHARP 16.0  // higher = shorter, sparkier flashes
#define TW_LIFT  0.35  // how much a flash raises brightness (denser glyph)
#define TW_WHITE 0.7   // how far a flash pushes the colour toward fg0

// Reveal: when the screen locks, characters pop in in random order, in uneven
// bursts and small clumps rather than a smooth, even fade. Lock only.
#ifndef REVEAL         // lock-saver.sh sets this per lock (4s first lock, 2s after/wake)
#define REVEAL   4.0   // seconds until the whole image is shown, fade included; 0 = off
#endif
#define R_FADE   0.06  // seconds each character takes to appear; small = pops in
#define R_JITTER 1.0   // 1 = fully random order; lower mixes in brightest-first
#define R_STEP   0.12  // characters arrive in bursts this many seconds apart (avg)
#define R_CLUMP  4.0   // patches of up to this many cells tend to arrive together
#define R_BRIGHT 0.8   // cells at least this bright count as "brightest" (go first)
// The shutdown dissolve (DISSOLVE, seconds) reuses the R_ settings in reverse.

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// The palette entry closest to c. Hue and saturation count for more than
// brightness (glyph density already shows brightness), so a dim red cell
// still picks the theme's red rather than a grey.
vec3 nearest(vec3 c) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    vec3 cn = c / max(l, 0.02);
    vec3 best = THEME[0];
    float bestd = 1e9;
    for (int i = 0; i < THEME_N; i++) {
        vec3 p = THEME[i];
        float pl = dot(p, vec3(0.299, 0.587, 0.114));
        vec3 dc = cn - p / max(pl, 0.02);
        float d = 4.0 * dot(dc, dc) + (l - pl) * (l - pl);
        if (d < bestd) { bestd = d; best = p; }
    }
    return best;
}

// When this cell pops in (or out) during a reveal/dissolve lasting `total`
// seconds, R_FADE included. Order is random: half per cell, half per patch of
// cells, so neighbours sometimes go together in clumps; R_JITTER below 1
// blends in a brightest-first order. Times are grouped into bursts R_STEP
// apart, each nudged by its own random offset, so the stream stutters.
float pop_time(vec2 cell, float lum, float total) {
    float noise = mix(hash(cell + 7.3), hash(floor(cell / R_CLUMP) + 3.1), 0.5);
    float order = mix(1.0 - min(lum / R_BRIGHT, 1.0), noise, R_JITTER);
    float span  = max(total - R_FADE, 0.0);
    float at    = order * span;
    float burst = floor(at / R_STEP);
    return min(burst * R_STEP + hash(vec2(burst, 5.7)) * R_STEP * 0.8, span);
}

// 5x5 glyph packed into 25 bits, top-left pixel in the highest bit, row by row.
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

    float glow = GLOW, boost = BOOST;
    float t = float(frame) / FPS;   // mpv restarts each time, so t starts at 0
#ifndef WALLPAPER
    // Reveal: blank until this cell's pop time (brightness from the image,
    // before any twinkle)
    float shown = REVEAL > 0.0
        ? clamp((t - pop_time(cell, lum, REVEAL)) / R_FADE, 0.0, 1.0)
        : 1.0;

    // Each bright cell gets its own phase and speed; raising a sine to a high
    // power turns it into brief flashes with long quiet gaps between them.
    float phase = hash(cell) * 6.2832;
    float speed = TW_SPEED * (0.5 + hash(cell + 31.7));
    float spark = pow(max(sin(t * speed * 3.1416 + phase), 0.0), TW_SHARP);
    spark *= smoothstep(TW_LOW, TW_HIGH, lum);
    lum += TW_LIFT * spark;
    col  = mix(nearest(col), THEME_FG, TW_WHITE * spark);
#else
    float spark = 0.0;   // desktop background: still, full colour
#ifdef DISSOLVE
    // Shutdown: each cell vanishes at its pop time
    float shown = 1.0 - clamp((t - pop_time(cell, lum, DISSOLVE)) / R_FADE, 0.0, 1.0);
#else
    float shown = 1.0;
#endif
    glow = 0.0;
    boost = 1.0;
    lum = WP_MIN + (1.0 - WP_MIN) * pow(clamp(lum, 0.0, 1.0), WP_GAMMA);
    // Scale the colour so its strongest channel is full: keeps the hue, drops
    // the brightness, which WP_DIM..1 then puts back in a narrower range.
    float peak = max(max(col.r, col.g), col.b);
    col = col / max(peak, 0.04) * mix(WP_DIM, 1.0, lum);
#endif

    lum = clamp(lum, 0.0, 1.0);

    // darkest to brightest:  . : - + = * @ #   (plain ASCII only)
    int bits = 0;
    if (lum > 0.10) bits = 4;         // .
    if (lum > 0.20) bits = 131200;    // :
    if (lum > 0.30) bits = 14336;     // -
    if (lum > 0.40) bits = 145536;    // +
    if (lum > 0.50) bits = 459200;    // =
    if (lum > 0.60) bits = 4897444;   // *
    if (lum > 0.70) bits = 15261199;  // @
    if (lum > 0.80) bits = 11512810;  // #

    // Characters on black (plus the faint glow on the lock screen); cells not
    // yet revealed, or already dissolved, are black
    return vec4(col * (glyph(bits, uv) * boost * (1.0 + 0.5 * spark) + glow) * shown, 1.0);
}
