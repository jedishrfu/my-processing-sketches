/**
 * SSIM Visualizer (Processing)
 * Illustrates how SSIM cares about "structure" (edges/patterns),
 * not just pixel-by-pixel error like MSE/PSNR.
 *
 * Keys:
 *   1 = Additive Gaussian noise
 *   2 = Blur (destroys structure)
 *   3 = Brightness shift (structure mostly preserved)
 *   4 = Contrast change (structure mostly preserved)
 *   5 = Small spatial shift (structure moved -> SSIM drops)
 *   0 = Reset (no distortion)
 *
 *   U/D = adjust strength up/down
 *   H = toggle heatmap overlay mode
 *
 * Notes:
 * - Uses grayscale and computes SSIM over 8x8 windows with uniform weights.
 * - Heatmap shows per-window SSIM replicated across that window.
 */

PImage orig, dist, heat;
int imgW = 256, imgH = 256;

int mode = 0;            // distortion mode
float strength = 0.35f;  // 0..1

boolean heatOverlay = false;

void settings() {
  size(3*imgW + 80, imgH + 120);
}

void setup() {
  surface.setTitle("SSIM Visualizer - Processing");
  orig = makeTestImage(imgW, imgH);
  dist = orig.copy();
  heat = createImage(imgW, imgH, RGB);
  updateDistortion();
}

void draw() {
  background(20);

  // panels
  int pad = 20;
  int y0 = 20;
  int x1 = pad;
  int x2 = pad + imgW + pad;
  int x3 = pad + 2*(imgW + pad);

  // render images
  image(orig, x1, y0);
  image(dist, x2, y0);

  if (heatOverlay) {
    // show distortion with heat overlay
    image(dist, x3, y0);
    tint(255, 180);
    image(heat, x3, y0);
    noTint();
  } else {
    image(heat, x3, y0);
  }

  // labels
  fill(230);
  textSize(14);
  text("Original", x1, y0 + imgH + 18);
  text("Distorted", x2, y0 + imgH + 18);
  text(heatOverlay ? "Distorted + Local SSIM overlay" : "Local SSIM heatmap", x3, y0 + imgH + 18);

  // metrics
  Metrics m = computeMetrics(orig, dist, 8);
  String modeName = modeName(mode);

  textSize(13);
  int ty = y0 + imgH + 45;
  text("Mode: " + modeName + "   Strength: " + nf(strength, 1, 2), pad, ty);

  ty += 18;
  text("MSE: " + nf(m.mse, 1, 4) + "    PSNR: " + nf(m.psnr, 1, 2) + " dB    SSIM: " + nf(m.ssim, 1, 4),
       pad, ty);

  ty += 18;
  text("Keys: 1 noise, 2 blur, 3 brightness, 4 contrast, 5 shift, 0 reset | U/D strength up/down | H heat overlay",
       pad, ty);

  // subtle frame
  noFill();
  stroke(80);
  rect(x1, y0, imgW, imgH);
  rect(x2, y0, imgW, imgH);
  rect(x3, y0, imgW, imgH);
}

void keyPressed() {
  if (key == '1') mode = 1;
  if (key == '2') mode = 2;
  if (key == '3') mode = 3;
  if (key == '4') mode = 4;
  if (key == '5') mode = 5;
  if (key == '0') mode = 0;

  if (key == 'u' || key == 'U') strength = constrain(strength + 0.05f, 0, 1);
  if (key == 'd' || key == 'D') strength = constrain(strength - 0.05f, 0, 1);

  if (key == 'h' || key == 'H') heatOverlay = !heatOverlay;

  updateDistortion();
}

void updateDistortion() {
  dist = orig.copy();

  switch (mode) {
    case 0: // none
      break;

    case 1: // gaussian noise
      applyGaussianNoise(dist, strength);
      break;

    case 2: // blur
      applyBoxBlur(dist, 1 + int(strength * 10));
      break;

    case 3: // brightness shift
      applyBrightnessShift(dist, (strength - 0.5f) * 140); // ~[-70..+70]
      break;

    case 4: // contrast change
      applyContrast(dist, 0.25f + strength * 2.5f); // ~[0.25..2.75]
      break;

    case 5: // small shift
      applyShift(dist, int((strength - 0.5f) * 16), int((strength - 0.5f) * 16));
      break;
  }

  // compute heatmap for local SSIM
  computeLocalSSIMHeatmap(orig, dist, heat, 8);
}

