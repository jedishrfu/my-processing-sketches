// Unsorting Algorithms Visualizer (Deluxe Edition)
// Features:
//   - Slider to control unsorting speed (steps per frame)
//   - Bars colored by how "out of place" they are
//   - Start from fully sorted or partially shuffled data
//   - Ghost overlay of ideal sorted positions (toggle 'g')
//   - Inversion count + normalized unsortedness metric
//   - Scatterplot panel of index vs value
//
// Keys:
//   r - reset to fully sorted
//   p - reset to partially shuffled
//   1 - mode 1: random shuffle (Fisher–Yates pass)
//   2 - mode 2: gradual reverse
//   3 - mode 3: anti-bubble (asc -> desc)
//   g - toggle ghost overlay of ideal sorted bars
//   SPACE - pause / resume

int[] data;
int n = 100;

int mode = 1;        // 1=random shuffle, 2=reverse, 3=anti-bubble
boolean running = true;

// State for each mode
int stepIndex = 0;   // used by random + reverse
int bubbleIndex = 0; // used by anti-bubble
boolean didSwapInPass = true;

// Slider state (controls stepsPerFrame)
float sliderX, sliderY, sliderW, sliderH;
float sliderVal = 0.2;    // 0..1
int minSteps = 1;
int maxSteps = 20;
boolean draggingSlider = false;

// Colors for displacement gradient
color cInPlace;
color cFar;

// Ghost overlay toggle
boolean showGhost = true;

void setup() {
  size(900, 500);
  textFont(createFont("Consolas", 14));
  resetArraySorted();
  
  // Slider geometry
  sliderW = width * 0.6;
  sliderH = 20;
  sliderX = (width - sliderW) / 2;
  sliderY = height - 40;
  
  cInPlace = color(0, 255, 0);   // green
  cFar     = color(255, 0, 0);   // red
}

void draw() {
  background(0);
  
  drawArray();
  drawHUD();
  drawSlider();
  drawScatterplot();
  
  if (running) {
    stepUnsortMultistep();
  }
}

// -------------------------------------------------------
// Initialization helpers
// -------------------------------------------------------
void resetArraySorted() {
  data = new int[n];
  for (int i = 0; i < n; i++) {
    data[i] = i + 1;
  }
  resetModeState();
  running = true;
}

void resetArrayPartiallyShuffled() {
  // Start sorted, then do some random swaps
  data = new int[n];
  for (int i = 0; i < n; i++) {
    data[i] = i + 1;
  }
  int swaps = int(n * 0.3); // 30% of n random swaps
  for (int k = 0; k < swaps; k++) {
    int i = int(random(n));
    int j = int(random(n));
    swap(i, j);
  }
  resetModeState();
  running = true;
}

void resetModeState() {
  stepIndex = 0;
  bubbleIndex = 0;
  didSwapInPass = true;
}

// -------------------------------------------------------
// Drawing the array as vertical bars
//   - optional ghost overlay for ideal sorted state
//   - bars colored by displacement from sorted index
// -------------------------------------------------------
void drawArray() {
  float w = width / (float)n;
  
  // Ghost overlay: ideal sorted positions (value v at index v-1)
  if (showGhost) {
    noStroke();
    for (int v = 1; v <= n; v++) {
      int idx = v - 1;
      float gx = idx * w;
      float gh = map(v, 1, n, 10, height - 100);
      float gy = height - 100 - gh;
      fill(80, 80, 80, 80); // faint gray with some alpha
      rect(gx, gy, w, gh);
    }
  }
  
  // Max possible displacement for normalization
  float maxDisp = max(1, n - 1);
  noStroke();
  
  for (int i = 0; i < n; i++) {
    float x = i * w;
    float h = map(data[i], 1, n, 10, height - 100);
    float y = height - 100 - h;
    
    int expectedIndex = data[i] - 1; // where it would be if sorted ascending
    float disp = abs(i - expectedIndex);
    float t = disp / maxDisp;        // 0..1
    
    color c = lerpColor(cInPlace, cFar, t);
    fill(c);
    rect(x, y, w, h);
  }
}

// -------------------------------------------------------
// HUD: mode, status, metrics, help
// -------------------------------------------------------
void drawHUD() {
  fill(255);
  textAlign(LEFT, TOP);
  
  String modeName = "";
  if (mode == 1) modeName = "Random shuffle (Fisher–Yates pass)";
  else if (mode == 2) modeName = "Reverse (outer swaps inward)";
  else if (mode == 3) modeName = "Anti-bubble (ascending → descending)";
  
  String status = running ? "RUNNING" : "PAUSED / DONE";
  
  int stepsPerFrame = getStepsPerFrame();
  float avgDisp = averageDisplacement();
  
  // Inversion metrics
  long invCount = countInversions();
  long maxInv = (long)n * (n - 1) / 2;
  float invNorm = (maxInv > 0) ? (float)invCount / (float)maxInv : 0;
  
  text("Unsorting demo (deluxe)", 10, 10);
  text("Mode: " + modeName, 10, 30);
  text("Status: " + status, 10, 50);
  text("Keys: r=sorted, p=partial, 1/2/3=mode, g=ghost, SPACE=pause/resume", 10, 70);
  text("Speed (steps per frame): " + stepsPerFrame, 10, 90);
  text("Average displacement: " + nf(avgDisp, 1, 2), 10, 110);
  text("Inversions: " + invCount + " / " + maxInv +
       "  (normalized: " + nf(invNorm, 1, 3) + ")", 10, 130);
  text("Ghost overlay: " + (showGhost ? "ON (g to toggle)" : "OFF (g to toggle)"), 10, 150);
}

