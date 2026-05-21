// Birch–Swinnerton-Dyer Conjecture (conceptual visualizer)
// with categorized dropdown, hover highlight, scrollable list, prev/next buttons,
// and a mini thumbnail preview of the selected curve.
//
// Controls:
//   Dropdown: choose a famous curve (short Weierstrass form).
//   < Prev / Next > buttons: cycle between curves (skipping headers).
//   Q/A : decrease/increase a  → moves to "Custom (keyboard)"
//   W/S : decrease/increase b  → moves to "Custom (keyboard)"
//   R   : random (a,b) in [-5,5] → Custom
//
// NOTE: This is conceptual only — not a serious numerical BSD tool.

import processing.event.MouseEvent;

int a = -1;
int b = 0;

int[] primes = {2, 3, 5, 7, 11, 13, 17, 19, 23};

float xMin = -3;
float xMax =  3;
float yMin = -3;
float yMax =  3;

ArrayList<PVector> integerPoints;

// ---- Curve list with categories / ranks ----
String[] curveNames;
String[] curveCategory;
int[] curveA;
int[] curveB;
int[] curveRank;        // -1 = unknown / custom / header
boolean[] curveIsHeader;

int selectedCurve = 0;  // index; 0 = Custom
boolean dropdownOpen = false;

// Dropdown UI / scrolling
int panelX0 = 580;
int dropdownX = panelX0 + 10;
int dropdownY = 120;
int dropdownW = 260;
int dropdownH = 24;

int maxVisibleItems = 8;
int scrollOffset = 0;    // first visible index in dropdown
int hoveredIndex = -1;

// Prev / Next buttons
int prevBtnX = panelX0 + 10;
int prevBtnY = dropdownY + dropdownH + 10;
int prevBtnW = 80;
int prevBtnH = 24;

int nextBtnX = prevBtnX + prevBtnW + 10;
int nextBtnY = prevBtnY;
int nextBtnW = 80;
int nextBtnH = 24;

void setup() {
  size(1000, 600);
  surface.setTitle("Birch–Swinnerton-Dyer (conceptual) visualizer");
  integerPoints = new ArrayList<PVector>();

  // Curve list (short Weierstrass y^2 = x^3 + a x + b)
  // Rank values are rough "expected" narrative labels, not computed here.
  // 0: Custom
  curveNames    = new String[] {
    "Custom (keyboard)",
    "— Simple demo curves (small coefficients) —",
    "C1: y² = x³ - x              (rank ≈ 1)",
    "C2: y² = x³ - x + 1          (rank ≈ 1)",
    "C3: y² = x³ - 4x             (rank ≈ 0)",
    "— Congruent-number-type / related —",
    "C4: y² = x³ - 4x + 1         (rank ≈ 0)",
    "C5: y² = x³ + x - 1          (rank ≈ 1)",
    "C6: y² = x³ - 2x + 2         (rank ≈ 1)"
  };
  curveCategory = new String[] {
    "Custom",
    "Header: Simple demo",
    "Simple demo",
    "Simple demo",
    "Simple demo",
    "Header: Congruent",
    "Congruent-ish",
    "Congruent-ish",
    "Congruent-ish"
  };
  curveIsHeader = new boolean[] {
    false,
    true,
    false,
    false,
    false,
    true,
    false,
    false,
    false
  };

  curveA = new int[] {
    -1,    // Custom (initial a)
    0,     // header
    -1,    // C1
    -1,    // C2
    -4,    // C3
    0,     // header
    -4,    // C4
     1,    // C5
    -2     // C6
  };

  curveB = new int[] {
     0,    // Custom (initial b)
     0,    // header
     0,    // C1
     1,    // C2
     0,    // C3
     0,    // header
     1,    // C4
    -1,    // C5
     2     // C6
  };

  curveRank = new int[] {
    -1,  // custom
    -1,  // header
     1,  // C1
     1,  // C2
     0,  // C3
    -1,  // header
     0,  // C4
     1,  // C5
     1   // C6
  };

  // Start on C1
  selectedCurve = 2;
  applyCurve(selectedCurve);
}

void draw() {
  background(255);

  // Left pane: big curve plot
  drawAxes();
  drawEllipticCurve();
  drawIntegerPoints();

  // Right pane: info, thumbnail, dropdown, controls
  drawInfoPane();
}

// ---- Left pane (plot) ----

