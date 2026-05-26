// Processing (Java mode) single-file sketch
// Piecewise-Linear (lossy) compression demo + ZIP size comparison + plot
//
// Controls:
//   1 -> epsilon = 0.010
//   2 -> epsilon = 0.025
//   S -> save plot as pwl_plot.png
//
// Notes:
//  - We ZIP (Deflate) in-memory using java.util.zip to estimate practical ZIP sizes.
//  - PWL format is a simple custom binary: [int length][repeated segments: int start, int end, double m, double b].
//  - For speed, N kept at 50k. You can raise it if your machine is beefy.

import java.nio.*;
import java.util.zip.*;
import java.io.*;
import java.util.*;

int N = 50_000;                 // number of samples
float[] signal;                 // original signal
float[] recon;                  // reconstructed signal (current epsilon)
int plotCount = 1000;           // number of points to draw
float eps = 0.010f;             // current error tolerance

// Metrics/results
int segmentsCount = 0;
double mae, rmse, maxAbs;
long rawBytes, zippedRawBytes, pwlBytes, zippedPwlBytes;
double compressionRatioVsRaw;

ArrayList<Segment> segments = new ArrayList<Segment>();

void settings() {
  size(1100, 720);
}

void setup() {
  surface.setTitle("PWL Lossy Compression + ZIP Size Demo");
  signal = generateSignal(N);
  computeAll();
  noLoop(); // render once unless parameters change
}

void keyPressed() {
  if (key == '1') { eps = 0.010f; computeAll(); redraw(); }
  else if (key == '2') { eps = 0.025f; computeAll(); redraw(); }
  else if (key == 's' || key == 'S') { saveFrame("pwl_plot.png"); }
}

void draw() {
  background(252);
  drawHeader();
  drawPlot();
  drawStats();
}

// -------------------------- Core pipeline --------------------------

void computeAll() {
  // Compress with PWL at eps
  segments = pwlCompress(signal, eps);
  segmentsCount = segments.size();

  // Reconstruct
  recon = pwlDecompress(segments, N);

  // Errors
  double sumAbs = 0, sumSq = 0; double mxe = 0;
  for (int i = 0; i < N; i++) {
    double e = (double)signal[i] - (double)recon[i];
    double ae = Math.abs(e);
    sumAbs += ae;
    sumSq  += e*e;
    if (ae > mxe) mxe = ae;
  }
  mae = sumAbs / N;
  rmse = Math.sqrt(sumSq / N);
  maxAbs = mxe;

  // Bytes: raw float32
  byte[] raw = floatsToBytes(signal);
  rawBytes = raw.length;
  zippedRawBytes = zipBytesSize(raw, "raw_signal_float32.bin");

  // Bytes: PWL custom binary
  byte[] pwl = segmentsToBytes(segments, N);
  pwlBytes = pwl.length;
  zippedPwlBytes = zipBytesSize(pwl, "pwl_segments.bin");

  compressionRatioVsRaw = (double)zippedPwlBytes / (double)rawBytes;
}

// -------------------------- Signal generation --------------------------

float[] generateSignal(int n) {
    float[] y = new float[n];
    Random rng = new Random(7);

    for (int i = 0; i < n; i++) {
        // mix: gentle trend + medium/high freq sinusoids + small noise
        double trend = 0.00003 * i;
        double s1 = 0.5 * Math.sin(2 * Math.PI * i / 2000.0);
        double s2 = 0.25 * Math.sin(2 * Math.PI * i / 400.0 + 0.7);
        double noise = 0.01 * rng.nextGaussian();
        y[i] = (float)(trend + s1 + s2 + noise);
    }

    // 🔹 Write little-endian floats to binary file
    String filename = "/Users/jamesmcardle/input_data.bin";
    try (FileOutputStream fos = new FileOutputStream(filename)) {
        ByteBuffer buffer = ByteBuffer.allocate(n * Float.BYTES);
        buffer.order(ByteOrder.LITTLE_ENDIAN);  // ✅ ensure little-endian
        for (float v : y) {
            buffer.putFloat(v);
        }
        fos.write(buffer.array());
        System.out.printf("Saved %d floats (%d bytes, little-endian) to %s%n",
                          n, n * Float.BYTES, filename);
    } catch (IOException e) {
        e.printStackTrace();
    }

    return y;
}

// -------------------------- PWL compression --------------------------
//
// Greedy segment grower with least-squares fit per extension.
// For each segment, we extend one point at a time, re-fit y = m*x + b,
// and check max absolute error vs eps. When violated, finalize previous end.
// This is simple and reasonably fast for ~50k points and small eps.