// -------------------------------------------------------
// Slider drawing & interaction
// -------------------------------------------------------
void drawSlider() {
  // Track
  stroke(200);
  fill(50);
  rect(sliderX, sliderY, sliderW, sliderH, 10);
  
  // Thumb position based on sliderVal (0..1)
  float thumbX = sliderX + sliderVal * sliderW;
  float thumbW = 12;
  float thumbH = sliderH + 10;
  
  noStroke();
  fill(200);
  rectMode(CENTER);
  rect(thumbX, sliderY + sliderH / 2, thumbW, thumbH, 6);
  rectMode(CORNER);
  
  fill(255);
  textAlign(CENTER, BOTTOM);
  text("Speed", sliderX + sliderW / 2, sliderY - 4);
}

int getStepsPerFrame() {
  return int(map(sliderVal, 0, 1, minSteps, maxSteps));
}

void updateSliderFromMouse() {
  sliderVal = constrain((mouseX - sliderX) / sliderW, 0, 1);
}

// -------------------------------------------------------
// Scatterplot panel: index vs value
//   - bottom-left of panel = (minIndex, minValue)
//   - top-right = (maxIndex, maxValue)
// -------------------------------------------------------
void drawScatterplot() {
  // Panel geometry
  float sw = 260;
  float sh = 200;
  float sx = width - sw - 10;
  float sy = 10;
  
  // Background + border
  stroke(200);
  fill(20);
  rect(sx, sy, sw, sh);
  
  // Axes (simple box axes)
  stroke(120);
  // X-axis
  line(sx + 30, sy + sh - 30, sx + sw - 10, sy + sh - 30);
  // Y-axis
  line(sx + 30, sy + 10, sx + 30, sy + sh - 30);
  
  // Labels
  fill(255);
  textAlign(CENTER, TOP);
  text("Scatterplot: index vs value", sx + sw / 2, sy + sh - 20);
  textAlign(CENTER, BOTTOM);
  text("index", sx + sw / 2, sy + sh - 32);
  pushMatrix();
  translate(sx + 12, sy + sh / 2);
  rotate(-HALF_PI);
  text("value", 0, 0);
  popMatrix();
  
  // Plot points
  float plotX0 = sx + 30;
  float plotY0 = sy + sh - 30;
  float plotX1 = sx + sw - 10;
  float plotY1 = sy + 10;
  
  noStroke();
  fill(100, 200, 255);
  
  for (int i = 0; i < n; i++) {
    float px = map(i, 0, n - 1, plotX0, plotX1);
    float py = map(data[i], 1, n, plotY0, plotY1); // inverted since screen y grows downward
    ellipse(px, py, 4, 4);
  }
}

// -------------------------------------------------------
// Stepping the unsorting algorithm
// -------------------------------------------------------
void stepUnsortMultistep() {
  int steps = getStepsPerFrame();
  for (int s = 0; s < steps; s++) {
    if (!running) break;
    stepUnsortSingle();
  }
}

void stepUnsortSingle() {
  switch (mode) {
  case 1:
    stepRandomShuffle();
    break;
  case 2:
    stepReverse();
    break;
  case 3:
    stepAntiBubble();
    break;
  }
}

// Mode 1: Random shuffle (Fisher–Yates), one swap per frame
void stepRandomShuffle() {
  if (stepIndex >= n) {
    running = false;
    return;
  }
  int j = stepIndex + (int)random(n - stepIndex);
  swap(stepIndex, j);
  stepIndex++;
}

// Mode 2: Reverse gradually, swapping outer pairs inward
void stepReverse() {
  if (stepIndex >= n / 2) {
    running = false;
    return;
  }
  int j = n - 1 - stepIndex;
  swap(stepIndex, j);
  stepIndex++;
}

// Mode 3: "Anti-bubble" – turn ascending into descending, one local swap at a time
void stepAntiBubble() {
  if (bubbleIndex >= n - 1) {
    if (!didSwapInPass) {
      running = false;
      return;
    }
    bubbleIndex = 0;
    didSwapInPass = false;
  }
  
  if (data[bubbleIndex] < data[bubbleIndex + 1]) {
    swap(bubbleIndex, bubbleIndex + 1);
    didSwapInPass = true;
  }
  bubbleIndex++;
}

// -------------------------------------------------------
// Metrics & helpers
// -------------------------------------------------------
float averageDisplacement() {
  float sum = 0;
  for (int i = 0; i < n; i++) {
    int expectedIndex = data[i] - 1;
    sum += abs(i - expectedIndex);
  }
  return sum / n;
}

long countInversions() {
  long inv = 0;
  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      if (data[i] > data[j]) inv++;
    }
  }
  return inv;
}

void swap(int i, int j) {
  int tmp = data[i];
  data[i] = data[j];
  data[j] = tmp;
}

// -------------------------------------------------------
// Input handling
// -------------------------------------------------------
void keyPressed() {
  if (key == 'r' || key == 'R') {
    resetArraySorted();
  } else if (key == 'p' || key == 'P') {
    resetArrayPartiallyShuffled();
  } else if (key == '1') {
    mode = 1;
    resetModeState();
    running = true;
  } else if (key == '2') {
    mode = 2;
    resetModeState();
    running = true;
  } else if (key == '3') {
    mode = 3;
    resetModeState();
    running = true;
  } else if (key == 'g' || key == 'G') {
    showGhost = !showGhost;
  } else if (key == ' ') {
    running = !running;
  }
}

void mousePressed() {
  // Check if click is inside slider track
  if (mouseX >= sliderX && mouseX <= sliderX + sliderW &&
      mouseY >= sliderY && mouseY <= sliderY + sliderH) {
    draggingSlider = true;
    updateSliderFromMouse();
  }
}

void mouseDragged() {
  if (draggingSlider) {
    updateSliderFromMouse();
  }
}

void mouseReleased() {
  draggingSlider = false;
}