void drawAxes() {
  pushMatrix();
  stroke(220);
  fill(0);

  // Plot region: x from 50..550, y from 50..550
  for (int gx = -3; gx <= 3; gx++) {
    float sx = worldToScreenX(gx);
    stroke(230);
    line(sx, worldToScreenY(yMin), sx, worldToScreenY(yMax));
  }
  for (int gy = -3; gy <= 3; gy++) {
    float sy = worldToScreenY(gy);
    stroke(230);
    line(worldToScreenX(xMin), sy, worldToScreenX(xMax), sy);
  }

  // Axes
  stroke(0);
  strokeWeight(2);
  line(worldToScreenX(xMin), worldToScreenY(0), worldToScreenX(xMax), worldToScreenY(0)); // x-axis
  line(worldToScreenX(0), worldToScreenY(yMin), worldToScreenX(0), worldToScreenY(yMax)); // y-axis

  // Labels
  textSize(12);
  textAlign(CENTER, TOP);
  for (int gx = -3; gx <= 3; gx++) {
    float sx = worldToScreenX(gx);
    text(gx, sx, worldToScreenY(0) + 3);
  }
  textAlign(LEFT, CENTER);
  for (int gy = -3; gy <= 3; gy++) {
    float sy = worldToScreenY(gy);
    text(gy, worldToScreenX(0) + 4, sy);
  }

  popMatrix();
}

void drawEllipticCurve() {
  stroke(0, 0, 150);
  strokeWeight(1.5);
  noFill();

  float step = 0.01;

  // Upper branch
  beginShape();
  for (float x = xMin; x <= xMax; x += step) {
    float rhs = x*x*x + a * x + b;
    if (rhs >= 0) {
      float y = sqrt(rhs);
      float sx = worldToScreenX(x);
      float sy = worldToScreenY(y);
      vertex(sx, sy);
    } else {
      endShape();
      beginShape();
    }
  }
  endShape();

  // Lower branch
  beginShape();
  for (float x = xMin; x <= xMax; x += step) {
    float rhs = x*x*x + a * x + b;
    if (rhs >= 0) {
      float y = -sqrt(rhs);
      float sx = worldToScreenX(x);
      float sy = worldToScreenY(y);
      vertex(sx, sy);
    } else {
      endShape();
      beginShape();
    }
  }
  endShape();
}

void drawIntegerPoints() {
  fill(200, 0, 0);
  stroke(0);
  strokeWeight(1);

  for (PVector p : integerPoints) {
    float sx = worldToScreenX(p.x);
    float sy = worldToScreenY(p.y);
    ellipse(sx, sy, 8, 8);
  }
}

// ---- Right pane (info + thumbnail + controls) ----

