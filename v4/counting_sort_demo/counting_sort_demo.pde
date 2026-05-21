// Counting Sort + Parallel Prefix Sum (Blelloch Scan)
// Processing sketch with two synchronized views:
//
//   View 1: array-centric
//   View 2: tree-centric
//
// Controls:
//   SPACE -> advance one step
//   A     -> autoplay on/off
//   R     -> randomize new example
//   1     -> array view
//   2     -> tree view
//
// Window fixed to 1200x700.

int W = 1200;
int H = 700;

int N = 18;
int K = 8;
int PADDED_K;

int[] input;
int[] counts;
int[] scanArray;
int[] prefix;
int[] seenSoFar;
int[] output;
int[] outputSourceIdx;

boolean autoPlay = false;
int autoDelay = 35;
int autoCounter = 0;

int viewMode = 1;

// phases
final int PHASE_INPUT           = 0;
final int PHASE_COUNT_BUILD     = 1;
final int PHASE_COUNT_DONE      = 2;
final int PHASE_UPSWEEP         = 3;
final int PHASE_DOWNSWEEP_INIT  = 4;
final int PHASE_DOWNSWEEP       = 5;
final int PHASE_PREFIX_DONE     = 6;
final int PHASE_PLACE           = 7;
final int PHASE_DONE            = 8;

int phase = PHASE_INPUT;

// state
int countBuildIndex = 0;
int upsweepStride = 2;
int downsweepStride = 0;
int placeIndex = 0;

float leftMargin = 24;
float topMargin = 20;

float cellW = 38;
float cellH = 34;
float gap = 6;

PFont fontMain;

// tree display arrays
float[] leafX, leafY;
float[] level1X, level1Y;
float[] level2X, level2Y;
float rootX, rootY;

void setup() {
  size(1200, 700);
  fontMain = createFont("Arial", 16);
  textFont(fontMain);
  initializeExample();
}

void initializeExample() {
  input = new int[N];
  counts = new int[K];
  output = new int[N];
  outputSourceIdx = new int[N];
  seenSoFar = new int[K];

  for (int i = 0; i < N; i++) {
    input[i] = int(random(K));
    output[i] = -1;
    outputSourceIdx[i] = -1;
  }

  PADDED_K = 1;
  while (PADDED_K < K) PADDED_K *= 2;

  scanArray = new int[PADDED_K];
  prefix = new int[K];

  phase = PHASE_INPUT;
  countBuildIndex = 0;
  upsweepStride = 2;
  downsweepStride = PADDED_K;
  placeIndex = 0;
  autoCounter = 0;

  for (int i = 0; i < K; i++) counts[i] = 0;
  for (int i = 0; i < PADDED_K; i++) scanArray[i] = 0;
  for (int i = 0; i < K; i++) prefix[i] = 0;
  for (int i = 0; i < K; i++) seenSoFar[i] = 0;

  buildTreeLayout();
}

void buildTreeLayout() {
  leafX = new float[PADDED_K];
  leafY = new float[PADDED_K];
  level1X = new float[PADDED_K / 2];
  level1Y = new float[PADDED_K / 2];
  level2X = new float[PADDED_K / 4];
  level2Y = new float[PADDED_K / 4];

  float x = 170;
  float y = 325;
  float dx = 68;

  for (int i = 0; i < PADDED_K; i++) {
    leafX[i] = x + i * dx;
    leafY[i] = y + 130;
  }

  for (int i = 0; i < PADDED_K / 2; i++) {
    level1X[i] = (leafX[2 * i] + leafX[2 * i + 1]) * 0.5;
    level1Y[i] = y + 85;
  }

  for (int i = 0; i < PADDED_K / 4; i++) {
    level2X[i] = (level1X[2 * i] + level1X[2 * i + 1]) * 0.5;
    level2Y[i] = y + 40;
  }

  rootX = (level2X[0] + level2X[1]) * 0.5;
  rootY = y - 5;
}

