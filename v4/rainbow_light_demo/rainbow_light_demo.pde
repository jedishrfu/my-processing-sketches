/**
 * Gary Seven Light Capsules — Thin, Non-overlapping, Binary Flash
 * Processing (Java mode)
 *
 * Controls:
 *   v / h  — toggle vertical / horizontal bars
 *   r      — reshuffle positions & phases
 *   - / =  — adjust PPI (size calibration)
 *   [ / ]  — slower / faster flashing (global)
 *   s      — save PNG frame
 */

ArrayList<Capsule> caps;
boolean showV = true, showH = true;

// Fewer bars by default
int numV = 10;   // vertical capsules (left half)
int numH = 8;    // horizontal capsules (right half)

// Physical sizes (cm)
final float CM_THIN = 0.5f;
final float CM_LONG = 5.0f;

// Display scaling
float ppi = 96;          // adjust with - / =
float speedScale = 1.0f; // global flash speed multiplier

// Rainbow palette (HSB)
int[] rainbow;

void settings() {
  size(1000, 620, P2D);
  smooth(8);
}

void setup() {
  surface.setTitle("Gary Seven — Thin Capsules (Binary Flash, No Overlap)");
  colorMode(HSB, 360, 100, 100, 255);
  noStroke();

  rainbow = new int[] {
    color(0,   100, 100),  // R
    color(30,  100, 100),  // O
    color(60,  100, 100),  // Y
    color(120, 100, 100),  // G
    color(240, 100, 100),  // B
    color(275, 90,  90),   // I
    color(300, 80,  100)   // V
  };

  randomizeLayout();
}

void draw() {
  background(0);

  float thinPx = cmToPx(CM_THIN);
  float longPx = cmToPx(CM_LONG);

  // Draw capsules (binary ON/OFF — no fading)
  for (Capsule c : caps) {
    if ((c.vertical && showV) || (!c.vertical && showH)) {
      c.drawBinary(thinPx, longPx);
    }
  }

  // HUD
  fill(255, 200);
  textFont(createFont("Arial", 12));
  text(
    "V:" + (showV ? "ON" : "OFF") + "  H:" + (showH ? "ON" : "OFF") +
    "   PPI=" + nf(ppi, 0, 1) + "  Speed x" + nf(speedScale, 1, 2) +
    "   Keys: [v][h] toggle  [r] reshuffle  [-][=] PPI  [[ ][ ]] speed  [s] save",
    12, height - 12
  );
}

void keyPressed() {
  if (key == 'v' || key == 'V') showV = !showV;
  if (key == 'h' || key == 'H') showH = !showH;
  if (key == 'r' || key == 'R') randomizeLayout();
  if (key == '-') ppi = max(50, ppi - 1);
  if (key == '=') ppi = min(220, ppi + 1);
  if (key == '[') speedScale = max(0.25, speedScale * 0.9);
  if (key == ']') speedScale = min(4.0, speedScale * 1.1);
  if (key == 's' || key == 'S') saveFrame("gary7_binary-####.png");
}

float cmToPx(float cm) {
  return cm / 2.54f * ppi;
}

void randomizeLayout() {
  caps = new ArrayList<Capsule>();

  // Non-overlapping lanes
  // Left half for vertical; right half for horizontal
  float leftW = width * 0.48f;
  float rightX = width * 0.52f;
  float rightW = width - rightX;

  // Build evenly spaced lanes with a little jitter inside each lane (still no overlap)
  // Vertical: unique X lanes, full height
  for (int i = 0; i < numV; i++) {
    float laneX = map(i + 0.5f, 0, numV, 20, leftW - 20);
    float x = laneX + random(-6, 6); // small jitter but lanes do not overlap
    float y = height * 0.5f;         // center; drawn by size later
    int col = rainbow[i % rainbow.length];

    // Square-wave flashing parameters (in frames)
    int period = (int)random(28, 80);     // each bar has its own blink rate
    int phase  = (int)random(period);     // and its own phase
    float duty = 0.5f;                    // exact 50% duty cycle

    caps.add(new Capsule(true, x, y, col, period, phase, duty));
  }

  // Horizontal: unique Y lanes, full width (but in right half)
  for (int j = 0; j < numH; j++) {
    float laneY = map(j + 0.5f, 0, numH, 30, height - 30);
    float y = laneY + random(-6, 6);
    float x = rightX + rightW * 0.5f;
    int col = rainbow[j % rainbow.length];

    int period = (int)random(28, 80);
    int phase  = (int)random(period);
    float duty = 0.5f;

    caps.add(new Capsule(false, x, y, col, period, phase, duty));
  }
}

class Capsule {
  boolean vertical;  // true: 0.5 cm × 5 cm (tall); false: 5 cm × 0.5 cm (wide)
  float cx, cy;
  int col;
  int period;   // frames per full ON/OFF cycle
  int phase;    // frame offset
  float duty;   // fraction ON in [0,1] (0.5 = equal ON/OFF)

  Capsule(boolean vertical, float cx, float cy, int col, int period, int phase, float duty) {
    this.vertical = vertical;
    this.cx = cx;
    this.cy = cy;
    this.col = col;
    this.period = max(2, period);
    this.phase = phase % this.period;
    this.duty = constrain(duty, 0.05f, 0.95f);
  }

  void drawBinary(float thinPx, float longPx) {
    // Square wave: strictly ON or OFF
    int p = max(2, round(period / speedScale));
    int f = (frameCount + phase) % p;
    boolean on = f < (int)(p * duty);

    if (!on) return;

    float w = vertical ? thinPx : longPx;
    float h = vertical ? longPx : thinPx;
    float r = min(w, h) * 0.45f;

    // Solid capsule (no fade). Slight fixed halo to look luminous.
    // Core
    fill(col);
    roundedRectCenter(cx, cy, w, h, r);

    // Tight halo (constant when ON)
    fill(hue(col), saturation(col), 100, 80);
    roundedRectCenter(cx, cy, w + 6, h + 6, r + 2.5f);
  }
}

void roundedRectCenter(float cx, float cy, float w, float h, float r) {
  pushMatrix();
  translate(cx, cy);
  rectMode(CENTER);
  rect(0, 0, w, h, r);
  popMatrix();
}