void drawInfoPane() {
  int x0 = panelX0;
  int x1 = width - 20;

  // Background panel
  noStroke();
  fill(245);
  rect(x0, 20, x1 - x0, height - 40);

  fill(0);
  textAlign(LEFT, TOP);
  textSize(16);
  text("Birch–Swinnerton-Dyer (toy visualizer)", x0 + 10, 30);

  // Mini thumbnail of the curve
  drawCurveThumbnail(x0 + 280, 50, 160, 100);

  // Textual info (numbers / explanation)
  float y = 60;
  textSize(13);
  textAlign(LEFT, TOP);
  text("Category: " + curveCategory[selectedCurve], x0 + 10, y);
  y += 18;

  if (curveRank[selectedCurve] >= 0) {
    text("Narrative rank label: ≈ " + curveRank[selectedCurve], x0 + 10, y);
    y += 18;
  } else {
    text("Narrative rank label: (custom / header)", x0 + 10, y);
    y += 18;
  }

  y = 190;
  text("Selected: " + curveNames[selectedCurve], x0 + 10, y);
  y += 20;

  text("Elliptic curve (short form):  y² = x³ + a x + b", x0 + 10, y);
  y += 18;
  text("a = " + a + "   (Q/A to change)", x0 + 10, y);
  y += 18;
  text("b = " + b + "   (W/S to change)", x0 + 10, y);
  y += 18;
  text("R: random (a,b) in [-5,5] → Custom", x0 + 10, y);
  y += 24;

  long disc = discriminant(a, b);
  text("Discriminant Δ = " + disc + (disc == 0 ? "  (singular!)" : ""), x0 + 10, y);
  y += 24;

  text("Integer rational points (|x|,|y| ≤ 10): " + integerPoints.size(), x0 + 10, y);
  y += 20;

  float Lapprox = partialLAt1(a, b);
  text("Toy partial L(E,1) ≈ " + nf(Lapprox, 1, 4), x0 + 10, y);
  y += 10;

  // Bar visual
  float barBaseY = y + 80;
  float barX1 = x0 + 40;
  float barX2 = x0 + 140;

  stroke(0);
  fill(220);
  rect(x0 + 10, y, x1 - x0 - 20, 90);

  float nPts = max(1, integerPoints.size());
  float barHeightPts = min(80, 5 * nPts);
  float barHeightL   = min(80, abs(80 / max(Lapprox, 0.1)));

  // Points bar
  fill(200, 0, 0);
  rect(barX1, barBaseY - barHeightPts, 30, barHeightPts);
  fill(0);
  textAlign(CENTER, TOP);
  text("# points", barX1 + 15, barBaseY + 5);

  // 1/L bar
  fill(0, 0, 200);
  rect(barX2, barBaseY - barHeightL, 30, barHeightL);
  fill(0);
  text("1 / L", barX2 + 15, barBaseY + 5);

  y += 110;

  textAlign(LEFT, TOP);
  String expl =
    "BSD (very roughly):\n" +
    " • The order of the zero of L(E,s) at s = 1 equals the rank of E(Q).\n" +
    " • Higher rank ⇒ more rational points ⇒ L(E,1) tends to be 'more zero'.\n\n" +
    "Here we:\n" +
    " • Draw E over the reals (left pane).\n" +
    " • Mark integer rational points.\n" +
    " • Show a toy partial Euler product as a stand-in for L(E,1).\n\n" +
    "Use the dropdown or Prev/Next buttons to flip between families.\n" +
    "This sketch is conceptual only — not a rigorous numerical tool.";

  text(expl, x0 + 10, y, x1 - x0 - 20, height - y - 20);

  // Draw controls LAST so dropdown overlays everything else
  drawCurveControls();
}

// Mini thumbnail of current curve in a small box
void drawCurveThumbnail(int x, int y, int w, int h) {
  pushStyle();
  stroke(0);
  fill(255);
  rect(x, y, w, h);

  // Local coordinate mapping for thumbnail
  float step = 0.02;

  // Upper branch
  stroke(0, 0, 150);
  noFill();
  beginShape();
  for (float X = xMin; X <= xMax; X += step) {
    float rhs = X*X*X + a * X + b;
    if (rhs >= 0) {
      float Y = sqrt(rhs);
      float sx = map(X, xMin, xMax, x + 5, x + w - 5);
      float sy = map(Y, yMin, yMax, y + h - 5, y + 5);
      vertex(sx, sy);
    } else {
      endShape();
      beginShape();
    }
  }
  endShape();

  // Lower branch
  beginShape();
  for (float X = xMin; X <= xMax; X += step) {
    float rhs = X*X*X + a * X + b;
    if (rhs >= 0) {
      float Y = -sqrt(rhs);
      float sx = map(X, xMin, xMax, x + 5, x + w - 5);
      float sy = map(Y, yMin, yMax, y + h - 5, y + 5);
      vertex(sx, sy);
    } else {
      endShape();
      beginShape();
    }
  }
  endShape();

  popStyle();
}

// ---- Dropdown & controls ----