void draw() {
  background(248);

  if (autoPlay) {
    autoCounter++;
    if (autoCounter >= autoDelay) {
      autoCounter = 0;
      advanceStep();
    }
  }

  drawHeader();
  drawControlsBar();

  if (viewMode == 1) {
    drawVersion1();
  } else {
    drawVersion2();
  }

  drawExplanationPanel(820, 92, 355, 580);
}

void drawHeader() {
  fill(20);
  textAlign(LEFT, TOP);
  textSize(24);
  text("Counting Sort Using a Parallel Prefix Sum", leftMargin, topMargin);

  fill(70);
  textSize(14);
  text("Build histogram -> Blelloch scan -> exclusive prefixes -> stable placement",
       leftMargin, topMargin + 34);
}

void drawControlsBar() {
  float x = leftMargin;
  float y = 62;

  fill(242);
  stroke(200);
  rect(x, y, 760, 24, 8);

  fill(40);
  textSize(13);
  text("SPACE: next   A: autoplay   R: randomize   1: array view   2: tree view   Current view: " + viewMode,
       x + 10, y + 5);
}

void drawVersion1() {
  float x = 24;
  drawInputArray(x, 120);
  drawCounts(x, 220);
  drawScanArray(x, 320);
  drawPrefixArray(x, 430);
  drawOutputArray(x, 540);
}

void drawVersion2() {
  float x = 24;
  drawInputArray(x, 120);
  drawCounts(x, 220);

  fill(30);
  textSize(18);
  text("3. Parallel Scan Tree View", x, 305);

  drawScanTree();

  drawPrefixArray(x, 505);
  drawOutputArray(x, 595);
}

void drawInputArray(float x, float y) {
  fill(30);
  textSize(18);
  text("1. Input Array", x, y - 26);

  for (int i = 0; i < N; i++) {
    boolean active = false;
    if (phase == PHASE_COUNT_BUILD && i == countBuildIndex) active = true;
    if (phase == PHASE_PLACE && i == placeIndex) active = true;

    drawCell(x + i * (cellW + gap), y, cellW, cellH, str(input[i]), colorForValue(input[i]), active);

    fill(90);
    textSize(10);
    textAlign(CENTER, TOP);
    text(i, x + i * (cellW + gap) + cellW / 2, y + cellH + 2);
  }
  textAlign(LEFT, TOP);
}

void drawCounts(float x, float y) {
  fill(30);
  textSize(18);
  text("2. Histogram Counts", x, y - 26);

  for (int i = 0; i < K; i++) {
    boolean active = false;
    if (phase == PHASE_COUNT_BUILD && countBuildIndex < N && input[countBuildIndex] == i) active = true;

    drawCell(x + i * 58, y, 42, 34, str(counts[i]), colorForValue(i), active);

    fill(80);
    textSize(11);
    textAlign(CENTER, TOP);
    text("key " + i, x + i * 58 + 21, y + 38);
  }
  textAlign(LEFT, TOP);
}

void drawScanArray(float x, float y) {
  fill(30);
  textSize(18);
  text("3. Scan Array (padded histogram)", x, y - 26);

  for (int i = 0; i < PADDED_K; i++) {
    boolean active = isScanIndexActive(i);
    int c = (i < K) ? colorForValue(i) : color(235);
    drawCell(x + i * 58, y, 42, 34, str(scanArray[i]), c, active);

    fill(80);
    textSize(11);
    textAlign(CENTER, TOP);
    text(i, x + i * 58 + 21, y + 38);
  }

  fill(70);
  textSize(12);
  textAlign(LEFT, TOP);

  if (phase == PHASE_UPSWEEP) {
    text("Up-sweep stride = " + min(upsweepStride, PADDED_K), x, y + 62);
  } else if (phase == PHASE_DOWNSWEEP_INIT) {
    text("Set the last entry to 0 to start the exclusive scan.", x, y + 62);
  } else if (phase == PHASE_DOWNSWEEP) {
    text("Down-sweep stride = " + max(downsweepStride, 1), x, y + 62);
  } else if (phase >= PHASE_PREFIX_DONE) {
    text("The scan array now holds exclusive prefix sums.", x, y + 62);
  } else {
    text("Starts as histogram counts; the scan transforms them into positions.", x, y + 62);
  }
}

