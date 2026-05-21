// Processing 4.x
// KAN-lite SDR compressor demo (1D) with:
// - non-bleeding legend box
// - progress bar and busy gating
// - background-threaded compress/decompress/save/load
// - UI controls disabled while busy

import java.nio.*;
import java.io.*;
import java.util.*;

// ---------------- UI ----------------
float tol = 0.5;            // tolerance (max-abs per block)
int blockSize = 4096;       // default block size
int Kmax = 8;               // max KAN terms per block
int M = 16;                 // control points per φ spline
int viewOffset = 0;         // visualization window offset
int viewLen = 2048;         // visualization window length

// UI ranges
float tolMin = 0.0, tolMax = 5.0;
int blockMin = 512, blockMax = 65536;
int kMin = 1, kMax = 32;
int mMin = 8, mMax = 64;

// Busy/progress
volatile boolean isBusy = false;
volatile float progress = 0.0f;  // 0..1
volatile String busyTask = "";

// Data
float[] raw = null;
float[] recon = null;

// Compression model per block
ArrayList<KANBlock> blocks = new ArrayList<>();
int nBlocks = 0;

// Stats
long storedParams = 0;    // total φ control points stored
long storedBytes = 0;     // FP16 assumption (2 bytes per control point) for CR display
String loadedPath = "";
boolean haveCompressed = false;
boolean haveDecompressed = false;

// File paths (populated by file chooser)
String pendingF32Path = null;
String pendingKANSavePath = null;
String pendingKANLoadPath = null;

// ---------------- Setup & Draw ----------------
void settings() {
  size(1200, 780);
}

void setup() {
  surface.setTitle("KAN-lite SDR Compression Demo (Processing) — with Progress & Busy UI");
  textFont(createFont("Menlo", 13));
}