void drawCurveControls() {
  textSize(13);
  textAlign(LEFT, CENTER);
  fill(0);
  text("Curve selection:", dropdownX, dropdownY - 18);

  // MAIN BOX
  stroke(0);
  strokeWeight(1.2);
  fill(255);
  rect(dropdownX, dropdownY, dropdownW, dropdownH, 4);

  fill(0);
  String label = curveNames[selectedCurve];
  textAlign(LEFT, CENTER);
  text(label, dropdownX + 8, dropdownY + dropdownH/2);

  // Triangle
  float tx = dropdownX + dropdownW - 16;
  float ty = dropdownY + dropdownH/2;
  fill(0);
  noStroke();
  triangle(tx - 6, ty - 3, tx + 6, ty - 3, tx, ty + 5);

  // DROPDOWN LIST
  hoveredIndex = -1;

  if (dropdownOpen) {

    int items = curveNames.length;

    int visible = min(items - scrollOffset, maxVisibleItems);
    int menuHeight = dropdownH * visible;

    // Background panel
    stroke(0);
    strokeWeight(1.2);
    fill(250);
    rect(dropdownX, dropdownY + dropdownH, dropdownW, menuHeight, 4);

    // Scrollbar if needed
    int barX = dropdownX + dropdownW + 4;
    int barY = dropdownY + dropdownH;
    int barW = 8;
    int barH = dropdownH * maxVisibleItems;

    if (items > maxVisibleItems) {
      fill(240);
      stroke(0);
      rect(barX, barY, barW, barH, 4);

      float thumbH = max(20, barH * (float)visible / items);
      float thumbY = barY;
      float denom = (float)(items - maxVisibleItems);
      if (denom < 1) denom = 1;
      thumbY += (barH - thumbH) * (float)scrollOffset / denom;

      fill(180);
      noStroke();
      rect(barX + 1, thumbY + 1, barW - 2, thumbH - 2, 4);
    }

    // Draw items with hover highlight
    for (int i = 0; i < visible; i++) {
      int idx = scrollOffset + i;
      float iy = dropdownY + dropdownH * (i + 1);

      boolean hovering = (mouseX >= dropdownX && mouseX <= dropdownX + dropdownW &&
                          mouseY >= iy && mouseY <= iy + dropdownH);

      if (curveIsHeader[idx]) {
        if (hovering) {
          fill(220);
        } else {
          fill(230);
        }
      } else {
        if (idx == selectedCurve) {
          fill(210);
        } else if (hovering) {
          fill(235);
        } else {
          fill(255);
        }
      }
      stroke(0);
      rect(dropdownX, iy, dropdownW, dropdownH);

      if (hovering) hoveredIndex = idx;

      // Item text
      textAlign(LEFT, CENTER);
      if (curveIsHeader[idx]) {
        fill(80);
      } else {
        fill(0);
      }
      text(curveNames[idx], dropdownX + 8, iy + dropdownH/2);
    }
  }

  // Prev / Next buttons
  fill(240);
  stroke(0);
  rect(prevBtnX, prevBtnY, prevBtnW, prevBtnH, 4);
  rect(nextBtnX, nextBtnY, nextBtnW, nextBtnH, 4);

  fill(0);
  textAlign(CENTER, CENTER);
  text("< Prev", prevBtnX + prevBtnW/2, prevBtnY + prevBtnH/2);
  text("Next >", nextBtnX + nextBtnW/2, nextBtnY + nextBtnH/2);
}

// ---- Arithmetic & BSD toy calculations ----

void recomputeIntegerPoints() {
  integerPoints.clear();
  if (discriminant(a, b) == 0) return; // skip singular curves

  int bound = 10;
  for (int xi = -bound; xi <= bound; xi++) {
    long rhs = (long)xi * xi * xi + (long)a * xi + (long)b;
    if (rhs < 0) continue;
    long s = isPerfectSquare(rhs);
    if (s >= 0) {
      int yi = (int)s;
      integerPoints.add(new PVector(xi, yi));
      if (yi != 0) {
        integerPoints.add(new PVector(xi, -yi));
      }
    }
  }
}

long isPerfectSquare(long n) {
  if (n < 0) return -1;
  long r = (long)Math.round(Math.sqrt(n));
  if (r * r == n) return r;
  return -1;
}

long discriminant(int a, int b) {
  long A = a;
  long B = b;
  long val = 4 * A * A * A + 27 * B * B;
  return -16 * val;
}

float partialLAt1(int a, int b) {
  if (discriminant(a, b) == 0) return 0.0;
  double prod = 1.0;

  for (int p : primes) {
    int Np = countPointsModP(a, b, p); // includes point at infinity
    int ap = p + 1 - Np;
    double euler = 1.0 / (1.0 - ((double)ap) / p + 1.0 / (p * (double)p));
    prod *= euler;
  }
  return (float)prod;
}

int countPointsModP(int a, int b, int p) {
  int count = 1; // point at infinity

  int aMod = mod(a, p);
  int bMod = mod(b, p);

  for (int x = 0; x < p; x++) {
    int rhs = (int)(((long)x * x * x) % p);
    rhs = (rhs + (int)(((long)aMod * x) % p)) % p;
    rhs = (rhs + bMod) % p;
    if (rhs < 0) rhs += p;

    int yCount = 0;
    for (int y = 0; y < p; y++) {
      int lhs = (int)(((long)y * y) % p);
      if (lhs == rhs) yCount++;
    }
    count += yCount;
  }
  return count;
}