void drawPrefixArray(float x, float y) {
  fill(30);
  textSize(18);
  text("4. Exclusive Prefix Sums", x, y - 26);

  for (int i = 0; i < K; i++) {
    boolean active = false;
    if (phase == PHASE_PLACE && placeIndex < N && input[placeIndex] == i) active = true;

    String label = (phase >= PHASE_PREFIX_DONE) ? str(prefix[i]) : "-";
    drawCell(x + i * 58, y, 42, 34, label, colorForValue(i), active);

    fill(80);
    textSize(11);
    textAlign(CENTER, TOP);
    text("key " + i, x + i * 58 + 21, y + 38);
  }

  fill(70);
  textSize(12);
  textAlign(LEFT, TOP);
  if (phase >= PHASE_PREFIX_DONE) {
    text("prefix[v] = first output slot reserved for key v", x, y + 62);
  }
}

void drawOutputArray(float x, float y) {
  fill(30);
  textSize(18);
  text("5. Output Array", x, y - 26);

  for (int i = 0; i < N; i++) {
    boolean active = false;
    if (phase == PHASE_PLACE && placeIndex < N) {
      int v = input[placeIndex];
      int pos = prefix[v] + seenSoFar[v];
      if (i == pos) active = true;
    }

    int c = (output[i] == -1) ? color(245) : colorForValue(output[i]);
    String label = (output[i] == -1) ? "" : str(output[i]);

    drawCell(x + i * (cellW + gap), y, cellW, cellH, label, c, active);

    fill(90);
    textSize(10);
    textAlign(CENTER, TOP);
    text(i, x + i * (cellW + gap) + cellW / 2, y + cellH + 2);
  }

  textAlign(LEFT, TOP);
}

void drawScanTree() {
  drawTreeConnections();

  // leaves
  for (int i = 0; i < PADDED_K; i++) {
    boolean active = isScanIndexActive(i);
    int c = (i < K) ? colorForValue(i) : color(235);
    drawTreeNode(leafX[i], leafY[i], str(scanArray[i]), c, active, i);
  }

  // internal nodes values
  int[] lvl1 = new int[PADDED_K / 2];
  int[] lvl2 = new int[PADDED_K / 4];
  int rootVal = 0;

  computeTreeNodeValues(lvl1, lvl2);

  if (phase == PHASE_UPSWEEP || phase == PHASE_COUNT_DONE) {
    for (int i = 0; i < PADDED_K / 2; i++) {
      boolean active = isLevel1Active(i);
      String label = str(lvl1[i]);
      drawCircle(level1X[i], level1Y[i], label, color(250), active);
    }

    for (int i = 0; i < PADDED_K / 4; i++) {
      boolean active = isLevel2Active(i);
      String label = str(lvl2[i]);
      drawCircle(level2X[i], level2Y[i], label, color(250), active);
    }

    rootVal = lvl2[0] + lvl2[1];
    boolean rootActive = isRootActive();
    drawCircle(rootX, rootY, str(rootVal), color(250), rootActive);
  } else if (phase == PHASE_DOWNSWEEP_INIT || phase == PHASE_DOWNSWEEP || phase >= PHASE_PREFIX_DONE) {
    // Down-sweep / prefix interpretation:
    // show internal ranges as prefix values of the left edge of each subtree
    for (int i = 0; i < PADDED_K / 2; i++) {
      boolean active = isLevel1Active(i);
      int start = 2 * i;
      String label = str(scanArray[start]);
      drawCircle(level1X[i], level1Y[i], label, color(250), active);
    }

    for (int i = 0; i < PADDED_K / 4; i++) {
      boolean active = isLevel2Active(i);
      int start = 4 * i;
      String label = str(scanArray[start]);
      drawCircle(level2X[i], level2Y[i], label, color(250), active);
    }

    boolean rootActive = isRootActive();
    drawCircle(rootX, rootY, "0", color(250), rootActive);
  }

  fill(70);
  textSize(12);
  textAlign(LEFT, TOP);

  if (phase == PHASE_UPSWEEP) {
    text("Internal nodes show partial sums being built upward.", 150, 500);
  } else if (phase == PHASE_DOWNSWEEP_INIT) {
    text("Root is reset to 0 so the result becomes an exclusive prefix scan.", 150, 500);
  } else if (phase == PHASE_DOWNSWEEP) {
    text("Internal nodes now show prefix values being pushed back down.", 150, 500);
  } else if (phase >= PHASE_PREFIX_DONE) {
    text("Leaves now hold the exclusive prefix sums for the padded histogram.", 150, 500);
  } else {
    text("Tree view makes the scan's combine-and-distribute pattern easier to see.", 150, 500);
  }
}

