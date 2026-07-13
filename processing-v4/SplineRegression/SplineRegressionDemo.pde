/**
 * Spline Regression Demo (Cubic B-splines + Ridge) in Processing
 * --------------------------------------------------------------
 * NEW:
 *  - 'c' : export CSVs (data, fit, weights, knots)
 *  - 's' : save LITTLE-ENDIAN binaries:
 *          * spline_model_le.bin
 *          * spline_fit_le.bin
 *
 * Existing:
 *  - 'b' basis overlay toggle; 'k' knot markers
 *  - 'r' regenerate data; +/- basis M; [/] lambda
 *  - HUD shows MAE, RMSE, MaxAbs, R², and RAW/NEW ratio
 */

import java.io.*;
import java.nio.*;
import java.nio.channels.*; // Optional, not required but handy

/* ===== Window (use constants so size() is legal in settings()) ===== */
static final int W = 900;
static final int H = 600;

float marginL = 70, marginR = 20, marginT = 30, marginB = 90;

/* ===== Data ===== */
int N = 220;
double[] xs, ys;
double xmin = 0.0, xmax = 10.0;
double ymin, ymax;
double noiseSigma = 0.18;

/* ===== Spline params ===== */
int degree = 3;      // cubic
int M = 14;          // basis count
double lambda = 1e-2;

/* ===== Toggles & state ===== */
boolean showBasis = false;
boolean showKnots = true;
String statusMsg = "";
int statusMsgFrames = 0;

/* ===== Model & metrics ===== */
SplineRegressor spline;
double mae, rmse, maxAbs, r2;
long rawBytes, compressedBytes;
double rawOverNew;   // RAW/NEW ratio

/* ===== Sketch ===== */
//void settings() { size(W, H); }

void setup() {
  size(800,600);
  smooth(8);
  generateData();
  spline = new SplineRegressor(degree, M, xmin, xmax);
  fitAndRescale();
}

void draw() {
  background(252);
  drawAxesGrid();
  if (showKnots) drawKnotMarkers();
  drawDataPoints();
  if (showBasis) drawBasisOverlay();
  drawSplineCurve();
  drawHUD();
  drawStatus();
}

void keyPressed() {
  if (key == '+' || key == '=') {
    M = Math.min(120, M + 1);
    spline.setBasisCount(M);
    fitAndRescale();
  } else if (key == '-' || key == '_') {
    M = Math.max(6, M - 1);
    spline.setBasisCount(M);
    fitAndRescale();
  } else if (key == '[') {
    lambda = Math.max(1e-12, lambda * 0.5);
    fitAndRescale();
  } else if (key == ']') {
    lambda = Math.min(1e6, lambda * 2.0);
    fitAndRescale();
  } else if (key == 'r' || key == 'R') {
    generateData();
    fitAndRescale();
  } else if (key == 'b' || key == 'B') {
    showBasis = !showBasis;
  } else if (key == 'k' || key == 'K') {
    showKnots = !showKnots;
  } else if (key == 's' || key == 'S') {
    saveBinariesLittleEndian();
  } else if (key == 'c' || key == 'C') {
    saveCSVs();
  }
}

/* ===== Data generation ===== */
void generateData() {
  xs = new double[N];
  ys = new double[N];
  for (int i = 0; i < N; i++) {
    double t = i / (double)(N - 1);
    double x = xmin + (xmax - xmin) * t;
    double clean = Math.sin(x) + 0.35 * Math.sin(3.0 * x) + 0.1 * x / xmax;
    double y = clean + randomGaussian() * noiseSigma;
    xs[i] = x;
    ys[i] = y;
  }
}

/* ===== Fit, metrics, scaling ===== */
void fitAndRescale() {
  spline.fit(xs, ys, lambda);
  // y-range from data and model
  ymin = Double.POSITIVE_INFINITY;
  ymax = Double.NEGATIVE_INFINITY;
  for (int i = 0; i < N; i++) {
    ymin = Math.min(ymin, ys[i]);
    ymax = Math.max(ymax, ys[i]);
  }
  for (int i = 0; i <= 1000; i++) {
    double x = xmin + (xmax - xmin) * i / 1000.0;
    double yhat = spline.predict(x);
    ymin = Math.min(ymin, yhat);
    ymax = Math.max(ymax, yhat);
  }
  double pad = 0.08 * (ymax - ymin + 1e-9);
  ymin -= pad;
  ymax += pad;

  computeErrors();
  computeCompression();
}

void computeErrors() {
  double sum = 0.0;
  for (int i = 0; i < N; i++) sum += ys[i];
  double ybar = sum / N;

  double se = 0.0, sae = 0.0, sst = 0.0, smax = 0.0;
  for (int i = 0; i < N; i++) {
    double yhat = spline.predict(xs[i]);
    double e = yhat - ys[i];
    se += e * e;
    sae += Math.abs(e);
    smax = Math.max(smax, Math.abs(e));
    double d = ys[i] - ybar;
    sst += d * d;
  }
  mae = sae / N;
  rmse = Math.sqrt(se / N);
  maxAbs = smax;
  r2 = (sst > 0) ? (1.0 - se / sst) : 1.0;
}

