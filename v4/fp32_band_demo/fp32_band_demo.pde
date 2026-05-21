// FP32 Little-Endian Binary Data Viewer
// Controls:
//   Left/Right arrows : move by one visible window
//   Shift + Left/Right : move by 10 visible windows
//   + / = : zoom out to more points
//   - / _ : zoom in to fewer points
//   [ / ] : change band denominator from 3..10
//   Home/End : jump to start/end

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.io.File;
import java.awt.event.KeyEvent;

float[] data;
float dataMin = Float.POSITIVE_INFINITY;
float dataMax = Float.NEGATIVE_INFINITY;

String fileName = "No file loaded";

int startIndex = 0;
int zoomIndex = 2;
int[] zoomLevels;

int bandDenom = 3;

int leftMargin = 85;
int rightMargin = 30;
int topMargin = 60;
int bottomMargin = 75;

void setup() {
  size(1200, 700);
  surface.setTitle("FP32 Little-Endian Viewer");
  selectInput("Select raw little-endian FP32 binary file:", "fileSelected");
  noLoop();
}

void fileSelected(File selection) {
  if (selection == null) {
    println("No file selected.");
    return;
  }

  fileName = selection.getName();
  byte[] bytes = loadBytes(selection.getAbsolutePath());

  int n = bytes.length / 4;
  data = new float[n];

  ByteBuffer bb = ByteBuffer.wrap(bytes);
  bb.order(ByteOrder.LITTLE_ENDIAN);

  dataMin = Float.POSITIVE_INFINITY;
  dataMax = Float.NEGATIVE_INFINITY;

  for (int i = 0; i < n; i++) {
    float v = bb.getFloat();
    data[i] = v;

    if (!Float.isNaN(v) && !Float.isInfinite(v)) {
      if (v < dataMin) dataMin = v;
      if (v > dataMax) dataMax = v;
    }
  }

  buildZoomLevels(n);

  startIndex = 0;
  surface.setTitle(fileName + " — FP32 Little-Endian Viewer");
  redraw();
}

void buildZoomLevels(int n) {
  ArrayList<Integer> levels = new ArrayList<Integer>();

  int p = 10;
  while (p < n) {
    levels.add(p);
    p *= 10;
  }

  if (levels.size() == 0 || levels.get(levels.size() - 1) != n) {
    levels.add(n);
  }

  zoomLevels = new int[levels.size()];

  for (int i = 0; i < levels.size(); i++) {
    zoomLevels[i] = levels.get(i);
  }

  zoomIndex = min(2, zoomLevels.length - 1); // default near 1000 points
}

void draw() {
  background(255);

  if (data == null) {
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Select a raw FP32 little-endian binary file", width / 2, height / 2);
    return;
  }

  int visibleCount = zoomLevels[zoomIndex];
  visibleCount = min(visibleCount, data.length);

  startIndex = constrain(startIndex, 0, max(0, data.length - visibleCount));

  int endIndex = min(startIndex + visibleCount, data.length);

  drawTitle(visibleCount, endIndex);
  drawBands();
  drawAxes(startIndex, endIndex);
  plotData(startIndex, endIndex);
  drawInfo(visibleCount, endIndex);
}

void drawTitle(int visibleCount, int endIndex) {
  fill(0);
  textAlign(CENTER, TOP);
  textSize(18);
  text(fileName, width / 2, 12);

  textSize(12);
  text(
    "Showing index " + startIndex + " to " + (endIndex - 1) +
    "  |  points: " + visibleCount +
    "  |  bands: lower/middle/upper using 1/" + bandDenom,
    width / 2,
    35
  );
}

void drawAxes(int start, int end) {
  int plotLeft = leftMargin;
  int plotRight = width - rightMargin;
  int plotTop = topMargin;
  int plotBottom = height - bottomMargin;

  stroke(0);
  strokeWeight(1);

  line(plotLeft, plotBottom, plotRight, plotBottom);
  line(plotLeft, plotBottom, plotLeft, plotTop);

  fill(0);
  textSize(12);

  textAlign(CENTER, TOP);
  text("datapoint index", (plotLeft + plotRight) / 2, height - 45);

  pushMatrix();
  translate(25, (plotTop + plotBottom) / 2);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("value", 0, 0);
  popMatrix();

  textAlign(RIGHT, CENTER);
  text(nf(dataMax, 1, 5), plotLeft - 10, plotTop);
  text(nf((dataMin + dataMax) / 2.0, 1, 5), plotLeft - 10, (plotTop + plotBottom) / 2);
  text(nf(dataMin, 1, 5), plotLeft - 10, plotBottom);

  textAlign(CENTER, TOP);
  text(start, plotLeft, plotBottom + 8);
  text(end - 1, plotRight, plotBottom + 8);
  text((start + end - 1) / 2, (plotLeft + plotRight) / 2, plotBottom + 8);
}