void computeTreeNodeValues(int[] lvl1, int[] lvl2) {
  for (int i = 0; i < PADDED_K / 2; i++) {
    lvl1[i] = scanArray[2 * i] + scanArray[2 * i + 1];
  }
  for (int i = 0; i < PADDED_K / 4; i++) {
    lvl2[i] = lvl1[2 * i] + lvl1[2 * i + 1];
  }
}

void drawTreeConnections() {
  stroke(150);
  strokeWeight(2);

  for (int i = 0; i < PADDED_K / 2; i++) {
    line(level1X[i], level1Y[i], leafX[2 * i], leafY[2 * i]);
    line(level1X[i], level1Y[i], leafX[2 * i + 1], leafY[2 * i + 1]);
  }

  for (int i = 0; i < PADDED_K / 4; i++) {
    line(level2X[i], level2Y[i], level1X[2 * i], level1Y[2 * i]);
    line(level2X[i], level2Y[i], level1X[2 * i + 1], level1Y[2 * i + 1]);
  }

  line(rootX, rootY, level2X[0], level2Y[0]);
  line(rootX, rootY, level2X[1], level2Y[1]);
}

boolean isScanIndexActive(int idx) {
  if (phase == PHASE_UPSWEEP && upsweepStride <= PADDED_K) {
    int stride = upsweepStride;
    int half = stride / 2;
    for (int i = stride - 1; i < PADDED_K; i += stride) {
      if (idx == i || idx == i - half) return true;
    }
  } else if (phase == PHASE_DOWNSWEEP && downsweepStride >= 2) {
    int stride = downsweepStride;
    int half = stride / 2;
    for (int i = stride - 1; i < PADDED_K; i += stride) {
      if (idx == i || idx == i - half) return true;
    }
  } else if (phase == PHASE_DOWNSWEEP_INIT && idx == PADDED_K - 1) {
    return true;
  }
  return false;
}

boolean isLevel1Active(int node) {
  int left = 2 * node;
  int right = left + 1;
  return isScanIndexActive(left) || isScanIndexActive(right);
}

boolean isLevel2Active(int node) {
  int start = 4 * node;
  for (int i = start; i < start + 4; i++) {
    if (isScanIndexActive(i)) return true;
  }
  return false;
}

boolean isRootActive() {
  for (int i = 0; i < PADDED_K; i++) {
    if (isScanIndexActive(i)) return true;
  }
  return false;
}

void drawTreeNode(float cx, float cy, String label, int fillColor, boolean active, int idx) {
  drawCircle(cx, cy, label, fillColor, active);

  fill(70);
  textSize(10);
  textAlign(CENTER, TOP);
  text(idx, cx, cy + 20);
  textAlign(LEFT, TOP);
}

void drawCircle(float cx, float cy, String label, int fillColor, boolean active) {
  if (active) {
    strokeWeight(3);
    stroke(20);
  } else {
    strokeWeight(1.5);
    stroke(120);
  }

  fill(fillColor);
  ellipse(cx, cy, 34, 34);

  fill(20);
  textAlign(CENTER, CENTER);
  textSize(14);
  text(label, cx, cy - 1);

  textAlign(LEFT, TOP);
  strokeWeight(1);
}