void draw() {
  background(250);

  // Controls
  int x = 20, y = 20, dy = 26;
  fill(0);
  text("KAN-lite SDR Compressor", x, y); y += dy;

  drawButton(x, y, 130, 28, "Load .f32", !isBusy);
  drawButton(x+140, y, 130, 28, "Compress", !isBusy && raw != null);
  drawButton(x+280, y, 130, 28, "Save .kan", !isBusy && haveCompressed);
  drawButton(x+420, y, 130, 28, "Load .kan", !isBusy);
  drawButton(x+560, y, 130, 28, "Decompress", !isBusy && !blocks.isEmpty());
  y += dy + 8;

  tol = drawSliderF(x, y, 240, "Tolerance", tol, tolMin, tolMax, !isBusy); y += dy;
  blockSize = drawSliderI(x, y, 240, "BlockSize", blockSize, blockMin, blockMax, true, !isBusy); y += dy;
  Kmax = drawSliderI(x, y, 240, "K terms (max)", Kmax, kMin, kMax, false, !isBusy); y += dy;
  M = drawSliderI(x, y, 240, "M control pts", M, mMin, mMax, false, !isBusy); y += dy;

  if (raw != null) {
    viewOffset = drawSliderI(x, y, 240, "Window Offset", viewOffset, 0, max(0, raw.length-1), true, !isBusy); y += dy;
    viewLen = drawSliderI(x, y, 240, "Window Length", viewLen, 256, min(200000, max(256, raw.length)), true, !isBusy); y += dy;
  }

  // Info panel
  y += 8;
  fill(0);
  text("Loaded: " + (loadedPath.isEmpty()? "(none)" : loadedPath), x, y); y += dy;
  if (raw != null) {
    text("Data points: " + raw.length, x, y); y += dy;
  }
  if (haveCompressed) {
    text("Blocks: " + nBlocks + "   Stored φ coeffs: " + storedParams + "   Stored bytes (FP16): " + storedBytes, x, y); y += dy;
    float rawBytes = (raw!=null) ? raw.length * 4.0 : 0;
    float CR = (storedBytes>0 && rawBytes>0) ? (rawBytes / storedBytes) : 0;
    text(String.format("Compression Ratio (raw FP32 / φ FP16): %.3f", CR), x, y); y += dy;
  }

  // Plot frame
  int plotX = 400, plotY = 90, plotW = width - plotX - 20, plotH = height - plotY - 20;
  stroke(220); noFill();
  rect(plotX, plotY, plotW, plotH);

  // Legend: draw inside the plot, but in a padded opaque box so it never bleeds into lines
  drawLegendBox(plotX, plotY, plotW);

  // Plot data
  if (raw != null) {
    int start = constrain(viewOffset, 0, raw.length-1);
    int end   = constrain(start + viewLen, 0, raw.length);
    if (end - start > 1) {
      // autoscale
      float rmin = +Float.MAX_VALUE, rmax = -Float.MAX_VALUE;
      for (int i = start; i < end; i++) { float v = raw[i]; if (v < rmin) rmin = v; if (v > rmax) rmax = v; }
      if (recon != null && haveDecompressed) {
        for (int i = start; i < end; i++) { float v = recon[i]; if (v < rmin) rmin = v; if (v > rmax) rmax = v; }
      }
      if (rmax <= rmin) { rmax = rmin + 1e-3f; }

      // leave inner margin to keep lines away from legend area
      int leftPad = 10, rightPad = 10, topPad = 50, bottomPad = 10;

      // original
      stroke(20, 80, 255);
      noFill();
      beginShape();
      for (int i = start; i < end; i++) {
        float t = map(i, start, end-1, plotX+leftPad, plotX+plotW-rightPad);
        float v = map(raw[i], rmin, rmax, plotY+plotH-bottomPad, plotY+topPad);
        vertex(t, v);
      }
      endShape();

      // recon
      if (recon != null && haveDecompressed) {
        stroke(220, 40, 40);
        noFill();
        beginShape();
        for (int i = start; i < end; i++) {
          float t = map(i, start, end-1, plotX+leftPad, plotX+plotW-rightPad);
          float v = map(recon[i], rmin, rmax, plotY+plotH-bottomPad, plotY+topPad);
          vertex(t, v);
        }
        endShape();
      }

      // error stats for window
      if (recon != null && haveDecompressed) {
        float mae=0, maxe=0;
        int n = end-start;
        for (int i = start; i < end; i++) {
          float e = abs(raw[i] - recon[i]);
          mae += e; if (e > maxe) maxe = e;
        }
        mae /= max(1, n);
        fill(0);
        text(String.format("Window MAE: %.5f   MaxAbs: %.5f", mae, maxe), plotX+12, plotY+plotH-16);
      }
    }
  }

  // Busy overlay + progress bar
  if (isBusy) {
    drawBusyOverlay();
  }
}

// ---------------- Legend ----------------
void drawLegendBox(int plotX, int plotY, int plotW) {
  // box in the upper-left of plot with padding
  int boxW = 250, boxH = 50;
  int bx = plotX + 10;
  int by = plotY + 10;
  noStroke();
  fill(255, 255, 255, 230);
  rect(bx, by, boxW, boxH, 8);
  // title
  fill(0);
  text("Original vs Decompressed", bx + 10, by + 18);
  // entries
  int ly = by + 34;
  // original
  stroke(20, 80, 255); line(bx + 12, ly, bx + 52, ly);
  noStroke(); fill(0); text("Original", bx + 60, ly + 4);
  // recon
  stroke(220, 40, 40); line(bx + 128, ly, bx + 168, ly);
  noStroke(); fill(0); text("Decompressed", bx + 176, ly + 4);
}

