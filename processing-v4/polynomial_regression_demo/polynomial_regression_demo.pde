// Curve vocabulary explorer with shuffled segments
// Segment degree order (by t from left to right):
//   1, 2, 3, 2, 4, 2, 3, 2, 1
//
// Behavior:
//   - Blue dotted curve is ALWAYS drawn.
//   - Press 1..4 to TOGGLE overlays of that degree.
//   - Press 0 to clear overlays (blue only).
//   - Press r to randomize to a new curve.
//
// Keys:
//   0 : blue curve only (no overlays)
//   1 : toggle degree 1 overlay
//   2 : toggle degree 2 overlay
//   3 : toggle degree 3 overlay
//   4 : toggle degree 4 overlay
//   r/R : randomize a new curve

int N = 800;                // number of sample points
float[] xs = new float[N];
float[] ys = new float[N];
int[] deg = new int[N];     // degree label for each point (1,2,3,4)

float minY, maxY;

// Which degrees are currently shown as overlays
boolean[] showDeg = new boolean[5]; // indices 1..4 used

// Segment scaling (randomized each time we generate a curve)
final int SEG_COUNT = 9;
float[] segScale = new float[SEG_COUNT];

void setup() {
  size(1000, 600);
  smooth(8);

  generateData();
  findYRange();

  noLoop();  // redraw only when something changes
}

void draw() {
  background(255);

  float left = 60;
  float right = width - 40;
  float top = 40;
  float bottom = height - 60;

  // Frame for curve
  stroke(200);
  noFill();
  rect(left, top, right - left, bottom - top);

  // --- Always draw blue dotted curve ---
  noStroke();
  fill(0, 0, 255);
  float rDot = 3;       // dot diameter
  int step = 2;         // skip every other sample for spacing

  for (int i = 0; i < N; i += step) {
    float px = map(i, 0, N - 1, left, right);
    float py = map(ys[i], minY, maxY, bottom, top);
    ellipse(px, py, rDot, rDot);
  }

  // --- Draw any active overlays for degrees 1..4 ---
  for (int d = 1; d <= 4; d++) {
    if (showDeg[d]) {
      int col;
      if (d == 1)      col = color(0);              // black
      else if (d == 2) col = color(0, 150, 0);      // green
      else if (d == 3) col = color(255, 140, 0);    // orange
      else             col = color(200, 0, 200);    // magenta

      drawDegreeSegments(d, col);
    }
  }

  // Legend under the graph area
  drawLegend();
}

// ------------------------------------------------------------
// Generate synthetic data with shuffled segment types
// Segment index:   0  1  2  3  4  5  6  7  8
// Degrees:         1  2  3  2  4  2  3  2  1
// ------------------------------------------------------------
void generateData() {
  int segCount = SEG_COUNT;

  // Randomize scale factors per segment (varies per degree)
  for (int seg = 0; seg < segCount; seg++) {
    int d = degreeForSeg(seg);
    float s;

    if (d == 1) {
      s = random(0.5, 1.5);
    } else if (d == 2) {
      s = random(0.8, 1.8);
    } else if (d == 3) {
      s = random(4.0, 8.0);
    } else { // d == 4
      s = random(8.0, 12.0);
    }
    segScale[seg] = s;
  }

  float yPrev = 0;     // last global y
  float anchor = 0;    // current segment anchor
  int prevSeg = -1;

  for (int i = 0; i < N; i++) {
    float t = (float)i / (N - 1);       // in [0,1]
    int seg = (int)(t * segCount);
    if (seg >= segCount) seg = segCount - 1;

    float localT = t * segCount - seg;  // local param in [0,1)

    int degree = degreeForSeg(seg);
    float scale = scaleForSeg(seg);
    float f = baseFunc(seg, localT);

    // Ensure continuity at segment boundaries
    if (seg != prevSeg) {
      anchor = (i == 0) ? 0 : (yPrev - scale * f);
    }

    float y = anchor + scale * f;

    xs[i] = t;
    ys[i] = y;
    deg[i] = degree;

    yPrev = y;
    prevSeg = seg;
  }
}

// ------------------------------------------------------------
// Base shape per segment (unscaled), as a function of localT in [0,1)
// ------------------------------------------------------------
float baseFunc(int seg, float u) {
  switch (seg) {
  case 0:
    // Degree 1: rising line
    return u;  // 0 -> 1

  case 1:
    // Degree 2: hill (∩)
    return u * (1.0 - u);  // 0 at ends, peak at 0.5

  case 2:
    // Degree 3: valley–hill–valley (two extrema)
    {
      float v = u;
      return v * (1.0 - v) * (v - 0.5);
    }

  case 3:
    // Degree 2: valley (U)
    return -u * (1.0 - u);

  case 4:
    // Degree 4: hill–valley–hill (wiggly quartic)
    {
      float v = u;
      return (v - 0.1) * (v - 0.3) * (v - 0.7) * (v - 0.9);
    }

  case 5:
    // Degree 2: smaller hill
    return 0.7 * u * (1.0 - u);

  case 6:
    // Degree 3: hill–valley–hill (flip of seg 2)
    {
      float v = u;
      return -v * (1.0 - v) * (v - 0.5);
    }

  case 7:
    // Degree 2: smaller valley
    return -0.7 * u * (1.0 - u);

  case 8:
    // Degree 1: gentle descending line
    return 1.0 - u;

  default:
    return 0;
  }
}

