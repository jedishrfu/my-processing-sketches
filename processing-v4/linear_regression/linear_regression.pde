// LinearRegressionInteractive.pde
// Click to add points. Drag to move points. Best-fit line updates live.
// Keys: [E] toggle residuals, [G] toggle grid, [C] clear, [R] random demo, [DEL/BKSP] delete nearest, [S] save PNG

ArrayList<PVector> pts = new ArrayList<PVector>(); // points in DATA coordinates
float b0 = 0;   // intercept in DATA coords
float b1 = 1;   // slope in DATA coords
float r2 = Float.NaN;
boolean fitted = false;

boolean showResiduals = true;
boolean showGrid = true;

// Plot area (screen coords)
int marginL = 80, marginR = 30, marginT = 40, marginB = 70;

// Data ranges (DATA coords)
float xmin = 0, xmax = 10, ymin = 0, ymax = 10;

// Drag handling
int draggingIdx = -1;
float dragRadiusPx = 10;

void setup() {
  size(900, 600);
  smooth(8);
  textFont(createFont("Menlo", 14));
  // Optional: seed with a quick demo
  randomDemo(25);
}

void draw() {
  background(250);
  drawAxes();
  if (showGrid) drawGrid(10, 10);

  // Draw points
  stroke(30);
  fill(30);
  for (int i = 0; i < pts.size(); i++) {
    PVector p = pts.get(i);
    PVector s = dataToScreen(p);
    noStroke();
    fill(30);
    ellipse(s.x, s.y, 8, 8);
  }

  // Fit & draw regression
  if (pts.size() >= 2) {
    fitRegression();
    drawRegressionLine();
    if (showResiduals) drawResiduals();
  } else {
    fitted = false;
    r2 = Float.NaN;
  }

  // Hover crosshair prediction
  if (pts.size() >= 2 && mouseInPlot()) {
    float dx = screenToDataX(mouseX);
    float dy = predict(dx);
    PVector s = dataToScreen(new PVector(dx, dy));
    stroke(0, 90);
    line(s.x, plotTop(), s.x, plotBottom());
    line(plotLeft(), s.y, plotRight(), s.y);
    noStroke();
    fill(0);
    ellipse(s.x, s.y, 8, 8);
    fill(0, 160);
    String tip = String.format("x=%.3f  ŷ=%.3f", dx, dy);
    drawBoxedText(tip, s.x + 10, s.y - 10);
  }

  // UI HUD
  drawHUD();
}

void drawAxes() {
  stroke(0);
  strokeWeight(1.5);
  // X axis
  line(plotLeft(), plotBottom(), plotRight(), plotBottom());
  // Y axis
  line(plotLeft(), plotTop(),    plotLeft(), plotBottom());
  // Ticks & labels
  fill(0);
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 10; i++) {
    float x = map(i, 0, 10, xmin, xmax);
    float sx = dataToScreenX(x);
    stroke(0);
    line(sx, plotBottom(), sx, plotBottom() + 5);
    noStroke();
    text(nf(x, 0, (xmax - xmin) <= 5 ? 2 : 1), sx, plotBottom() + 8);
  }
  textAlign(RIGHT, CENTER);
  for (int j = 0; j <= 10; j++) {
    float y = map(j, 0, 10, ymin, ymax);
    float sy = dataToScreenY(y);
    stroke(0);
    line(plotLeft() - 5, sy, plotLeft(), sy);
    noStroke();
    text(nf(y, 0, (ymax - ymin) <= 5 ? 2 : 1), plotLeft() - 8, sy);
  }
  // Titles
  textAlign(CENTER, BOTTOM);
  text("X", (plotLeft() + plotRight()) * 0.5, height - 12);
  pushMatrix();
  translate(18, (plotTop() + plotBottom()) * 0.5);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  text("Y", 0, 0);
  popMatrix();
}