int mod(int x, int m) {
  int r = x % m;
  if (r < 0) r += m;
  return r;
}

// ---- Coordinate transforms ----

float worldToScreenX(float x) {
  return map(x, xMin, xMax, 50, 550);
}

float worldToScreenY(float y) {
  return map(y, yMin, yMax, 550, 50);
}

// ---- Curve helpers ----

void applyCurve(int idx) {
  if (idx < 0 || idx >= curveNames.length) return;

  if (curveIsHeader[idx]) {
    // headers have no specific (a,b); do nothing
    return;
  }

  a = curveA[idx];
  b = curveB[idx];
  recomputeIntegerPoints();
}

void cycleCurve(int dir) {
  int n = curveNames.length;
  int start = selectedCurve;
  while (true) {
    selectedCurve = (selectedCurve + dir + n) % n;
    if (!curveIsHeader[selectedCurve]) {
      applyCurve(selectedCurve);
      break;
    }
    if (selectedCurve == start) break; // avoid infinite loop
  }
}

// ---- Input handling ----

void keyPressed() {
  boolean changed = false;
  if (key == 'q' || key == 'Q') {
    a--;
    changed = true;
  } else if (key == 'a' || key == 'A') {
    a++;
    changed = true;
  } else if (key == 'w' || key == 'W') {
    b--;
    changed = true;
  } else if (key == 's' || key == 'S') {
    b++;
    changed = true;
  } else if (key == 'r' || key == 'R') {
    a = (int)random(-5, 6);
    b = (int)random(-5, 6);
    changed = true;
  }

  if (changed) {
    // Move to Custom; sync its a,b
    selectedCurve = 0;
    curveA[0] = a;
    curveB[0] = b;
    recomputeIntegerPoints();
  }
}

void mousePressed() {
  int items = curveNames.length;

  // Click on dropdown main box toggles it
  if (mouseX >= dropdownX && mouseX <= dropdownX + dropdownW &&
      mouseY >= dropdownY && mouseY <= dropdownY + dropdownH) {
    dropdownOpen = !dropdownOpen;
    return;
  }

  // If dropdown open, handle item clicks + scrollbar clicks
  if (dropdownOpen) {
    int visible = min(items - scrollOffset, maxVisibleItems);

    // Item clicks
    for (int i = 0; i < visible; i++) {
      int idx = scrollOffset + i;
      float iy = dropdownY + dropdownH * (i + 1);
      if (mouseX >= dropdownX && mouseX <= dropdownX + dropdownW &&
          mouseY >= iy && mouseY <= iy + dropdownH) {
        if (!curveIsHeader[idx]) {
          selectedCurve = idx;
          applyCurve(selectedCurve);
          dropdownOpen = false;
        }
        return;
      }
    }

    // Scrollbar clicks (page up/down)
    if (items > maxVisibleItems) {
      int barX = dropdownX + dropdownW + 4;
      int barY = dropdownY + dropdownH;
      int barW = 8;
      int barH = dropdownH * maxVisibleItems;

      if (mouseX >= barX && mouseX <= barX + barW &&
          mouseY >= barY && mouseY <= barY + barH) {
        int dir = (mouseY < barY + barH/2) ? -1 : 1;
        scrollOffset += dir;
        scrollOffset = constrain(scrollOffset, 0, items - maxVisibleItems);
        return;
      }
    }

    // Click elsewhere closes dropdown
    dropdownOpen = false;
  }

  // Prev button
  if (mouseX >= prevBtnX && mouseX <= prevBtnX + prevBtnW &&
      mouseY >= prevBtnY && mouseY <= prevBtnY + prevBtnH) {
    cycleCurve(-1);
    return;
  }

  // Next button
  if (mouseX >= nextBtnX && mouseX <= nextBtnX + nextBtnW &&
      mouseY >= nextBtnY && mouseY <= nextBtnY + nextBtnH) {
    cycleCurve(1);
    return;
  }
}

// Mouse wheel for scrolling dropdown
void mouseWheel(MouseEvent event) {
  if (!dropdownOpen) return;
  int items = curveNames.length;
  if (items <= maxVisibleItems) return;

  float e = event.getCount();  // +1 down, -1 up
  scrollOffset += (e > 0 ? 1 : -1);
  scrollOffset = constrain(scrollOffset, 0, items - maxVisibleItems);
}
