import java.util.Arrays;
import java.util.ArrayList;

/**
 * Hash Constant Explorer for Processing
 * ------------------------------------
 * Live-search hash constants and plot quality metrics.
 *
 * Features:
 * - live plotting while scoring
 * - progress bar
 * - hover tooltip
 * - zoom / pan on main plot
 * - three mini-panels for component metrics
 * - auto-fit main plot until user zooms/pans
 *
 * Controls:
 *   R = restart search
 *   M = toggle mode (sweep/random) and restart
 *   S = save screenshot
 *   +/= = zoom in
 *   -   = zoom out
 *   0   = reset zoom/pan
 *   drag mouse in main plot to pan
 */

ArrayList<Result> results = new ArrayList<Result>();
Result best;
Result hovered;

// ---------------------- USER SETTINGS ----------------------

int SEARCH_MODE = 0;  // 0 = sweep, 1 = random

int CONSTANT_START = 0x00010001;
int CONSTANT_END   = 0x0010FFFF;
int CONSTANT_STEP  = 257;
int RANDOM_SAMPLES = 1200;

int RANDOM_VALUE_COUNT = 256;
int FINAL_EFFECT_COUNT = 300;
int AVALANCHE_TEST_VALUES = 32;

boolean ONLY_ODD = true;
boolean REQUIRE_LOW16_PRIME = false;

int SEED = 1;
int BATCH_PER_FRAME = 8;

// layout
float marginLeft = 90;
float marginRight = 40;
float marginTop = 60;
float marginBottom = 110;

// ----------------------------------------------------------

int[] randomValues;
int[] effectCounts = new int[32 * 32];
int[] dependencyCounts = new int[32 * 32];

// search state
boolean searchRunning = false;
int sweepCurrent;
int randomTested;
RandomLCG searchRng;
int sweepAcceptedTotal = 0;

// cached global plot bounds
float globalMinConst, globalMaxConst, globalMinScore, globalMaxScore;
float globalMinAval, globalMaxAval;
float globalMinEff, globalMaxEff;
float globalMinDep, globalMaxDep;

// view window for main plot
float viewMinConst, viewMaxConst;
float viewMinScore, viewMaxScore;
boolean userChangedView = false;

// dragging
boolean dragging = false;
float dragStartX, dragStartY;
float dragViewMinConst, dragViewMaxConst, dragViewMinScore, dragViewMaxScore;

void setup() {
  size(1200, 700);
  surface.setTitle("Hash Constant Explorer");
  textFont(createFont("Arial", 14));
  startSearch();
}

void draw() {
  if (searchRunning) {
    stepSearch();
  }

  background(245);
  updateBounds();
  drawTitle();
  drawMainPlot();
  updateHoveredPoint();
  drawMiniPanels();
  drawBestPanel();
  drawLegend();
  drawProgressBar();
  drawHoverTooltip();
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    startSearch();
  } else if (key == 'm' || key == 'M') {
    SEARCH_MODE = 1 - SEARCH_MODE;
    startSearch();
  } else if (key == 's' || key == 'S') {
    saveFrame("hash-constant-explorer-####.png");
  } else if (key == '+' || key == '=') {
    zoomMainPlot(0.8);
  } else if (key == '-') {
    zoomMainPlot(1.25);
  } else if (key == '0') {
    resetView();
  }
}

void mousePressed() {
  if (mouseInMainPlot()) {
    dragging = true;
    userChangedView = true;

    dragStartX = mouseX;
    dragStartY = mouseY;
    dragViewMinConst = viewMinConst;
    dragViewMaxConst = viewMaxConst;
    dragViewMinScore = viewMinScore;
    dragViewMaxScore = viewMaxScore;
  }
}

void mouseDragged() {
  if (!dragging) return;

  float plotX = marginLeft;
  float plotY = marginTop + 35;
  float plotW = width - marginLeft - marginRight;
  float plotH = height - marginTop - marginBottom - 210;

  float dx = mouseX - dragStartX;
  float dy = mouseY - dragStartY;

  float constSpan = dragViewMaxConst - dragViewMinConst;
  float scoreSpan = dragViewMaxScore - dragViewMinScore;

  float constShift = -dx / plotW * constSpan;
  float scoreShift = dy / plotH * scoreSpan;

  viewMinConst = dragViewMinConst + constShift;
  viewMaxConst = dragViewMaxConst + constShift;
  viewMinScore = dragViewMinScore + scoreShift;
  viewMaxScore = dragViewMaxScore + scoreShift;

  clampView();
}