void drawGrid(int nx, int ny) {
  stroke(0, 30);
  strokeWeight(1);
  // Vertical
  for (int i = 1; i < nx; i++) {
    float x = lerp(xmin, xmax, i/(float)nx);
    float sx = dataToScreenX(x);
    line(sx, plotTop(), sx, plotBottom());
  }
  // Horizontal
  for (int j = 1; j < ny; j++) {
    float y = lerp(ymin, ymax, j/(float)ny);
    float sy = dataToScreenY(y);
    line(plotLeft(), sy, plotRight(), sy);
  }
}

void fitRegression() {
  int n = pts.size();
  double sumX = 0, sumY = 0, sumXX = 0, sumXY = 0;
  for (PVector p : pts) {
    sumX  += p.x;
    sumY  += p.y;
    sumXX += p.x * p.x;
    sumXY += p.x * p.y;
  }
  double xBar = sumX / n;
  double yBar = sumY / n;

  double sxx = sumXX - n * xBar * xBar;
  double sxy = sumXY - n * xBar * yBar;

  if (abs((float)sxx) < 1e-12) {
    fitted = false;
    return;
  }
  b1 = (float)(sxy / sxx);
  b0 = (float)(yBar - b1 * xBar);
  fitted = true;

  // R^2
  double ssTot = 0, ssRes = 0;
  for (PVector p : pts) {
    double yi = p.y;
    double fi = b0 + b1 * p.x;
    ssTot += (yi - yBar) * (yi - yBar);
    ssRes += (yi - fi) * (yi - fi);
  }
  r2 = (float)(ssTot == 0 ? 1.0 : 1.0 - ssRes/ssTot);
}

float predict(float x) { return b0 + b1 * x; }

void drawRegressionLine() {
  if (!fitted) return;
  // Compute intersections of line with plot box in DATA coords
  // Line: y = b0 + b1*x
  ArrayList<PVector> edges = new ArrayList<PVector>();
  // left edge x = xmin
  edges.add(new PVector(xmin, predict(xmin)));
  // right edge x = xmax
  edges.add(new PVector(xmax, predict(xmax)));
  // clip to [ymin, ymax] by adding y edges too, then clipping segment to box
  // We'll just draw between (xmin,y(xmin)) and (xmax,y(xmax)) and rely on the box clipping visually.
  PVector a = dataToScreen(edges.get(0));
  PVector b = dataToScreen(edges.get(1));
  stroke(20, 120, 220);
  strokeWeight(2.5);
  line(a.x, a.y, b.x, b.y);

  // Equation box
  String eq = String.format("ŷ = %.4f + %.4f·x", b0, b1);
  String r2s = Float.isNaN(r2) ? "—" : String.format("%.4f", r2);
  drawBoxedText(eq + "   R² = " + r2s, plotLeft()+10, plotTop()+10);
}

void drawResiduals() {
  if (!fitted) return;
  stroke(220, 50, 50, 160);
  strokeWeight(1.5);
  for (PVector p : pts) {
    PVector s = dataToScreen(p);
    float yhat = predict(p.x);
    PVector sh = dataToScreen(new PVector(p.x, yhat));
    line(s.x, s.y, sh.x, sh.y);
  }
}

void drawHUD() {
  String msg = "[Click] add point   [Drag] move point   [DEL/BKSP] delete nearest   [R] random   [C] clear   [E] residuals   [G] grid   [S] save PNG";
  fill(0);
  textAlign(LEFT, CENTER);
  text(msg, 10, 15);

  // Data bounds & count
  String stats = String.format("points: %d   data X:[%.2f, %.2f] Y:[%.2f, %.2f]",
    pts.size(), xmin, xmax, ymin, ymax);
  textAlign(LEFT, CENTER);
  text(stats, 10, height - 15);
}

// ---------- Interaction ----------
void mousePressed() {
  if (!mouseInPlot()) return;
  int idx = findNearestPointIdx(mouseX, mouseY, dragRadiusPx);
  if (idx >= 0) {
    draggingIdx = idx;
  } else {
    // Add new point
    float dx = screenToDataX(mouseX);
    float dy = screenToDataY(mouseY);
    pts.add(new PVector(dx, dy));
    // Optionally auto-rescale data bounds
    autoRescale(dx, dy);
  }
}