void drawCell(float x, float y, float w, float h, String label, int fillColor, boolean active) {
  if (active) {
    strokeWeight(3);
    stroke(20);
  } else {
    strokeWeight(1.3);
    stroke(120);
  }

  fill(fillColor);
  rect(x, y, w, h, 7);

  fill(20);
  textAlign(CENTER, CENTER);
  textSize(16);
  text(label, x + w / 2, y + h / 2 - 1);

  textAlign(LEFT, TOP);
  strokeWeight(1);
}

int colorForValue(int v) {
  switch(v) {
  case 0: return color(255, 214, 214);
  case 1: return color(255, 232, 190);
  case 2: return color(255, 246, 168);
  case 3: return color(214, 244, 196);
  case 4: return color(190, 234, 255);
  case 5: return color(208, 214, 255);
  case 6: return color(233, 208, 255);
  case 7: return color(255, 206, 232);
  default: return color(230);
  }
}

void keyPressed() {
  if (key == ' ') {
    advanceStep();
  } else if (key == 'a' || key == 'A') {
    autoPlay = !autoPlay;
  } else if (key == 'r' || key == 'R') {
    initializeExample();
  } else if (key == '1') {
    viewMode = 1;
  } else if (key == '2') {
    viewMode = 2;
  }
}

void advanceStep() {
  switch (phase) {
  case PHASE_INPUT:
    phase = PHASE_COUNT_BUILD;
    break;

  case PHASE_COUNT_BUILD:
    if (countBuildIndex < N) {
      int v = input[countBuildIndex];
      counts[v]++;
      countBuildIndex++;
    }
    if (countBuildIndex >= N) {
      for (int i = 0; i < PADDED_K; i++) {
        scanArray[i] = (i < K) ? counts[i] : 0;
      }
      phase = PHASE_COUNT_DONE;
    }
    break;

  case PHASE_COUNT_DONE:
    phase = PHASE_UPSWEEP;
    upsweepStride = 2;
    break;

  case PHASE_UPSWEEP:
    performUpsweepStep();
    if (upsweepStride > PADDED_K) {
      phase = PHASE_DOWNSWEEP_INIT;
    }
    break;

  case PHASE_DOWNSWEEP_INIT:
    scanArray[PADDED_K - 1] = 0;
    downsweepStride = PADDED_K;
    phase = PHASE_DOWNSWEEP;
    break;

  case PHASE_DOWNSWEEP:
    performDownsweepStep();
    if (downsweepStride < 2) {
      for (int i = 0; i < K; i++) {
        prefix[i] = scanArray[i];
      }
      phase = PHASE_PREFIX_DONE;
    }
    break;

  case PHASE_PREFIX_DONE:
    phase = PHASE_PLACE;
    break;

  case PHASE_PLACE:
    if (placeIndex < N) {
      int v = input[placeIndex];
      int pos = prefix[v] + seenSoFar[v];
      output[pos] = v;
      outputSourceIdx[pos] = placeIndex;
      seenSoFar[v]++;
      placeIndex++;
    }
    if (placeIndex >= N) {
      phase = PHASE_DONE;
    }
    break;

  case PHASE_DONE:
    break;
  }
}

void performUpsweepStep() {
  int half = upsweepStride / 2;
  for (int i = upsweepStride - 1; i < PADDED_K; i += upsweepStride) {
    scanArray[i] += scanArray[i - half];
  }
  upsweepStride *= 2;
}

void performDownsweepStep() {
  int half = downsweepStride / 2;
  for (int i = downsweepStride - 1; i < PADDED_K; i += downsweepStride) {
    int t = scanArray[i - half];
    scanArray[i - half] = scanArray[i];
    scanArray[i] += t;
  }
  downsweepStride /= 2;
}