void mouseReleased() {
  dragging = false;
}

boolean mouseInMainPlot() {
  float plotX = marginLeft;
  float plotY = marginTop + 35;
  float plotW = width - marginLeft - marginRight;
  float plotH = height - marginTop - marginBottom - 210;
  return mouseX >= plotX && mouseX <= plotX + plotW &&
         mouseY >= plotY && mouseY <= plotY + plotH;
}

void startSearch() {
  results.clear();
  best = null;
  hovered = null;

  randomValues = getRandomValues(RANDOM_VALUE_COUNT, SEED);

  sweepCurrent = CONSTANT_START;
  randomTested = 0;
  searchRng = new RandomLCG(SEED);
  sweepAcceptedTotal = estimateSweepAcceptedCount();

  userChangedView = false;
  resetViewToDefault();

  searchRunning = true;

  println();
  println("Starting search...");
  println("Mode: " + ((SEARCH_MODE == 0) ? "sweep" : "random"));
}

void resetViewToDefault() {
  viewMinConst = 0;
  viewMaxConst = 1;
  viewMinScore = 0;
  viewMaxScore = 1;
}

void stepSearch() {
  int did = 0;

  while (did < BATCH_PER_FRAME && searchRunning) {
    if (SEARCH_MODE == 0) {
      if (!stepSweepOnce()) {
        searchRunning = false;
        println("Sweep search complete. Tested: " + results.size());
        printBestToConsole();
        break;
      }
    } else {
      if (!stepRandomOnce()) {
        searchRunning = false;
        println("Random search complete. Tested: " + results.size());
        printBestToConsole();
        break;
      }
    }
    did++;
  }
}

boolean stepSweepOnce() {
  while (sweepCurrent <= CONSTANT_END) {
    int c = sweepCurrent;
    sweepCurrent += CONSTANT_STEP;

    if (!acceptConstant(c)) continue;

    Result r = evaluateConstant(c);
    results.add(r);

    if (best == null || r.score < best.score) {
      best = r;
    }
    return true;
  }
  return false;
}

boolean stepRandomOnce() {
  while (randomTested < RANDOM_SAMPLES) {
    int c = searchRng.nextInt();
    if (c == 0) continue;
    if (ONLY_ODD) c |= 1;
    c = abs(c);

    if (!acceptConstant(c)) continue;

    Result r = evaluateConstant(c);
    results.add(r);
    randomTested++;

    if (best == null || r.score < best.score) {
      best = r;
    }
    return true;
  }
  return false;
}

void printBestToConsole() {
  if (best == null) return;

  println();
  println("Best constant found: 0x" + hex(best.constant));
  println("score = " + nf((float) best.score, 0, 2));
  println("avalancheAvg = " + nf(best.avalancheAvg, 0, 2));
  println("effectRange = " + best.effectMin + " .. " + best.effectMax +
    " (spread " + best.effectSpread + ")");
  println("dependencyRange = " + best.depMin + " .. " + best.depMax +
    " (spread " + best.dependencySpread + ")");
}

boolean acceptConstant(int c) {
  if (c == 0) return false;
  if (ONLY_ODD && (c & 1) == 0) return false;
  if (REQUIRE_LOW16_PRIME) {
    int low = c & 0xFFFF;
    if (!isPrime(low)) return false;
  }
  return true;
}

int estimateSweepAcceptedCount() {
  int count = 0;
  for (int c = CONSTANT_START; c <= CONSTANT_END; c += CONSTANT_STEP) {
    if (acceptConstant(c)) count++;
  }
  return max(count, 1);
}

float getProgress() {
  if (SEARCH_MODE == 0) {
    return constrain(results.size() / (float) sweepAcceptedTotal, 0, 1);
  } else {
    return constrain(randomTested / (float) max(1, RANDOM_SAMPLES), 0, 1);
  }
}

Result evaluateConstant(int constant) {
  Result r = new Result();
  r.constant = constant;

  float avalancheSum = 0;
  for (int i = 0; i < AVALANCHE_TEST_VALUES; i++) {
    avalancheSum += getAvalanche(constant, randomValues[i % randomValues.length]);
  }
  r.avalancheAvg = avalancheSum / AVALANCHE_TEST_VALUES;
  r.avalanchePenalty = abs(r.avalancheAvg - 16000.0);

  int[] eff = getEffect(constant, FINAL_EFFECT_COUNT, 11);
  r.effectMin = eff[0];
  r.effectMax = eff[1];
  r.effectSpread = r.effectMax - r.effectMin;

  int[] dep = getDependencies(constant, randomValues);
  r.depMin = dep[0];
  r.depMax = dep[1];
  r.dependencySpread = r.depMax - r.depMin;

  r.score = r.avalanchePenalty + r.effectSpread + r.dependencySpread;
  return r;
}