// ---------------- Busy & Progress UI ----------------
void drawBusyOverlay() {
  // translucent overlay
  noStroke();
  fill(255, 255, 255, 200);
  rect(0, 0, width, height);

  // progress bar centered
  int bw = 520, bh = 70;
  int bx = (width - bw) / 2;
  int by = height / 2 - bh;
  // box
  fill(245);
  stroke(180);
  rect(bx, by, bw, bh, 10);

  // label
  fill(0);
  textAlign(CENTER, CENTER);
  text(busyTask + " … " + nf(progress*100, 0, 1) + "%", bx + bw/2, by + 20);

  // bar
  int barX = bx + 20, barY = by + 40, barW = bw - 40, barH = 18;
  noStroke();
  fill(230);
  rect(barX, barY, barW, barH, 8);
  fill(100, 160, 255);
  int pw = (int)(barW * constrain(progress, 0, 1));
  rect(barX, barY, pw, barH, 8);

  textAlign(LEFT, BASELINE);
}

// ---------------- Buttons & Sliders ----------------
boolean overRect(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
}

void drawButton(int x, int y, int w, int h, String label, boolean enabled) {
  stroke(180);
  if (!enabled) fill(230);
  else fill(overRect(x,y,w,h) ? 230 : 245);
  rect(x, y, w, h, 6);
  fill(enabled ? 0 : 120);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  textAlign(LEFT, BASELINE);
}

float drawSliderF(int x, int y, int w, String name, float val, float vmin, float vmax, boolean enabled) {
  int h = 18;
  int sliderW = w;
  float t = map(val, vmin, vmax, 0, sliderW);
  stroke(200); line(x, y+h/2, x+sliderW, y+h/2);
  fill(enabled ? 120 : 180);
  circle(x+(int)t, y+h/2, 12);
  fill(0); text(String.format("%s: %.4f", name, val), x + w + 10, y + h - 2);
  if (enabled && mousePressed && overRect(x, y, sliderW, h)) {
    float nt = constrain(mouseX - x, 0, sliderW);
    val = map(nt, 0, sliderW, vmin, vmax);
  }
  return val;
}

int drawSliderI(int x, int y, int w, String name, int val, int vmin, int vmax, boolean pow2, boolean enabled) {
  int h = 18;
  int sliderW = w;
  float t = (float)(val - vmin) / (float)(vmax - vmin);
  stroke(200); line(x, y+h/2, x+sliderW, y+h/2);
  fill(enabled ? 120 : 180);
  circle(x+(int)(t*sliderW), y+h/2, 12);
  fill(0); text(name + ": " + val, x + w + 10, y + h - 2);
  if (enabled && mousePressed && overRect(x, y, sliderW, h)) {
    float nt = constrain(mouseX - x, 0, sliderW);
    float f = nt / sliderW;
    int nv = (int)round(vmin + f * (vmax - vmin));
    if (pow2) nv = max(vmin, min(vmax, nearestPow2(nv)));
    val = nv;
  }
  return val;
}

int nearestPow2(int v) {
  int p = 1;
  while (p < v) p <<= 1;
  int prev = p >> 1;
  if (prev == 0) return p;
  return (p - v < v - prev) ? p : prev;
}

// ---------------- Mouse ----------------
void mousePressed() {
  if (isBusy) return; // disabled while busy
  int x = 20, y = 46;
  if (overRect(x, y, 130, 28)) { onLoadF32(); }
  if (overRect(x+140, y, 130, 28)) { onCompress(); }
  if (overRect(x+280, y, 130, 28)) { onSaveKAN(); }
  if (overRect(x+420, y, 130, 28)) { onLoadKAN(); }
  if (overRect(x+560, y, 130, 28)) { onDecompress(); }
}

// ---------------- Busy helpers ----------------
void busyStart(String task) {
  isBusy = true;
  progress = 0.0f;
  busyTask = task;
}

void busyEnd() {
  progress = 1.0f;
  isBusy = false;
  busyTask = "";
}

// ---------------- File I/O (launchers) ----------------
void onLoadF32() {
  selectInput("Choose .f32 (little-endian float32)", "fileSelectedF32");
}
void fileSelectedF32(File sel) {
  if (sel == null) return;
  pendingF32Path = sel.getAbsolutePath();
  thread("taskLoadF32");
}