static class Segment {
  int start, end;   // [start, end) indices
  double m, b;      // y = m*x + b
  Segment(int s, int e, double m_, double b_) { start = s; end = e; m = m_; b = b_; }
}

ArrayList<Segment> pwlCompress(float[] y, float eps) {
  int n = y.length;
  ArrayList<Segment> segs = new ArrayList<Segment>();
  int start = 0;

  while (start < n) {
    int end = start + 2; // need at least 2 pts to define a line
    int bestEnd = start + 1;
    double bestM = 0.0, bestB = y[start];

    while (end <= n) {
      // Fit y = m*x + b on indices [start, end)
      FitResult fr = fitLine(y, start, end);
      double maxErr = maxAbsError(y, start, end, fr.m, fr.b);

      if (maxErr <= eps) {
        bestEnd = end;
        bestM = fr.m;
        bestB = fr.b;
        end++;
      } else {
        break;
      }
    }

    // finalize segment
    segs.add(new Segment(start, bestEnd, bestM, bestB));
    start = bestEnd;
  }
  return segs;
}

static class FitResult {
  double m, b;
  FitResult(double m_, double b_) { m = m_; b = b_; }
}

FitResult fitLine(float[] y, int s, int e) {
  // Least squares line fit over integer x = s..e-1
  int n = e - s;
  if (n == 1) return new FitResult(0.0, y[s]);

  double sx = 0, sy = 0, sxx = 0, sxy = 0;
  for (int i = s; i < e; i++) {
    double xi = i;
    double yi = y[i];
    sx  += xi;
    sy  += yi;
    sxx += xi * xi;
    sxy += xi * yi;
  }
  double denom = (n * sxx - sx * sx);
  if (Math.abs(denom) < 1e-12) {
    // vertical-ish; fallback to constant
    double mean = sy / n;
    return new FitResult(0.0, mean);
  }
  double m = (n * sxy - sx * sy) / denom;
  double b = (sy - m * sx) / n;
  return new FitResult(m, b);
}

double maxAbsError(float[] y, int s, int e, double m, double b) {
  double mx = 0.0;
  for (int i = s; i < e; i++) {
    double pred = m * i + b;
    double err = Math.abs(pred - y[i]);
    if (err > mx) mx = err;
  }
  return mx;
}

float[] pwlDecompress(ArrayList<Segment> segs, int length) {
  float[] out = new float[length];
  for (Segment g : segs) {
    for (int i = g.start; i < g.end; i++) {
      double v = g.m * i + g.b;
      out[i] = (float)v;
    }
  }
  return out;
}

// -------------------------- Serialization & ZIP --------------------------

byte[] floatsToBytes(float[] a) {
  ByteBuffer bb = ByteBuffer.allocate(a.length * 4).order(ByteOrder.LITTLE_ENDIAN);
  for (int i = 0; i < a.length; i++) bb.putFloat(a[i]);
  return bb.array();
}

byte[] segmentsToBytes(ArrayList<Segment> segs, int length) {
  // Each segment: int start, int end, double m, double b
  int segSize = 4 + 4 + 8 + 8;
  ByteBuffer bb = ByteBuffer.allocate(4 + segs.size() * segSize).order(ByteOrder.LITTLE_ENDIAN);
  bb.putInt(length);
  for (Segment s : segs) {
    bb.putInt(s.start);
    bb.putInt(s.end);
    bb.putDouble(s.m);
    bb.putDouble(s.b);
  }
  return bb.array();
}

long zipBytesSize(byte[] data, String entryName) {
  try {
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    ZipOutputStream zos = new ZipOutputStream(baos);
    zos.setLevel(9); // max deflate
    ZipEntry ze = new ZipEntry(entryName);
    zos.putNextEntry(ze);
    zos.write(data);
    zos.closeEntry();
    zos.close();
    byte[] zipped = baos.toByteArray();
    return zipped.length;
  } catch (Exception ex) {
    ex.printStackTrace();
    return -1;
  }
}

// -------------------------- UI: text + plot --------------------------

void drawHeader() {
  fill(20);
  textAlign(LEFT, TOP);
  textSize(18);
  text("Piecewise-Linear (Lossy) Compression + ZIP Size Demo", 20, 16);
  textSize(12);
  text("Press 1 → ε=0.010   |   Press 2 → ε=0.025   |   Press S → save plot", 20, 40);
}