void computeCompression() {
  // Assume we're "compressing" only y-values as doubles (x known or even-spaced)
  rawBytes = (long)N * 8L;

  // Compressed representation: header + degree + M + xmin,xmax + lambda + knots + weights (+ lengths)
  int knotCount = M + degree + 1;
  long knotBytes = (long)knotCount * 8L; // doubles
  long weightBytes = (long)M * 8L;       // doubles
  long header = 4 + 4 + 4 + 4 + 8 + 8 + 8 + 4 + 4; // magic(4)+ver(4)+degree(4)+M(4)+xmin(8)+xmax(8)+lambda(8)+knotCount(4)+weightCount(4)
  compressedBytes = header + knotBytes + weightBytes;

  rawOverNew = (compressedBytes > 0) ? ((double)rawBytes / (double)compressedBytes) : Double.NaN;
}

/* ===== Drawing ===== */
void drawAxesGrid() {
  stroke(220);
  strokeWeight(1);
  noFill();
  rect(marginL, marginT, width - marginL - marginR, height - marginT - marginB);

  // grid
  stroke(235);
  for (int i = 1; i <= 10; i++) {
    float xs = map(i, 0, 10, marginL, width - marginR);
    line(xs, marginT, xs, height - marginB);
    float ys = map(i, 0, 10, height - marginB, marginT);
    line(marginL, ys, width - marginR, ys);
  }

  // y=0 axis if visible
  if (ymin < 0 && ymax > 0) {
    stroke(200, 60, 60, 180);
    float y0 = yToScreen(0);
    line(marginL, y0, width - marginR, y0);
  }

  // numeric ticks (sparse)
  fill(40);
  noStroke();
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 10; i++) {
    double xv = xmin + (xmax - xmin) * i / 10.0;
    float xs = xToScreen((float)xv);
    text(nf((float)xv, 1, 1), xs, height - marginB + 6);
  }
  textAlign(RIGHT, CENTER);
  for (int i = 0; i <= 10; i++) {
    double yv = ymin + (ymax - ymin) * i / 10.0;
    float ys = yToScreen((float)yv);
    text(nf((float)yv, 1, 2), marginL - 8, ys);
  }
}

void drawKnotMarkers() {
  stroke(120, 120, 120, 130);
  strokeWeight(1.2);
  noFill();
  double[] U = spline.knots;
  for (int i = 0; i < U.length; i++) {
    float xs = xToScreen((float)U[i]);
    line(xs, marginT, xs, height - marginB);
  }
}

void drawDataPoints() {
  noStroke();
  fill(40, 90, 220, 150);
  for (int i = 0; i < N; i++) {
    ellipse(xToScreen((float)xs[i]), yToScreen((float)ys[i]), 5, 5);
  }
}

void drawBasisOverlay() {
  int S = 400;
  for (int j = 0; j < M; j++) {
    noFill();
    stroke(50, 150, 200, 70);
    strokeWeight(1.2);
    beginShape();
    for (int i = 0; i <= S; i++) {
      double x = xmin + (xmax - xmin) * i / (double)S;
      double phi = spline.bspline(j, degree, x, spline.knots);
      double y = spline.w[j] * phi; // component contribution
      vertex(xToScreen((float)x), yToScreen((float)y));
    }
    endShape();
  }
}

void drawSplineCurve() {
  noFill();
  stroke(10, 150, 80);
  strokeWeight(2.8);
  int S = 1000;
  beginShape();
  for (int i = 0; i <= S; i++) {
    double x = xmin + (xmax - xmin) * i / (double)S;
    double y = spline.predict(x);
    vertex(xToScreen((float)x), yToScreen((float)y));
  }
  endShape();
}

void drawHUD() {
  // panel
  fill(0, 170);
  noStroke();
  rect(marginL, height - marginB+20, width - marginL - marginR, marginB - 24, 10);

  fill(255);
  textAlign(LEFT, TOP);
  String line1 = "Cubic B-Spline Regression   |   M=" + M + " (deg " + degree + ")   |   λ=" + pretty(lambda);
  String line2 = "Errors:  MAE=" + pretty(mae) + "   RMSE=" + pretty(rmse) + "   MaxAbs=" + pretty(maxAbs) + "   R²=" + pretty(r2);
  String line3 = "Compression:  raw=" + bytesStr(rawBytes) + "   new=" + bytesStr(compressedBytes) + "   RAW/NEW=" + pretty(rawOverNew);
  String line4 = "Keys:  -/+ M   [/] λ   r regenerate   b basis " + (showBasis ? "(on)" : "(off)") + "   k knots " + (showKnots ? "(on)" : "(off)") + "   s save LE bin   c save CSV";

  text(line1, marginL + 10, height - marginB + 12);
  text(line2, marginL + 10, height - marginB + 30);
  text(line3, marginL + 10, height - marginB + 48);
  text(line4, marginL + 10, height - marginB + 66);
}