int hashValue(int x, int constant) {
  x = ((x >>> 16) ^ x) * constant;
  x = ((x >>> 16) ^ x) * constant;
  x = (x >>> 16) ^ x;
  return x;
}

int getAvalanche(int constant, int value) {
  int changedBitsSum = 0;

  for (int i = 0; i < 32; i++) {
    int x = value ^ (1 << i);
    for (int shift = 0; shift < 32; shift++) {
      int x1 = hashValue(x, constant);
      int x2 = hashValue(x ^ (1 << shift), constant);
      int x3 = x1 ^ x2;
      changedBitsSum += Integer.bitCount(x3);
    }
  }

  return changedBitsSum * 1000 / 32 / 32;
}

int[] getEffect(int constant, int count, int seed) {
  Arrays.fill(effectCounts, 0);
  RandomLCG r = new RandomLCG(seed);

  for (int i = 0; i < count; i++) {
    int x = r.nextInt();
    for (int shift = 0; shift < 32; shift++) {
      int x1 = hashValue(x, constant);
      int x2 = hashValue(x ^ (1 << shift), constant);
      int x3 = x1 ^ x2;
      for (int s = 0; s < 32; s++) {
        if ((x3 & (1 << s)) != 0) {
          effectCounts[shift * 32 + s]++;
        }
      }
    }
  }

  int mn = Integer.MAX_VALUE;
  int mx = Integer.MIN_VALUE;
  for (int i = 0; i < effectCounts.length; i++) {
    if (effectCounts[i] < mn) mn = effectCounts[i];
    if (effectCounts[i] > mx) mx = effectCounts[i];
  }

  return new int[] { mn, mx };
}

int[] getDependencies(int constant, int[] values) {
  Arrays.fill(dependencyCounts, 0);

  for (int idx = 0; idx < values.length; idx++) {
    int x = values[idx];
    for (int shift = 0; shift < 32; shift++) {
      int x1 = hashValue(x, constant);
      int x2 = hashValue(x ^ (1 << shift), constant);
      int x3 = x1 ^ x2;

      for (int s = 0; s < 32; s++) {
        if ((x3 & (1 << s)) != 0) {
          for (int s2 = 0; s2 < 32; s2++) {
            if (s == s2) continue;
            if ((x3 & (1 << s2)) != 0) {
              dependencyCounts[s * 32 + s2]++;
            }
          }
        }
      }
    }
  }

  int mn = Integer.MAX_VALUE;
  int mx = Integer.MIN_VALUE;
  for (int i = 0; i < dependencyCounts.length; i++) {
    int v = dependencyCounts[i];
    if (v == 0) continue;
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }

  if (mn == Integer.MAX_VALUE) mn = 0;
  if (mx == Integer.MIN_VALUE) mx = 0;

  return new int[] { mn, mx };
}

int[] getRandomValues(int count, int seed) {
  int[] values = new int[count];
  RandomLCG r = new RandomLCG(seed);
  for (int i = 0; i < count; i++) {
    values[i] = r.nextInt();
  }
  return values;
}

boolean isPrime(int n) {
  if (n < 2) return false;
  if ((n & 1) == 0) return n == 2;
  for (int d = 3; d * d <= n; d += 2) {
    if (n % d == 0) return false;
  }
  return true;
}