// ---------- Test image ----------
PImage makeTestImage(int w, int h) {
  PImage img = createImage(w, h, RGB);
  img.loadPixels();

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {

      // gradient + checker + circles/lines = lots of "structure"
      float gx = map(x, 0, w-1, 0, 1);
      float gy = map(y, 0, h-1, 0, 1);

      int checker = ((x / 16) + (y / 16)) % 2;
      float c = checker == 0 ? 0.18f : 0.28f;

      float v = 0.35f*gx + 0.25f*gy + c;

      // concentric rings
      float dx = x - w*0.35f;
      float dy = y - h*0.55f;
      float r = sqrt(dx*dx + dy*dy);
      v += 0.18f * sin(r * 0.22f);

      // diagonal line emphasis
      float d = abs(y - (0.65f*x));
      v += 0.25f * exp(-d*d / (2*18*18));

      v = constrain(v, 0, 1);
      int g = int(v * 255);
      img.pixels[y*w + x] = color(g);
    }
  }

  img.updatePixels();
  return img;
}

// ---------- Distortions ----------
void applyGaussianNoise(PImage img, float amt) {
  // amt 0..1 -> sigma ~ 0..40
  float sigma = amt * 40.0f;
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float g = red(img.pixels[i]);
    float n = (float)randomGaussian() * sigma;
    float out = constrain(g + n, 0, 255);
    img.pixels[i] = color(out);
  }
  img.updatePixels();
}

void applyBrightnessShift(PImage img, float delta) {
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float g = red(img.pixels[i]);
    img.pixels[i] = color(constrain(g + delta, 0, 255));
  }
  img.updatePixels();
}

void applyContrast(PImage img, float factor) {
  // factor 1 = unchanged; >1 increases contrast; <1 decreases
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float g = red(img.pixels[i]);
    float out = (g - 128) * factor + 128;
    img.pixels[i] = color(constrain(out, 0, 255));
  }
  img.updatePixels();
}

void applyShift(PImage img, int sx, int sy) {
  PImage copy = img.copy();
  img.loadPixels();
  copy.loadPixels();
  int w = img.width, h = img.height;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int xx = x - sx;
      int yy = y - sy;
      if (xx >= 0 && xx < w && yy >= 0 && yy < h) {
        img.pixels[y*w + x] = copy.pixels[yy*w + xx];
      } else {
        img.pixels[y*w + x] = color(0);
      }
    }
  }
  img.updatePixels();
}

// Simple box blur (grayscale)
void applyBoxBlur(PImage img, int radius) {
  radius = max(1, radius);
  PImage src = img.copy();
  src.loadPixels();
  img.loadPixels();

  int w = img.width, h = img.height;
  int r = radius;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float sum = 0;
      int count = 0;
      for (int yy = y - r; yy <= y + r; yy++) {
        if (yy < 0 || yy >= h) continue;
        for (int xx = x - r; xx <= x + r; xx++) {
          if (xx < 0 || xx >= w) continue;
          sum += red(src.pixels[yy*w + xx]);
          count++;
        }
      }
      img.pixels[y*w + x] = color(sum / count);
    }
  }

  img.updatePixels();
}

// ---------- SSIM / Metrics ----------
class Metrics {
  float mse;
  float psnr;
  float ssim;
  Metrics(float mse, float psnr, float ssim) {
    this.mse = mse; this.psnr = psnr; this.ssim = ssim;
  }
}

Metrics computeMetrics(PImage a, PImage b, int win) {
  float mse = computeMSE(a, b);
  float psnr = (mse <= 1e-12f) ? 99 : (10.0f * log10((255.0f*255.0f) / mse));
  float ssim = computeSSIM(a, b, win);
  return new Metrics(mse, psnr, ssim);
}

float computeMSE(PImage a, PImage b) {
  a.loadPixels(); b.loadPixels();
  double sum = 0.0;
  int n = a.pixels.length;
  for (int i = 0; i < n; i++) {
    float da = red(a.pixels[i]);
    float db = red(b.pixels[i]);
    float d = da - db;
    sum += d*d;
  }
  return (float)(sum / n);
}