void drawStatus() {
  if (statusMsgFrames > 0) {
    fill(0, 200);
    noStroke();
    float w = textWidth(statusMsg) + 20;
    rect(width - w - 16, 16, w, 28, 6);
    fill(255);
    textAlign(LEFT, TOP);
    text(statusMsg, width - w - 6, 20);
    statusMsgFrames--;
  }
}

/* ===== Binary save (Little-Endian) ===== */
void saveBinariesLittleEndian() {
  try {
    // Model (LE)
    FileOutputStream fos = new FileOutputStream(sketchPath("spline_model_le.bin"));
    // MAGIC 'SLPL' (little-endian read as letters when parsed byte-wise), version=1
    writeIntLE(fos, 0x4C50534C);   // you can ignore the codepoint; consumers should treat as opaque magic
    writeIntLE(fos, 1);
    writeIntLE(fos, degree);
    writeIntLE(fos, M);
    writeDoubleLE(fos, xmin);
    writeDoubleLE(fos, xmax);
    writeDoubleLE(fos, lambda);

    int knotCount = spline.knots.length;
    int weightCount = spline.w.length;
    writeIntLE(fos, knotCount);
    writeIntLE(fos, weightCount);

    for (int i = 0; i < knotCount; i++) writeDoubleLE(fos, spline.knots[i]);
    for (int i = 0; i < weightCount; i++) writeDoubleLE(fos, spline.w[i]);
    fos.flush();
    fos.close();

    // Fit (LE): N, then (x, yhat)
    fos = new FileOutputStream(sketchPath("spline_fit_le.bin"));
    writeIntLE(fos, N);
    for (int i = 0; i < N; i++) {
      double yhat = spline.predict(xs[i]);
      writeDoubleLE(fos, xs[i]);
      writeDoubleLE(fos, yhat);
    }
    fos.flush();
    fos.close();

    setStatus("Saved CSVs? Press 'c'. Saved LE bins: spline_model_le.bin, spline_fit_le.bin");
  } catch (Exception e) {
    setStatus("Save LE failed: " + e.getMessage());
    e.printStackTrace();
  }
}

/* ===== CSV save ===== */
void saveCSVs() {
  try {
    // data points
    PrintWriter pw = createWriter(sketchPath("data.csv"));
    pw.println("x,y");
    for (int i = 0; i < N; i++) pw.println(xs[i] + "," + ys[i]);
    pw.flush(); pw.close();

    // fit on data x grid
    pw = createWriter(sketchPath("fit.csv"));
    pw.println("x,yhat");
    for (int i = 0; i < N; i++) {
      double yhat = spline.predict(xs[i]);
      pw.println(xs[i] + "," + yhat);
    }
    pw.flush(); pw.close();

    // weights
    pw = createWriter(sketchPath("model_weights.csv"));
    pw.println("index,weight");
    for (int i = 0; i < spline.w.length; i++) pw.println(i + "," + spline.w[i]);
    pw.flush(); pw.close();

    // knots
    pw = createWriter(sketchPath("knots.csv"));
    pw.println("index,knot");
    for (int i = 0; i < spline.knots.length; i++) pw.println(i + "," + spline.knots[i]);
    pw.flush(); pw.close();

    setStatus("Saved CSVs: data.csv, fit.csv, model_weights.csv, knots.csv");
  } catch (Exception e) {
    setStatus("CSV save failed: " + e.getMessage());
    e.printStackTrace();
  }
}

/* ===== LE write helpers ===== */
void writeIntLE(OutputStream os, int v) throws IOException {
  os.write((v      ) & 0xFF);
  os.write((v >>  8) & 0xFF);
  os.write((v >> 16) & 0xFF);
  os.write((v >> 24) & 0xFF);
}
void writeDoubleLE(OutputStream os, double d) throws IOException {
  long v = Double.doubleToLongBits(d);
  os.write((int)( v        & 0xFF));
  os.write((int)((v >>  8) & 0xFF));
  os.write((int)((v >> 16) & 0xFF));
  os.write((int)((v >> 24) & 0xFF));
  os.write((int)((v >> 32) & 0xFF));
  os.write((int)((v >> 40) & 0xFF));
  os.write((int)((v >> 48) & 0xFF));
  os.write((int)((v >> 56) & 0xFF));
}

/* ===== Helpers ===== */
void setStatus(String s) { statusMsg = s; statusMsgFrames = 240; }

String pretty(double v) {
  if (Double.isNaN(v) || Double.isInfinite(v)) return "" + v;
  double a = Math.abs(v);
  if (a == 0) return "0";
  if (a >= 1000 || a < 1e-3) return String.format("%.2e", v);
  if (a >= 10) return String.format("%.2f", v);
  return String.format("%.4f", v);
}

String bytesStr(long b) {
  if (b < 1024) return b + " B";
  double kb = b / 1024.0;
  if (kb < 1024) return String.format("%.1f kB", kb);
  double mb = kb / 1024.0;
  return String.format("%.2f MB", mb);
}

float xToScreen(float x) { return map(x, (float)xmin, (float)xmax, marginL, width - marginR); }
float yToScreen(float y) { return map(y, (float)ymin, (float)ymax, height - marginB, marginT); }