void onSaveKAN() {
  if (!haveCompressed || blocks.isEmpty()) return;
  selectOutput("Save compressed .kan", "fileSelectedSaveKAN");
}
void fileSelectedSaveKAN(File sel) {
  if (sel == null) return;
  pendingKANSavePath = sel.getAbsolutePath();
  thread("taskSaveKAN");
}

void onLoadKAN() {
  selectInput("Choose .kan file", "fileSelectedKAN");
}
void fileSelectedKAN(File sel) {
  if (sel == null) return;
  pendingKANLoadPath = sel.getAbsolutePath();
  thread("taskLoadKAN");
}

void onDecompress() {
  if (raw == null && blocks.isEmpty()) return;
  thread("taskDecompress");
}

void onCompress() {
  if (raw == null) return;
  thread("taskCompress");
}

// ---------------- Threaded tasks ----------------
void taskLoadF32() {
  busyStart("Loading .f32");
  try {
    File f = new File(pendingF32Path);
    long sz = f.length();
    int nFloats = (int)(sz / 4L);
    float[] a = new float[nFloats];
    DataInputStream dis = new DataInputStream(new BufferedInputStream(new FileInputStream(f)));
    byte[] buf = new byte[4 * 8192];
    int got;
    int idx = 0;
    long readBytes = 0;
    ByteBuffer bb = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN);
    while ((got = dis.read(buf)) != -1) {
      for (int i = 0; i < got; i += 4) {
        if (i + 3 >= got) break;
        bb.clear();
        bb.put(buf, i, 4);
        bb.flip();
        if (idx < nFloats) a[idx++] = bb.getFloat();
      }
      readBytes += got;
      progress = (float)readBytes / (float)sz;
    }
    dis.close();
    raw = a;
    recon = null;
    blocks.clear();
    haveCompressed = false;
    haveDecompressed = false;
    loadedPath = pendingF32Path;
  } catch(Exception e) {
    e.printStackTrace();
  } finally {
    busyEnd();
  }
}

void taskSaveKAN() {
  busyStart("Saving .kan");
  try {
    saveKAN_streaming(pendingKANSavePath);
  } catch(Exception e) {
    e.printStackTrace();
  } finally {
    busyEnd();
  }
}

void taskLoadKAN() {
  busyStart("Loading .kan");
  try {
    loadKAN_streaming(pendingKANLoadPath);
  } catch(Exception e) {
    e.printStackTrace();
  } finally {
    busyEnd();
  }
}

void taskDecompress() {
  busyStart("Decompressing");
  try {
    reconstruct_withProgress();
  } catch(Exception e) {
    e.printStackTrace();
  } finally {
    busyEnd();
  }
}

void taskCompress() {
  busyStart("Compressing");
  try {
    compressAll_withProgress();
    reconstruct_withProgress();
    haveCompressed = true;
    haveDecompressed = true;
  } catch(Exception e) {
    e.printStackTrace();
  } finally {
    busyEnd();
  }
}

// ---------------- Core: Compression ----------------
void compressAll_withProgress() {
  blocks.clear();
  int N = raw.length;
  nBlocks = (N + blockSize - 1)/blockSize;
  storedParams = 0;
  for (int b = 0; b < nBlocks; b++) {
    int s = b*blockSize;
    int e = min(N, s+blockSize);
    float[] y = Arrays.copyOfRange(raw, s, e);
    KANBlock kb = fitKANBlock(y, Kmax, M, tol);
    kb.start = s;
    kb.end   = e;
    blocks.add(kb);
    storedParams += (long)(kb.K * kb.M); // φ control points only
    progress = (float)(b+1) / (float)nBlocks;
  }
  // Assume FP16 storage for φ control points
  storedBytes = storedParams * 2L;
}