void mouseDragged() {
  if (draggingIdx >= 0) {
    float dx = constrain(screenToDataX(mouseX), xmin, xmax);
    float dy = constrain(screenToDataY(mouseY), ymin, ymax);
    pts.get(draggingIdx).set(dx, dy);
  }
}

void mouseReleased() {
  draggingIdx = -1;
}

void keyPressed() {
  if (key == 'e' || key == 'E') showResiduals = !showResiduals;
  if (key == 'g' || key == 'G') showGrid = !showGrid;
  if (key == 'c' || key == 'C') { pts.clear(); fitted = false; r2 = Float.NaN; }
  if (key == 'r' || key == 'R') randomDemo(25);
  if (keyCode == DELETE || keyCode == BACKSPACE) deleteNearest();
  if (key == 's' || key == 'S') saveFrame("linear-regression-####.png");
}

void deleteNearest() {
  if (pts.isEmpty()) return;
  int idx = findNearestPointIdx(mouseX, mouseY, 1000); // large search radius
  if (idx >= 0) pts.remove(idx);
}

int findNearestPointIdx(float sx, float sy, float maxDistPx) {
  int best = -1;
  float bestD = maxDistPx;
  for (int i = 0; i < pts.size(); i++) {
    PVector s = dataToScreen(pts.get(i));
    float d = dist(sx, sy, s.x, s.y);
    if (d < bestD) { bestD = d; best = i; }
  }
  return best;
}

// ---------- Data utilities ----------
void autoRescale(float x, float y) {
  boolean changed = false;
  float pad = 0.5;
  if (x < xmin) { xmin = x - pad; changed = true; }
  if (x > xmax) { xmax = x + pad; changed = true; }
  if (y < ymin) { ymin = y - pad; changed = true; }
  if (y > ymax) { ymax = y + pad; changed = true; }
  if (changed) {
    // keep min margins between ranges
    float minSpan = 1.0;
    if (xmax - xmin < minSpan) { float c = (xmax + xmin)/2; xmin = c - minSpan/2; xmax = c + minSpan/2; }
    if (ymax - ymin < minSpan) { float c = (ymax + ymin)/2; ymin = c - minSpan/2; ymax = c + minSpan/2; }
  }
}

// Demo data around a line with noise
void randomDemo(int n) {
  pts.clear();
  float trueB0 = random(1, 3);
  float trueB1 = random(0.3, 1.2);
  xmin = 0; xmax = 10; ymin = 0; ymax = 10;
  for (int i = 0; i < n; i++) {
    float x = map(i + random(-0.5, 0.5), 0, n-1, 0.5, 9.5);
    float y = trueB0 + trueB1 * x + randomGaussian() * 0.6;
    pts.add(new PVector(x, y));
  }
}

// ---------- Coordinate transforms ----------
float plotLeft()   { return marginL; }
float plotRight()  { return width - marginR; }
float plotTop()    { return marginT; }
float plotBottom() { return height - marginB; }

boolean mouseInPlot() {
  return mouseX >= plotLeft() && mouseX <= plotRight() && mouseY >= plotTop() && mouseY <= plotBottom();
}

PVector dataToScreen(PVector d) {
  return new PVector(dataToScreenX(d.x), dataToScreenY(d.y));
}
float dataToScreenX(float x) {
  return map(x, xmin, xmax, plotLeft(), plotRight());
}
float dataToScreenY(float y) {
  return map(y, ymin, ymax, plotBottom(), plotTop());
}
float screenToDataX(float sx) {
  return map(sx, plotLeft(), plotRight(), xmin, xmax);
}
float screenToDataY(float sy) {
  return map(sy, plotBottom(), plotTop(), ymin, ymax);
}

// ---------- UI helper ----------
void drawBoxedText(String s, float x, float y) {
  float pad = 6;
  textAlign(LEFT, TOP);
  float tw = textWidth(s);
  float th = textAscent() + textDescent();
  noStroke();
  fill(255, 230);
  rect(x - pad, y - pad, tw + 2*pad, th + 2*pad, 8);
  fill(0);
  text(s, x, y);
}