void updateBounds() {
  if (results.isEmpty()) {
    globalMinConst = 0;
    globalMaxConst = 1;
    globalMinScore = 0;
    globalMaxScore = 1;
    globalMinAval = 0;
    globalMaxAval = 1;
    globalMinEff = 0;
    globalMaxEff = 1;
    globalMinDep = 0;
    globalMaxDep = 1;
    if (!userChangedView) {
      resetView();
    }
    return;
  }

  globalMinConst = Float.MAX_VALUE;
  globalMaxConst = -Float.MAX_VALUE;
  globalMinScore = Float.MAX_VALUE;
  globalMaxScore = -Float.MAX_VALUE;
  globalMinAval = Float.MAX_VALUE;
  globalMaxAval = -Float.MAX_VALUE;
  globalMinEff = Float.MAX_VALUE;
  globalMaxEff = -Float.MAX_VALUE;
  globalMinDep = Float.MAX_VALUE;
  globalMaxDep = -Float.MAX_VALUE;

  for (Result r : results) {
    if (r.constant < globalMinConst) globalMinConst = r.constant;
    if (r.constant > globalMaxConst) globalMaxConst = r.constant;
    if (r.score < globalMinScore) globalMinScore = (float) r.score;
    if (r.score > globalMaxScore) globalMaxScore = (float) r.score;
    if (r.avalanchePenalty < globalMinAval) globalMinAval = r.avalanchePenalty;
    if (r.avalanchePenalty > globalMaxAval) globalMaxAval = r.avalanchePenalty;
    if (r.effectSpread < globalMinEff) globalMinEff = r.effectSpread;
    if (r.effectSpread > globalMaxEff) globalMaxEff = r.effectSpread;
    if (r.dependencySpread < globalMinDep) globalMinDep = r.dependencySpread;
    if (r.dependencySpread > globalMaxDep) globalMaxDep = r.dependencySpread;
  }

  if (abs(globalMaxConst - globalMinConst) < 0.0001) globalMaxConst = globalMinConst + 1;
  if (abs(globalMaxScore - globalMinScore) < 0.0001) globalMaxScore = globalMinScore + 1;
  if (abs(globalMaxAval - globalMinAval) < 0.0001) globalMaxAval = globalMinAval + 1;
  if (abs(globalMaxEff - globalMinEff) < 0.0001) globalMaxEff = globalMinEff + 1;
  if (abs(globalMaxDep - globalMinDep) < 0.0001) globalMaxDep = globalMinDep + 1;

  // auto-fit until user zooms or pans
  if (!userChangedView) {
    viewMinConst = globalMinConst;
    viewMaxConst = globalMaxConst;
    viewMinScore = globalMinScore;
    viewMaxScore = globalMaxScore;
  }
}

void resetView() {
  viewMinConst = globalMinConst;
  viewMaxConst = globalMaxConst;
  viewMinScore = globalMinScore;
  viewMaxScore = globalMaxScore;
  userChangedView = false;
}

void zoomMainPlot(float factor) {
  if (results.isEmpty()) return;

  userChangedView = true;

  float cx = (viewMinConst + viewMaxConst) * 0.5;
  float cy = (viewMinScore + viewMaxScore) * 0.5;
  float halfW = (viewMaxConst - viewMinConst) * 0.5 * factor;
  float halfH = (viewMaxScore - viewMinScore) * 0.5 * factor;

  viewMinConst = cx - halfW;
  viewMaxConst = cx + halfW;
  viewMinScore = cy - halfH;
  viewMaxScore = cy + halfH;

  clampView();
}

void clampView() {
  float minConstSpan = max(1, (globalMaxConst - globalMinConst) * 0.01);
  float minScoreSpan = max(1, (globalMaxScore - globalMinScore) * 0.01);

  if (viewMaxConst - viewMinConst < minConstSpan) {
    float c = (viewMinConst + viewMaxConst) * 0.5;
    viewMinConst = c - minConstSpan * 0.5;
    viewMaxConst = c + minConstSpan * 0.5;
  }

  if (viewMaxScore - viewMinScore < minScoreSpan) {
    float c = (viewMinScore + viewMaxScore) * 0.5;
    viewMinScore = c - minScoreSpan * 0.5;
    viewMaxScore = c + minScoreSpan * 0.5;
  }
}

void drawTitle() {
  fill(20);
  textAlign(LEFT, TOP);
  textSize(22);
  text("Hash Constant Explorer", marginLeft, 16);

  textSize(13);
  text("Live search with auto-fit, zoom, pan, hover, and separate metric panels.", marginLeft, 42);
}