// ------------------------------------------------------------
// Degree per segment
// ------------------------------------------------------------
int degreeForSeg(int seg) {
  switch (seg) {
  case 0:
  case 8:
    return 1;
  case 1:
  case 3:
  case 5:
  case 7:
    return 2;
  case 2:
  case 6:
    return 3;
  case 4:
    return 4;
  default:
    return 1;
  }
}

// ------------------------------------------------------------
// Scale per segment (uses randomized segScale[])
// ------------------------------------------------------------
float scaleForSeg(int seg) {
  return segScale[seg];
}

// ------------------------------------------------------------
// Find Y range for mapping to canvas
// ------------------------------------------------------------
void findYRange() {
  minY = ys[0];
  maxY = ys[0];
  for (int i = 1; i < N; i++) {
    if (ys[i] < minY) minY = ys[i];
    if (ys[i] > maxY) maxY = ys[i];
  }
  if (abs(maxY - minY) < 1e-6) {
    maxY = minY + 1;
  }
}

// ------------------------------------------------------------
// Draw segments of a given degree with thick colored lines
// ------------------------------------------------------------
void drawDegreeSegments(int targetDegree, int col) {
  float left = 60;
  float right = width - 40;
  float top = 40;
  float bottom = height - 60;

  stroke(col);
  strokeWeight(4);
  noFill();

  for (int i = 1; i < N; i++) {
    if (deg[i] == targetDegree && deg[i - 1] == targetDegree) {
      float x1 = map(i - 1, 0, N - 1, left, right);
      float y1 = map(ys[i - 1], minY, maxY, bottom, top);
      float x2 = map(i, 0, N - 1, left, right);
      float y2 = map(ys[i], minY, maxY, bottom, top);
      line(x1, y1, x2, y2);
    }
  }
}

// ------------------------------------------------------------
// Legend below the graph area, with color swatches
// ------------------------------------------------------------
void drawLegend() {
  float left = 60;
  float right = width - 40;
  float bottom = height - 60;

  int x0 = (int)left;
  int y0 = (int)(bottom + 20);  // just below the graph
  int dy = 20;

  fill(255);
  stroke(0);
  rect(x0 - 10, y0 - 20, (int)(right - left) + 20, 110);

  textAlign(LEFT, CENTER);
  textSize(12);
  fill(0);
  text("Keys: 0 = blue only | 1–4 toggle degrees | r = randomize curve", x0, y0 - 5);

  int y = y0 + 15;

  int sw = 40;  // swatch width

  // Blue base curve
  noStroke();
  fill(0, 0, 255);
  rect(x0, y - 5, sw, 10);
  fill(0);
  text("blue dotted curve (base)", x0 + sw + 10, y);
  y += dy;

  // Degree 1
  noStroke();
  fill(0);
  rect(x0, y - 5, sw, 10);
  fill(0);
  text("degree 1 (linear-ish)  [key 1]  " + (showDeg[1] ? "(ON)" : "(off)"), x0 + sw + 10, y);
  y += dy;

  // Degree 2
  noStroke();
  fill(0, 150, 0);
  rect(x0, y - 5, sw, 10);
  fill(0);
  text("degree 2 (hills/valleys)  [key 2]  " + (showDeg[2] ? "(ON)" : "(off)"), x0 + sw + 10, y);
  y += dy;

  // Degree 3
  noStroke();
  fill(255, 140, 0);
  rect(x0, y - 5, sw, 10);
  fill(0);
  text("degree 3 (cubic combos)  [key 3]  " + (showDeg[3] ? "(ON)" : "(off)"), x0 + sw + 10, y);
  y += dy;

  // Degree 4
  noStroke();
  fill(200, 0, 200);
  rect(x0, y - 5, sw, 10);
  fill(0);
  text("degree 4 (quartic combos) [key 4]  " + (showDeg[4] ? "(ON)" : "(off)"), x0 + sw + 10, y);
}

// ------------------------------------------------------------
// Key handling
// ------------------------------------------------------------
void keyPressed() {
  boolean changed = false;

  if (key == '0') {
    // Reset to blue only
    for (int d = 1; d <= 4; d++) {
      showDeg[d] = false;
    }
    changed = true;
  } else if (key >= '1' && key <= '4') {
    int d = key - '0';
    showDeg[d] = !showDeg[d];  // toggle
    changed = true;
  } else if (key == 'r' || key == 'R') {
    generateData();
    findYRange();
    changed = true;
  }

  if (changed) {
    redraw();
  }
}
