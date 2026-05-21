/**
 * Polynomial Regression + Monotone Cubic Spline (Processing / Java mode)
 *
 * Modes:
 *   P - Polynomial regression (least squares), degree via 1..6
 *   S - Monotone cubic Hermite spline (Fritsch–Carlson)
 *
 * Mouse:
 *   Click to add a point
 * Keys:
 *   1..6 - change polynomial degree
 *   P    - polynomial mode
 *   S    - spline mode
 *   R    - randomize sample data
 *   Backspace - remove last point
 */
 
 import java.util.*; // Arrays, Comparator, etc.

ArrayList<PVector> pts = new ArrayList<PVector>();

enum FitMode { POLY, SPLINE }
FitMode mode = FitMode.SPLINE;

int degree = 3;           // poly degree for POLY mode
float[] coeffs = null;    // polynomial coefficients a0..ad
float rmse = Float.NaN;

void setup() {
  size(900, 560);
  randomizeData();
}

void draw() {
  background(250);
  drawAxes();

  // draw points
  noStroke();
  fill(0);
  for (PVector p : pts) ellipse(p.x, p.y, 7, 7);

  // Fit/draw curve depending on mode
  if (mode == FitMode.POLY) drawPolynomialFit();
  else drawSplineFit();

  // HUD
  drawHUD();
}

void mousePressed() {
  pts.add(new PVector(mouseX, mouseY));
}

void keyPressed() {
  if (key >= '1' && key <= '6') degree = key - '0';
  else if (key == 'p' || key == 'P') mode = FitMode.POLY;
  else if (key == 's' || key == 'S') mode = FitMode.SPLINE;
  else if (key == 'r' || key == 'R') randomizeData();
  else if (keyCode == BACKSPACE && pts.size() > 0) pts.remove(pts.size()-1);
}

/* ---------------------- Drawing helpers ---------------------- */

float padL = 60, padR = 20, padT = 30, padB = 60;
float dataXmin = -5, dataXmax = 5;
float dataYmin = -20, dataYmax = 60;

void drawAxes() {
  rectMode(CORNERS);
  noFill();
  stroke(220);
  rect(padL, padT, width - padR, height - padB);

  stroke(200);
  fill(120);
  textAlign(CENTER, TOP);
  for (int i = (int)ceil(dataXmin); i <= (int)floor(dataXmax); i++) {
    float sx = dataToScreenX(i);
    line(sx, height - padB, sx, height - padB + 6);
    text(i, sx, height - padB + 8);
  }
  textAlign(RIGHT, CENTER);
  for (int j = (int)ceil(dataYmin); j <= (int)floor(dataYmax); j += 10) {
    float sy = dataToScreenY(j);
    line(padL - 6, sy, padL, sy);
    text(j, padL - 10, sy);
  }

  textAlign(CENTER, CENTER);
  fill(60);
  text("x", (padL + width - padR)/2, height - 20);
  pushMatrix();
  translate(20, (padT + height - padB)/2);
  rotate(-HALF_PI);
  text("y", 0, 0);
  popMatrix();
}

void drawHUD() {
  fill(255, 245);
  noStroke();
  rect(10, 10, 430, 130, 10);
  fill(20);
  textAlign(LEFT, TOP);
  String s = "Mode: " + (mode == FitMode.POLY ? "Polynomial Regression" : "Monotone Cubic Spline") + "\n";
  if (mode == FitMode.POLY) {
    s += "Degree: " + degree + ((pts.size() < degree+1) ? " (need ≥ " + (degree+1) + " pts)" : "") + "\n";
    if (coeffs != null) {
      s += "RMSE: " + nf(rmse, 1, 3) + "\n";
      s += "y = ";
      for (int k = 0; k < coeffs.length; k++) {
        s += (k==0 ? "" : " + ") + nf(coeffs[k], 1, 3) + (k==0 ? "" : "*x" + (k>1 ? "^"+k : ""));
      }
      s += "\n";
    }
  } else {
    s += "Points: " + pts.size() + (pts.size() < 2 ? " (need ≥ 2 pts)" : "") + "\n";
    s += "Spline: Fritsch–Carlson (monotone cubic Hermite)\n";
  }
  s += "Controls: click=add · Backspace=undo · P=poly · S=spline · 1..6=deg · R=randomize";
  text(s, 20, 20);
}

/* ---------------------- Polynomial fit ---------------------- */