void reconstruct_withProgress() {
  if (raw == null && blocks.isEmpty()) return;
  int N = 0;
  for (KANBlock kb : blocks) N = max(N, kb.end);
  if (raw != null) N = max(N, raw.length);
  recon = new float[N];
  int B = blocks.size();
  for (int bi = 0; bi < B; bi++) {
    KANBlock kb = blocks.get(bi);
    int len = kb.end - kb.start;
    float[] out = kb.eval(len);
    arrayCopy(out, 0, recon, kb.start, len);
    progress = (float)(bi+1)/(float)B;
  }
}

// Fit one block with up to K terms; stop early if max-abs error <= tol
KANBlock fitKANBlock(float[] y, int Kmax, int M, float tol) {
  int n = y.length;
  float[] x = new float[n];
  for (int i = 0; i < n; i++) x[i] = (n == 1) ? 0.0f : (float)i/(float)(n-1);

  // Build fixed ψ_i templates (diverse)
  ArrayList<Spline1D> psi = new ArrayList<>();
  for (int i = 0; i < Kmax; i++) psi.add(makePsiTemplate(i, M));

  // Greedy additive fit on φ_i
  float[] reconB = new float[n];
  float[] resid = Arrays.copyOf(y, n);
  ArrayList<Spline1D> phi = new ArrayList<>();
  int Kused = 0;

  for (int k = 0; k < Kmax; k++) {
    Spline1D psi_k = psi.get(k);
    float[] u = new float[n];
    for (int i = 0; i < n; i++) u[i] = psi_k.eval(x[i]);

    // Fit φ_k(u) ~= resid via LS over PWL control points
    Spline1D phi_k = fitPhiByLS(u, resid, M, 0.0f);
    phi.add(phi_k);
    Kused++;

    // Update recon and resid
    for (int i = 0; i < n; i++) {
      reconB[i] += phi_k.eval(u[i]);
      resid[i] = y[i] - reconB[i];
    }

    // Check tolerance
    float maxe = 0;
    for (int i = 0; i < n; i++) maxe = max(maxe, abs(resid[i]));
    if (maxe <= tol) break;
  }

  return new KANBlock(Kused, M, psi.subList(0, Kused), phi, 0, n);
}

// Make a fixed ψ template (PWL on [0,1]) with diverse shapes by index
Spline1D makePsiTemplate(int idx, int M) {
  float[] cp = new float[M];
  float f = 1.0f + (idx % 6); // pseudo frequency
  float phase = (idx * 0.37f) % 1.0f;
  for (int j = 0; j < M; j++) {
    float t = (float)j/(float)(M-1);
    float u = (t + phase) % 1.0f;
    // Mix of sin and identity for diversity; bounded [-1,1]
    float v = 0.6f*sin(TWO_PI*f*u) + 0.4f*(2.0f*u - 1.0f);
    cp[j] = v;
  }
  return new Spline1D(cp);
}

// Given u[i] in [-1,1] (or any range), fit φ(u) := PWL with M points on [umin, umax]
Spline1D fitPhiByLS(float[] u, float[] target, int M, float ridge) {
  int n = u.length;
  float umin = +Float.MAX_VALUE, umax = -Float.MAX_VALUE;
  for (int i = 0; i < n; i++) { umin = min(umin, u[i]); umax = max(umax, u[i]); }
  if (umax <= umin) { umax = umin + 1e-6f; }

  float[] knots = new float[M];
  for (int j = 0; j < M; j++) knots[j] = lerp(umin, umax, (float)j/(float)(M-1));

  // Normal equations A c = b
  double[][] A = new double[M][M];
  double[] b = new double[M];

  for (int i = 0; i < n; i++) {
    float val = u[i];
    int j = clampIndex(val, knots);
    int j2 = min(M-1, j+1);
    float t = (knots[j2] - knots[j] > 0) ? (val - knots[j])/(knots[j2]-knots[j]) : 0;
    double wj = 1.0 - t;
    double wj2 = t;

    A[j][j]   += wj*wj;
    A[j2][j2] += wj2*wj2;
    A[j][j2]  += wj*wj2;
    A[j2][j]  += wj2*wj; // symmetric
    double yi = target[i];
    b[j]  += wj*yi;
    b[j2] += wj2*yi;
  }
  for (int j = 0; j < M; j++) A[j][j] += ridge;

  double[] c = solveSymmetric(A, b);

  float[] cp = new float[M];
  for (int j = 0; j < M; j++) cp[j] = (float)c[j];
  Spline1D sp = new Spline1D(cp);
  sp.knots = knots;
  return sp;
}