void drawStats() {
  int y0 = 420;
  textAlign(LEFT, TOP);
  textSize(14);
  fill(0);

  double avgPtsPerSeg = segmentsCount > 0 ? (double)N / (double)segmentsCount : 0.0;

  String[] lines = new String[] {
    String.format("N = %,d   |   epsilon = %.3f   |   segments = %,d", N, eps, segmentsCount),
    String.format("Average points per segment = %.2f", avgPtsPerSeg),
    String.format("Errors:   MAE = %.6f   RMSE = %.6f   MaxAbsErr = %.6f", mae, rmse, maxAbs),
    String.format("Raw float32 bytes = %,d", rawBytes),
    String.format("Zipped raw (DEFLATE) bytes = %,d", zippedRawBytes),
    String.format("PWL binary bytes = %,d", pwlBytes),
    String.format("Zipped PWL (DEFLATE) bytes = %,d", zippedPwlBytes),
    String.format("Compression ratio (zipped PWL / raw) = %.4f×", compressionRatioVsRaw)
  };

  int yy = y0;
  for (String s : lines) {
    text(s, 20, yy);
    yy += 22;
  }
}

void drawPlot() {
  // Plot area
  int left = 60, top = 90, right = width - 40, bottom = 400;
  int w = right - left;
  int h = bottom - top;

  // Frame
  stroke(180);
  noFill();
  rect(left, top, w, h);

  // Find range over the slice to scale nicely
  int n = min(plotCount, N);
  float minV = Float.POSITIVE_INFINITY, maxV = Float.NEGATIVE_INFINITY;
  for (int i = 0; i < n; i++) {
    minV = min(minV, min(signal[i], recon[i]));
    maxV = max(maxV, max(signal[i], recon[i]));
  }
  // add a little padding
  float pad = (maxV - minV) * 0.05f + 1e-6f;
  float yMin = minV - pad, yMax = maxV + pad;

  // Axes labels
  fill(0);
  textAlign(LEFT, BOTTOM);
  textSize(12);
  text("0", left, bottom + 16);
  text("" + (n-1), right - 20, bottom + 16);
  textAlign(LEFT, TOP);
  text(String.format("%.3f", yMax), left + 4, top - 18);
  textAlign(LEFT, TOP);
  text(String.format("%.3f", yMin), left + 4, bottom + 4);

  // Helper mapping
  final int L = left, T = top;
  final float Xs = (float)w / (float)(n - 1);
  // invert y for screen coords
  // y_screen = T + (yMax - y) * (h / (yMax - yMin))
  float Ys = (float)h / (yMax - yMin);

  // Draw original (blue)
  stroke(40, 80, 220);
  noFill();
  beginShape();
  for (int i = 0; i < n; i++) {
    float xs = L + i * Xs;
    float ys = T + (float)((yMax - signal[i]) * Ys);
    vertex(xs, ys);
  }
  endShape();

  // Draw reconstruction (orange)
  stroke(245, 140, 40);
  noFill();
  beginShape();
  for (int i = 0; i < n; i++) {
    float xs = L + i * Xs;
    float ys = T + (float)((yMax - recon[i]) * Ys);
    vertex(xs, ys);
  }
  endShape();

  // Legend
  noStroke();
  fill(40, 80, 220);
  rect(left + 8, top + 8, 14, 14);
  fill(20);
  textAlign(LEFT, CENTER);
  text("original", left + 28, top + 14);
  fill(245, 140, 40);
  rect(left + 110, top + 8, 14, 14);
  fill(20);
  text("PWL recon", left + 130, top + 14);

// --- Add axis ticks ---
stroke(200);
fill(100);
textSize(10);

// Y ticks (5 divisions)
for (int i = 0; i <= 5; i++) {
  float frac = i / 5.0;
  float yy = top + h - frac * h;
  float val = yMin + frac * (yMax - yMin);
  line(left - 4, yy, left, yy); // tick
  textAlign(RIGHT, CENTER);
  text(String.format("%.2f", val), left - 8, yy);
}

// X ticks (10 divisions)
for (int i = 0; i <= 10; i++) {
  float frac = i / 10.0;
  float xx = left + frac * w;
  int idx = (int)(frac * (n - 1));
  line(xx, bottom, xx, bottom + 4); // tick
  textAlign(CENTER, TOP);
  text("" + idx, xx, bottom + 6);
}

  // Title
  textAlign(LEFT, TOP);
  textSize(14);
  fill(0);
  text("First " + n + " samples: original vs. piecewise-linear reconstruction", left, top - 28);
}