void drawBands() {
  int plotLeft = leftMargin;
  int plotRight = width - rightMargin;
  int plotTop = topMargin;
  int plotBottom = height - bottomMargin;

  float lowCut = dataMin + (dataMax - dataMin) / bandDenom;
  float highCut = dataMax - (dataMax - dataMin) / bandDenom;

  float yLow = map(lowCut, dataMin, dataMax, plotBottom, plotTop);
  float yHigh = map(highCut, dataMin, dataMax, plotBottom, plotTop);

  noStroke();

  fill(210, 230, 255, 50);
  rect(plotLeft, yLow, plotRight - plotLeft, plotBottom - yLow);

  fill(230, 230, 230, 45);
  rect(plotLeft, yHigh, plotRight - plotLeft, yLow - yHigh);

  fill(255, 220, 210, 50);
  rect(plotLeft, plotTop, plotRight - plotLeft, yHigh - plotTop);

  stroke(180);
  strokeWeight(1);
  line(plotLeft, yLow, plotRight, yLow);
  line(plotLeft, yHigh, plotRight, yHigh);
}

void plotData(int start, int end) {
  int plotLeft = leftMargin;
  int plotRight = width - rightMargin;
  int plotTop = topMargin;
  int plotBottom = height - bottomMargin;

  int count = end - start;
  if (count <= 0) return;

  float lowCut = dataMin + (dataMax - dataMin) / bandDenom;
  float highCut = dataMax - (dataMax - dataMin) / bandDenom;

  int stride = max(1, count / ((plotRight - plotLeft) * 4));

  strokeWeight(3);

  for (int i = start; i < end; i += stride) {
    float v = data[i];

    if (Float.isNaN(v) || Float.isInfinite(v)) continue;

    float x = map(i, start, end - 1, plotLeft, plotRight);
    float y = map(v, dataMin, dataMax, plotBottom, plotTop);

    if (v < lowCut) {
      stroke(0, 90, 220);
    } else if (v > highCut) {
      stroke(220, 50, 0);
    } else {
      stroke(40, 160, 70);
    }

    point(x, y);
  }
}

void drawInfo(int visibleCount, int endIndex) {
  fill(0);
  textSize(12);
  textAlign(LEFT, TOP);

  String info =
    "Total points: " + data.length +
    "\nMin: " + dataMin +
    "\nMax: " + dataMax +
    "\nVisible points: " + visibleCount +
    "\nZoom level: " + (zoomIndex + 1) + " / " + zoomLevels.length +
    "\nRange: [" + startIndex + ", " + (endIndex - 1) + "]" +
    "\nControls: ←/→ move, +/- zoom, [/ ] change 1/" + bandDenom;

  text(info, leftMargin, height - 65);
}

void keyPressed() {
  if (data == null) return;

  int visibleCount = zoomLevels[zoomIndex];
  int jump = visibleCount;

  if (keyEvent.isShiftDown()) {
    jump *= 10;
  }

  if (keyCode == RIGHT) {
    startIndex += jump;
  } else if (keyCode == LEFT) {
    startIndex -= jump;
  } else if (keyCode == KeyEvent.VK_HOME) {
    startIndex = 0;
  } else if (keyCode == KeyEvent.VK_END) {
    startIndex = max(0, data.length - visibleCount);
  } else if (key == '+' || key == '=') {
    zoomIndex = min(zoomIndex + 1, zoomLevels.length - 1);
  } else if (key == '-' || key == '_') {
    zoomIndex = max(zoomIndex - 1, 0);
  } else if (key == ']') {
    bandDenom = min(10, bandDenom + 1);
  } else if (key == '[') {
    bandDenom = max(3, bandDenom - 1);
  }

  visibleCount = zoomLevels[zoomIndex];
  startIndex = constrain(startIndex, 0, max(0, data.length - visibleCount));

  redraw();
}