float computeSSIM(PImage a, PImage b, int win) {
  // average SSIM over non-overlapping windows
  a.loadPixels(); b.loadPixels();
  int w = a.width, h = a.height;

  // constants for 8-bit images (classic choices)
  float L = 255.0f;
  float C1 = sq(0.01f * L);
  float C2 = sq(0.03f * L);

  double ssimSum = 0.0;
  int blocks = 0;

  for (int by = 0; by + win <= h; by += win) {
    for (int bx = 0; bx + win <= w; bx += win) {
      // compute mean
      double meanX = 0, meanY = 0;
      int n = win * win;
      for (int y = 0; y < win; y++) {
        int row = (by + y) * w + bx;
        for (int x = 0; x < win; x++) {
          meanX += red(a.pixels[row + x]);
          meanY += red(b.pixels[row + x]);
        }
      }
      meanX /= n;
      meanY /= n;

      // variance + covariance
      double varX = 0, varY = 0, covXY = 0;
      for (int y = 0; y < win; y++) {
        int row = (by + y) * w + bx;
        for (int x = 0; x < win; x++) {
          double px = red(a.pixels[row + x]) - meanX;
          double py = red(b.pixels[row + x]) - meanY;
          varX += px * px;
          varY += py * py;
          covXY += px * py;
        }
      }
      // unbiased-ish not needed; keep consistent
      varX /= (n - 1);
      varY /= (n - 1);
      covXY /= (n - 1);

      double num = (2*meanX*meanY + C1) * (2*covXY + C2);
      double den = (meanX*meanX + meanY*meanY + C1) * (varX + varY + C2);

      double ssim = (den == 0) ? 1.0 : (num / den);

      ssimSum += ssim;
      blocks++;
    }
  }

  return (float)(ssimSum / max(1, blocks));
}

void computeLocalSSIMHeatmap(PImage a, PImage b, PImage out, int win) {
  a.loadPixels(); b.loadPixels();
  out.loadPixels();
  int w = a.width, h = a.height;

  float L = 255.0f;
  float C1 = sq(0.01f * L);
  float C2 = sq(0.03f * L);

  for (int i = 0; i < out.pixels.length; i++) out.pixels[i] = color(0);

  for (int by = 0; by + win <= h; by += win) {
    for (int bx = 0; bx + win <= w; bx += win) {

      double meanX = 0, meanY = 0;
      int n = win * win;

      for (int y = 0; y < win; y++) {
        int row = (by + y) * w + bx;
        for (int x = 0; x < win; x++) {
          meanX += red(a.pixels[row + x]);
          meanY += red(b.pixels[row + x]);
        }
      }
      meanX /= n;
      meanY /= n;

      double varX = 0, varY = 0, covXY = 0;
      for (int y = 0; y < win; y++) {
        int row = (by + y) * w + bx;
        for (int x = 0; x < win; x++) {
          double px = red(a.pixels[row + x]) - meanX;
          double py = red(b.pixels[row + x]) - meanY;
          varX += px * px;
          varY += py * py;
          covXY += px * py;
        }
      }
      varX /= (n - 1);
      varY /= (n - 1);
      covXY /= (n - 1);

      double num = (2*meanX*meanY + C1) * (2*covXY + C2);
      double den = (meanX*meanX + meanY*meanY + C1) * (varX + varY + C2);
      double ssim = (den == 0) ? 1.0 : (num / den);

      // map ssim [-1..1] roughly into [0..1], clamp
      float v = constrain((float)((ssim + 1.0) * 0.5), 0, 1);
      // heatmap: dark (low) to bright (high)
      int col = color(v * 255);

      for (int y = 0; y < win; y++) {
        int row = (by + y) * w + bx;
        for (int x = 0; x < win; x++) {
          out.pixels[row + x] = col;
        }
      }
    }
  }

  out.updatePixels();
}

// ---------- Utils ----------
String modeName(int m) {
  switch(m) {
    case 0: return "None (baseline)";
    case 1: return "Gaussian noise";
    case 2: return "Blur (structure loss)";
    case 3: return "Brightness shift (structure preserved)";
    case 4: return "Contrast change (structure preserved)";
    case 5: return "Small spatial shift (structure moved)";
  }
  return "Unknown";
}

// Processing doesn't have log10() built in; define it.
float log10(float x) {
  return log(x) / log(10);
}