void drawMainPlot() {
  if (results.isEmpty()) return;

  float plotX = marginLeft;
  float plotY = marginTop + 35;
  float plotW = width - marginLeft - marginRight;
  float plotH = height - marginTop - marginBottom - 210;

  stroke(0);
  strokeWeight(1);
  line(plotX, plotY + plotH, plotX + plotW, plotY + plotH);
  line(plotX, plotY, plotX, plotY + plotH);

  stroke(220);
  for (int i = 0; i <= 10; i++) {
    float gy = map(i, 0, 10, plotY + plotH, plotY);
    line(plotX, gy, plotX + plotW, gy);
  }
  for (int i = 0; i <= 10; i++) {
    float gx = map(i, 0, 10, plotX, plotX + plotW);
    line(gx, plotY, gx, plotY + plotH);
  }

  fill(0);
  textSize(12);
  textAlign(CENTER, TOP);
  text("constant", plotX + plotW / 2, plotY + plotH + 38);

  pushMatrix();
  translate(plotX - 55, plotY + plotH / 2);
  rotate(-HALF_PI);
  textAlign(CENTER, TOP);
  text("composite score (lower is better)", 0, 0);
  popMatrix();

  fill(40);
  textAlign(LEFT, TOP);
  text("0x" + hex((int) viewMinConst), plotX, plotY + plotH + 8);
  textAlign(RIGHT, TOP);
  text("0x" + hex((int) viewMaxConst), plotX + plotW, plotY + plotH + 8);

  textAlign(RIGHT, CENTER);
  text(nf(viewMaxScore, 0, 1), plotX - 8, plotY);
  text(nf(viewMinScore, 0, 1), plotX - 8, plotY + plotH);

  noStroke();
  for (Result r : results) {
    float px = map(r.constant, viewMinConst, viewMaxConst, plotX, plotX + plotW);
    float py = map((float) r.score, viewMinScore, viewMaxScore, plotY + plotH, plotY);

    r.screenX = px;
    r.screenY = py;

    if (px < plotX || px > plotX + plotW || py < plotY || py > plotY + plotH) continue;

    float t = map((float) r.score, globalMinScore, globalMaxScore, 0, 1);
    fill(255 * t, 80, 255 * (1 - t), 170);
    ellipse(px, py, 6, 6);
  }

  if (best != null) {
    float bx = map(best.constant, viewMinConst, viewMaxConst, plotX, plotX + plotW);
    float by = map((float) best.score, viewMinScore, viewMaxScore, plotY + plotH, plotY);

    if (bx >= plotX && bx <= plotX + plotW && by >= plotY && by <= plotY + plotH) {
      stroke(0);
      strokeWeight(2);
      fill(0, 200, 80);
      ellipse(bx, by, 14, 14);

      fill(0);
      textAlign(LEFT, BOTTOM);
      text("best", bx + 10, by - 4);
    }
  }
}

void drawMiniPanels() {
  float x = marginLeft;
  float y = height - 180;
  float gap = 16;
  float totalW = width - marginLeft - marginRight;
  float w = (totalW - 2 * gap) / 3.0;
  float h = 95;

  drawMiniPanel(x, y, w, h, "Avalanche penalty", 0);
  drawMiniPanel(x + w + gap, y, w, h, "Effect spread", 1);
  drawMiniPanel(x + 2 * (w + gap), y, w, h, "Dependency spread", 2);
}

void drawMiniPanel(float x, float y, float w, float h, String title, int mode) {
  fill(255);
  stroke(180);
  rect(x, y, w, h, 8);

  fill(0);
  textAlign(LEFT, TOP);
  textSize(12);
  text(title, x + 8, y + 6);

  float px0 = x + 8;
  float py0 = y + 22;
  float pw = w - 16;
  float ph = h - 30;

  stroke(220);
  line(px0, py0 + ph, px0 + pw, py0 + ph);
  line(px0, py0, px0, py0 + ph);

  if (results.isEmpty()) return;

  float minY = 0, maxY = 1;
  if (mode == 0) {
    minY = globalMinAval;
    maxY = globalMaxAval;
  } else if (mode == 1) {
    minY = globalMinEff;
    maxY = globalMaxEff;
  } else {
    minY = globalMinDep;
    maxY = globalMaxDep;
  }

  noStroke();
  fill(70, 130, 220, 150);

  for (Result r : results) {
    float val = 0;
    if (mode == 0) val = r.avalanchePenalty;
    else if (mode == 1) val = r.effectSpread;
    else val = r.dependencySpread;

    float sx = map(r.constant, globalMinConst, globalMaxConst, px0, px0 + pw);
    float sy = map(val, minY, maxY, py0 + ph, py0);
    ellipse(sx, sy, 3.5, 3.5);
  }

  fill(40);
  textAlign(LEFT, BOTTOM);
  text(nf(minY, 0, 1), px0, y + h - 2);
  textAlign(RIGHT, TOP);
  text(nf(maxY, 0, 1), x + w - 8, y + 6);
}