void drawPolynomialFit() {
  coeffs = null;
  rmse = Float.NaN;

  if (pts.size() >= degree + 1) {
    float[] xs = new float[pts.size()];
    float[] ys = new float[pts.size()];
    for (int i = 0; i < pts.size(); i++) {
      xs[i] = screenToDataX(pts.get(i).x);
      ys[i] = screenToDataY(pts.get(i).y);
    }
    coeffs = polyfit(xs, ys, degree);
    if (coeffs != null) {
      rmse = computeRMSE(xs, ys, coeffs);
      // plot
      int steps = 700;
      noFill();
      stroke(20, 120, 255);
      strokeWeight(2);
      beginShape();
      for (int i = 0; i <= steps; i++) {
        float x = map(i, 0, steps, dataXmin, dataXmax);
        float y = polyval(coeffs, x);
        vertex(dataToScreenX(x), dataToScreenY(y));
      }
      endShape();
    }
  }
}

float[] polyfit(float[] x, float[] y, int deg) {
  int n = deg + 1;
  double[][] XtX = new double[n][n];
  double[] Xty = new double[n];

  double[] sx = new double[2*deg + 1];
  for (int i = 0; i < x.length; i++) {
    double xp = 1.0;
    for (int p = 0; p <= 2*deg; p++) { sx[p] += xp; xp *= x[i]; }
  }
  for (int r = 0; r < n; r++)
    for (int c = 0; c < n; c++)
      XtX[r][c] = sx[r + c];

  for (int r = 0; r < n; r++) {
    double sum = 0;
    for (int i = 0; i < x.length; i++) sum += pow(x[i], r) * y[i];
    Xty[r] = sum;
  }
  return gaussSolve(XtX, Xty);
}

float polyval(float[] a, float x) {
  float acc = 0;
  for (int i = a.length-1; i >= 0; i--) acc = acc * x + a[i];
  return acc;
}

float computeRMSE(float[] x, float[] y, float[] a) {
  double se = 0;
  for (int i = 0; i < x.length; i++) {
    double e = y[i] - polyval(a, x[i]);
    se += e*e;
  }
  return (float)Math.sqrt(se / x.length);
}

float[] gaussSolve(double[][] A, double[] b) {
  int n = b.length;
  double[][] M = new double[n][n];
  double[] rhs = new double[n];
  for (int i = 0; i < n; i++) { arrayCopy(A[i], M[i]); rhs[i] = b[i]; }

  for (int k = 0; k < n; k++) {
    int piv = k; double maxAbs = Math.abs(M[k][k]);
    for (int r = k+1; r < n; r++) {
      double v = Math.abs(M[r][k]);
      if (v > maxAbs) { maxAbs = v; piv = r; }
    }
    if (Math.abs(maxAbs) < 1e-12) return null;
    if (piv != k) { double[] tmp = M[k]; M[k] = M[piv]; M[piv] = tmp; double tb = rhs[k]; rhs[k] = rhs[piv]; rhs[piv] = tb; }

    for (int r = k+1; r < n; r++) {
      double f = M[r][k] / M[k][k];
      for (int c = k; c < n; c++) M[r][c] -= f * M[k][c];
      rhs[r] -= f * rhs[k];
    }
  }

  float[] x = new float[n];
  for (int i = n-1; i >= 0; i--) {
    double sum = rhs[i];
    for (int c = i+1; c < n; c++) sum -= M[i][c] * x[c];
    x[i] = (float)(sum / M[i][i]);
  }
  return x;
}

/* ---------------------- Monotone cubic Hermite spline ----------------------
 * Fritsch–Carlson method:
 * - Sort by x
 * - Compute secant slopes d[i]
 * - Compute tangents m[i] with a weighted harmonic mean, enforcing monotonicity
 * - Piecewise Hermite basis for evaluation
 */

void drawSplineFit() {
  if (pts.size() < 2) return;

  // Gather and sort by x
  int n = pts.size();
  float[] xs = new float[n];
  float[] ys = new float[n];
  for (int i = 0; i < n; i++) {
    xs[i] = screenToDataX(pts.get(i).x);
    ys[i] = screenToDataY(pts.get(i).y);
  }
  int[] order = sortIndicesBy(xs);
  xs = reorder(xs, order);
  ys = reorder(ys, order);
  // Remove duplicate x (keep last)
  int m = uniqueByX(xs, ys);
  if (m < 2) return;
  xs = Arrays.copyOf(xs, m);
  ys = Arrays.copyOf(ys, m);

  float[] ms = fritschCarlsonSlopes(xs, ys);

  // Draw curve
  noFill();
  stroke(0, 170, 90);
  strokeWeight(2);
  beginShape();
  int steps = 800;
  for (int i = 0; i <= steps; i++) {
    float x = map(i, 0, steps, dataXmin, dataXmax);
    float y = splineEval(x, xs, ys, ms);
    vertex(dataToScreenX(x), dataToScreenY(y));
  }
  endShape();

  // Optionally, draw x-sorted points (small)
  noStroke();
  fill(0, 170, 90, 160);
  for (int i = 0; i < xs.length; i++) {
    ellipse(dataToScreenX(xs[i]), dataToScreenY(ys[i]), 5, 5);
  }
}