int clampIndex(float val, float[] knots) {
  int M = knots.length;
  if (val <= knots[0]) return 0;
  if (val >= knots[M-1]) return M-2;
  int lo = 0, hi = M-1;
  while (hi - lo > 1) {
    int mid = (lo + hi)/2;
    if (val < knots[mid]) hi = mid;
    else lo = mid;
  }
  return lo;
}

double[] solveSymmetric(double[][] A, double[] b) {
  int n = b.length;
  double[][] Mtx = new double[n][n];
  double[] rhs = new double[n];
  for (int i = 0; i < n; i++) {
    rhs[i] = b[i];
    for (int j = 0; j < n; j++) Mtx[i][j] = A[i][j];
  }
  for (int k = 0; k < n; k++) {
    int piv = k;
    double best = Math.abs(Mtx[k][k]);
    for (int i = k+1; i < n; i++) {
      double v = Math.abs(Mtx[i][k]);
      if (v > best) { best = v; piv = i; }
    }
    if (piv != k) {
      double[] tmp = Mtx[k]; Mtx[k] = Mtx[piv]; Mtx[piv] = tmp;
      double tt = rhs[k]; rhs[k] = rhs[piv]; rhs[piv] = tt;
    }
    double diag = Mtx[k][k];
    if (Math.abs(diag) < 1e-12) diag = 1e-12;
    for (int j = k; j < n; j++) Mtx[k][j] /= diag;
    rhs[k] /= diag;
    for (int i = k+1; i < n; i++) {
      double f = Mtx[i][k];
      if (f == 0) continue;
      for (int j = k; j < n; j++) Mtx[i][j] -= f * Mtx[k][j];
      rhs[i] -= f * rhs[k];
    }
  }
  double[] x = new double[n];
  for (int i = n-1; i >= 0; i--) {
    double sum = rhs[i];
    for (int j = i+1; j < n; j++) sum -= Mtx[i][j] * x[j];
    x[i] = sum;
  }
  return x;
}

// ---------------- Data Structures ----------------
class Spline1D {
  float[] cp;     // control points
  float[] knots;  // optional explicit knots
  Spline1D(float[] cp) {
    this.cp = cp;
    this.knots = null;
  }
  float eval(float x) {
    int M = cp.length;
    if (knots == null) {
      float t = constrain(x, 0, 1);
      float u = t * (M-1);
      int j = floor(u);
      int j2 = min(M-1, j+1);
      float a = u - j;
      return lerp(cp[j], cp[j2], a);
    } else {
      float v = x;
      int j = clampIndex(v, knots);
      int j2 = j+1;
      float denom = (float)(knots[j2] - knots[j]);
      float a = denom > 0 ? (v - knots[j]) / denom : 0;
      a = constrain(a, 0, 1);
      return lerp(cp[j], cp[j2], a);
    }
  }
}

class KANBlock {
  int K;      // number of terms used
  int M;      // control points per φ
  int start, end;
  ArrayList<Spline1D> psi; // fixed templates size K
  ArrayList<Spline1D> phi; // learned splines size K

  KANBlock(int K, int M, List<Spline1D> psi, List<Spline1D> phi, int s, int e) {
    this.K = K; this.M = M;
    this.psi = new ArrayList<>(psi);
    this.phi = new ArrayList<>(phi);
    this.start = s; this.end = e;
  }

  float[] eval(int n) {
    float[] out = new float[n];
    for (int i = 0; i < n; i++) {
      float x = (n==1) ? 0.0f : (float)i/(float)(n-1);
      float sum = 0;
      for (int k = 0; k < K; k++) {
        float u = psi.get(k).eval(x);
        sum += phi.get(k).eval(u);
      }
      out[i] = sum;
    }
    return out;
  }
}