void updateHoveredPoint() {
  hovered = null;
  float bestDistSq = 12 * 12;

  for (Result r : results) {
    float dx = mouseX - r.screenX;
    float dy = mouseY - r.screenY;
    float d2 = dx * dx + dy * dy;
    if (d2 < bestDistSq) {
      bestDistSq = d2;
      hovered = r;
    }
  }
}

void drawHoverTooltip() {
  if (hovered == null || !mouseInMainPlot()) return;

  String line1 = "constant: 0x" + hex(hovered.constant);
  String line2 = "score: " + nf((float) hovered.score, 0, 2);
  String line3 = "avalanche penalty: " + nf(hovered.avalanchePenalty, 0, 2);
  String line4 = "effect spread: " + hovered.effectSpread;
  String line5 = "dependency spread: " + hovered.dependencySpread;

  textSize(12);
  float pad = 8;
  float w = max(textWidth(line1), max(textWidth(line2), max(textWidth(line3), max(textWidth(line4), textWidth(line5))))) + 2 * pad;
  float h = 5 * 16 + 2 * pad;

  float tx = mouseX + 14;
  float ty = mouseY - 10;

  if (tx + w > width - 10) tx = mouseX - w - 14;
  if (ty + h > height - 10) ty = height - h - 10;
  if (ty < 10) ty = 10;

  fill(255, 250, 210, 240);
  stroke(80);
  rect(tx, ty, w, h, 8);

  fill(0);
  textAlign(LEFT, TOP);
  text(line1, tx + pad, ty + pad);
  text(line2, tx + pad, ty + pad + 16);
  text(line3, tx + pad, ty + pad + 32);
  text(line4, tx + pad, ty + pad + 48);
  text(line5, tx + pad, ty + pad + 64);
}

void drawBestPanel() {
  float x = 18;
  float y = 72;
  float w = 430;
  float h = 110;

  fill(255, 255, 255, 235);
  stroke(180);
  rect(x, y, w, h, 10);

  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);

  if (best == null) {
    text("Best constant found: searching...", x + 12, y + 10);
    textSize(12);
    text("Points are plotted as each constant is scored.", x + 12, y + 36);
    return;
  }

  text("Best constant found: 0x" + hex(best.constant), x + 12, y + 10);
  textSize(12);
  text("Composite score: " + nf((float) best.score, 0, 2), x + 12, y + 34);
  text("Avalanche avg: " + nf(best.avalancheAvg, 0, 2) + "   ideal ≈ 16000", x + 12, y + 52);
  text("Effect range: " + best.effectMin + " .. " + best.effectMax + "   spread = " + best.effectSpread, x + 12, y + 68);
  text("Dependency range: " + best.depMin + " .. " + best.depMax + "   spread = " + best.dependencySpread, x + 12, y + 84);
}

void drawLegend() {
  fill(40);
  textAlign(RIGHT, TOP);
  textSize(12);

  String modeName = (SEARCH_MODE == 0) ? "sweep" : "random";
  String status = searchRunning ? "running" : "done";

  text("Mode: " + modeName, width - 20, 18);
  text("Status: " + status, width - 20, 36);
  text("R restart   M toggle   S save", width - 20, 54);
  text("+/- zoom   0 reset   drag pan", width - 20, 72);
  text("Tested constants: " + results.size(), width - 20, 90);
}

void drawProgressBar() {
  float x = marginLeft;
  float y = height - 34;
  float w = width - marginLeft - marginRight;
  float h = 14;

  float p = getProgress();

  noStroke();
  fill(220);
  rect(x, y, w, h, 6);

  fill(70, 140, 255);
  rect(x, y, w * p, h, 6);

  stroke(140);
  noFill();
  rect(x, y, w, h, 6);

  fill(20);
  textAlign(CENTER, BOTTOM);
  textSize(12);
  String label = searchRunning ? "search progress: " : "search complete: ";
  text(label + nf(100 * p, 0, 1) + "%", x + w / 2, y - 4);
}

// ---------------------- SUPPORT TYPES ----------------------

class Result {
  int constant;
  float avalancheAvg;
  float avalanchePenalty;
  int effectMin, effectMax;
  int depMin, depMax;
  int effectSpread;
  int dependencySpread;
  double score;

  float screenX;
  float screenY;
}

class RandomLCG {
  long state;

  RandomLCG(int seed) {
    state = (seed & 0xffffffffL);
    if (state == 0) state = 1;
  }

  int nextInt() {
    state = (1664525L * state + 1013904223L) & 0xffffffffL;
    return (int) state;
  }
}