float[] fritschCarlsonSlopes(float[] x, float[] y) {
  int n = x.length;
  float[] m = new float[n];
  float[] h = new float[n-1];
  float[] d = new float[n-1];
  for (int i = 0; i < n-1; i++) {
    h[i] = x[i+1] - x[i];
    d[i] = (y[i+1] - y[i]) / h[i];
  }
  m[0] = d[0];
  m[n-1] = d[n-2];

  for (int i = 1; i < n-1; i++) {
    if (d[i-1] * d[i] <= 0) {
      m[i] = 0;
    } else {
      float w1 = 2*h[i] + h[i-1];
      float w2 = h[i] + 2*h[i-1];
      m[i] = (w1 + w2) / (w1/d[i-1] + w2/d[i]);
    }
  }

  // Extra clipping to avoid overshoot when endpoints are steep (optional)
  for (int i = 0; i < n-1; i++) {
    if (abs(d[i]) < 1e-12) { // flat secant -> zero tangents
      m[i] = 0;
      m[i+1] = 0;
      continue;
    }
    float a = m[i] / d[i];
    float b = m[i+1] / d[i];
    float s = a*a + b*b;
    if (s > 9) {
      float t = 3.0 / sqrt(s);
      m[i] = t * a * d[i];
      m[i+1] = t * b * d[i];
    }
  }
  return m;
}

float splineEval(float X, float[] x, float[] y, float[] m) {
  int n = x.length;
  if (X <= x[0]) return y[0];
  if (X >= x[n-1]) return y[n-1];

  // binary search for interval
  int lo = 0, hi = n-1;
  while (hi - lo > 1) {
    int mid = (lo + hi) >>> 1;
    if (X >= x[mid]) lo = mid; else hi = mid;
  }
  int i = lo;
  float h = x[i+1] - x[i];
  float t = (X - x[i]) / h;

  float t2 = t*t, t3 = t2*t;
  float h00 =  2*t3 - 3*t2 + 1;
  float h10 =      t3 - 2*t2 + t;
  float h01 = -2*t3 + 3*t2;
  float h11 =      t3 -   t2;

  return h00*y[i] + h10*h*m[i] + h01*y[i+1] + h11*h*m[i+1];
}

/* ---------------------- Utilities ---------------------- */

int[] sortIndicesBy(float[] a) {
  Integer[] idx = new Integer[a.length];
  for (int i = 0; i < a.length; i++) idx[i] = i;
  Arrays.sort(idx, new Comparator<Integer>() {
    public int compare(Integer i, Integer j) { return Float.compare(a[i], a[j]); }
  });
  int[] out = new int[a.length];
  for (int i = 0; i < a.length; i++) out[i] = idx[i];
  return out;
}

float[] reorder(float[] arr, int[] order) {
  float[] out = new float[order.length];
  for (int i = 0; i < order.length; i++) out[i] = arr[order[i]];
  return out;
}

int uniqueByX(float[] xs, float[] ys) {
  int w = 1;
  for (int r = 1; r < xs.length; r++) {
    if (abs(xs[r] - xs[w-1]) > 1e-9) { // new x
      xs[w] = xs[r];
      ys[w] = ys[r];
      w++;
    } else {
      // if duplicate x: keep latest y (already in ys[r])
      ys[w-1] = ys[r];
    }
  }
  return w;
}

/* ---------------------- Data helpers ---------------------- */

void randomizeData() {
  pts.clear();
  // Demo curve for both modes: y = 3 - 0.5x + 2x^2 with noise
  for (int i = 0; i < 22; i++) {
    float x = map(i, 0, 21, dataXmin, dataXmax);
    float y = 3 - 0.5*x + 2*x*x + randomGaussian()*3.0;
    pts.add(new PVector(dataToScreenX(x), dataToScreenY(y)));
  }
}

float dataToScreenX(float x) { return map(x, dataXmin, dataXmax, padL, width - padR); }
float dataToScreenY(float y) { return map(y, dataYmin, dataYmax, height - padB, padT); }
float screenToDataX(float sx) { return map(sx, padL, width - padR, dataXmin, dataXmax); }
float screenToDataY(float sy) { return map(sy, height - padB, padT, dataYmin, dataYmax); }