// ---------------- Streaming save/load (.kan) ----------------
// Format:
// [magic 'K','A','N','1'] [int32 N] [int32 blockSize] [int32 Kmax] [int32 M] [int32 B]
// per-block: [int32 start][int32 end][int32 K]
//   then K times: [M * float32 φ control points] + [uint8 psiTemplateId]

void saveKAN_streaming(String path) throws IOException {
  if (blocks.isEmpty()) return;
  DataOutputStream dos = new DataOutputStream(new BufferedOutputStream(new FileOutputStream(path)));
  try {
    int N = (raw!=null)? raw.length : (recon!=null? recon.length : 0);
    // header
    dos.writeByte('K'); dos.writeByte('A'); dos.writeByte('N'); dos.writeByte('1');
    dos.writeInt(N);
    dos.writeInt(blockSize);
    dos.writeInt(Kmax);
    dos.writeInt(M);
    dos.writeInt(blocks.size());

    int B = blocks.size();
    long totalItems = 0;
    for (KANBlock kb : blocks) totalItems += 3 + kb.K * (M + 1); // approx items
    long done = 0;

    for (int bi = 0; bi < B; bi++) {
      KANBlock kb = blocks.get(bi);
      dos.writeInt(kb.start); done++;
      dos.writeInt(kb.end);   done++;
      dos.writeInt(kb.K);     done++;
      for (int k = 0; k < kb.K; k++) {
        Spline1D phi = kb.phi.get(k);
        for (int j = 0; j < kb.M; j++) { dos.writeFloat(phi.cp[j]); done++; }
        dos.writeByte((byte)(k & 0xFF)); done++;
      }
      progress = (float)done / (float)max(1, totalItems);
    }
    dos.flush();
  } finally {
    dos.close();
  }
}

void loadKAN_streaming(String path) throws IOException {
  DataInputStream dis = new DataInputStream(new BufferedInputStream(new FileInputStream(path)));
  try {
    int m0 = dis.readUnsignedByte(), m1 = dis.readUnsignedByte(), m2 = dis.readUnsignedByte(), m3 = dis.readUnsignedByte();
    if (m0!='K' || m1!='A' || m2!='N' || m3!='1') throw new IOException("Bad magic");
    int N = dis.readInt();
    blockSize = dis.readInt();
    Kmax = dis.readInt();
    M = dis.readInt();
    int B = dis.readInt();

    blocks.clear();
    storedParams = 0;

    long totalBlocks = B;
    for (int bi = 0; bi < B; bi++) {
      int s = dis.readInt();
      int e = dis.readInt();
      int K = dis.readInt();
      ArrayList<Spline1D> psi = new ArrayList<>();
      ArrayList<Spline1D> phi = new ArrayList<>();
      for (int k = 0; k < K; k++) {
        float[] cp = new float[M];
        for (int j = 0; j < M; j++) cp[j] = dis.readFloat();
        int psiId = dis.readUnsignedByte();
        psi.add(makePsiTemplate(psiId, M));
        phi.add(new Spline1D(cp));
      }
      blocks.add(new KANBlock(K, M, psi, phi, s, e));
      storedParams += (long)K * M;
      progress = (float)(bi+1) / (float)max(1, totalBlocks);
    }
    recon = new float[N];
    loadedPath = path + " (KAN model)";
    haveCompressed = true;
    haveDecompressed = false;
  } finally {
    dis.close();
  }
}

// ---------------- Legacy helpers (unused by threads but kept for reference) ----------------
float[] readF32_simple(String path) throws IOException {
  byte[] bytes = loadBytes(path);
  int n = bytes.length / 4;
  float[] a = new float[n];
  ByteBuffer bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
  for (int i = 0; i < n; i++) a[i] = bb.getFloat();
  return a;
}

// ---------------- END ----------------