void drawExplanationPanel(float x, float y, float w, float h) {
  fill(252);
  stroke(195);
  rect(x, y, w, h, 12);

  fill(25);
  textSize(20);
  text("What is happening?", x + 14, y + 12);

  fill(55);
  textSize(14);

  String[] lines = getPhaseExplanation();
  float yy = y + 48;
  for (int i = 0; i < lines.length; i++) {
    text(lines[i], x + 14, yy, w - 28, 200);
    yy += 42;
  }

  yy += 8;
  fill(25);
  textSize(17);
  text("Current phase", x + 14, yy);
  yy += 28;

  fill(60);
  textSize(14);
  text(phaseName(), x + 14, yy);

  yy += 34;
  if (phase == PHASE_COUNT_BUILD) {
    text("Processed inputs: " + countBuildIndex + " / " + N, x + 14, yy);
    yy += 24;
  }
  if (phase == PHASE_UPSWEEP) {
    text("Current up-sweep stride: " + min(upsweepStride, PADDED_K), x + 14, yy);
    yy += 24;
  }
  if (phase == PHASE_DOWNSWEEP) {
    text("Current down-sweep stride: " + max(downsweepStride, 1), x + 14, yy);
    yy += 24;
  }
  if (phase == PHASE_PLACE) {
    text("Placed outputs: " + placeIndex + " / " + N, x + 14, yy);
    yy += 24;
  }

  yy += 10;
  fill(25);
  textSize(17);
  text("Why prefix sums matter", x + 14, yy);
  yy += 28;

  fill(60);
  textSize(14);
  text("The exclusive prefix sum turns each count bin into a starting position. "
     + "That is what lets counting sort place elements directly into the output.",
       x + 14, yy, w - 28, 150);
}

String phaseName() {
  switch (phase) {
  case PHASE_INPUT: return "Input ready";
  case PHASE_COUNT_BUILD: return "Building the histogram";
  case PHASE_COUNT_DONE: return "Histogram complete";
  case PHASE_UPSWEEP: return "Blelloch scan: up-sweep";
  case PHASE_DOWNSWEEP_INIT: return "Exclusive scan initialization";
  case PHASE_DOWNSWEEP: return "Blelloch scan: down-sweep";
  case PHASE_PREFIX_DONE: return "Prefix sums ready";
  case PHASE_PLACE: return "Stable placement into output";
  case PHASE_DONE: return "Sorting complete";
  }
  return "";
}

String[] getPhaseExplanation() {
  if (phase == PHASE_INPUT) {
    return new String[] {
      "We begin with an unsorted array of small integer keys.",
      "Counting sort works well when the key range is small.",
      "The next stage builds a histogram of occurrences."
    };
  } else if (phase == PHASE_COUNT_BUILD) {
    return new String[] {
      "Each input value increments one histogram bin.",
      "The animation does this one item at a time so the update is easy to see.",
      "In parallel systems, many items can contribute simultaneously."
    };
  } else if (phase == PHASE_COUNT_DONE) {
    return new String[] {
      "The histogram is complete.",
      "Now we run an exclusive prefix sum over the histogram.",
      "That converts counts into starting output positions."
    };
  } else if (phase == PHASE_UPSWEEP) {
    return new String[] {
      "Up-sweep combines neighboring ranges into larger partial sums.",
      "This is the reduction half of the Blelloch scan.",
      "The tree view shows those internal partial sums directly."
    };
  } else if (phase == PHASE_DOWNSWEEP_INIT) {
    return new String[] {
      "The root total is replaced by 0.",
      "That change turns the reduction tree into an exclusive scan tree.",
      "Now prefix values can be propagated downward."
    };
  } else if (phase == PHASE_DOWNSWEEP) {
    return new String[] {
      "Down-sweep redistributes prefix information through the tree.",
      "After this finishes, each leaf contains the sum of all earlier leaves.",
      "Those leaf values are the exclusive prefixes."
    };
  } else if (phase == PHASE_PREFIX_DONE) {
    return new String[] {
      "The exclusive prefixes are ready.",
      "For any key v, prefix[v] tells where v's block begins in the output.",
      "The final stage performs stable placement."
    };
  } else if (phase == PHASE_PLACE) {
    return new String[] {
      "Each element uses prefix[value] plus an offset among equal keys.",
      "That places items directly into their final output slots.",
      "Equal keys stay in encounter order, so the sort is stable."
    };
  } else {
    return new String[] {
      "The output is now sorted.",
      "Because equal keys were placed in original order, the result is stable.",
      "Press R to generate another example and step through it again."
    };
  }
}
