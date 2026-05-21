/**
 * CSV Plotter with:
 *  - Top full-width control panel
 *  - X and Y column selection
 *  - Multiple Y columns (colored lines + legend)
 *  - Filter column with min/max
 *  - On-screen checkboxes for X log / Y log
 *  - Axis labels with column names (Y label rotated)
 *
 * No external libraries required.
 */

import java.io.File;

Table table;
float[][] values;
String[] colNames;
int colCount, rowCount;
boolean dataLoaded = false;

// GUI components
Button btnLoadCSV;
ColumnSelector xSelector;
MultiColumnSelector ySelector;
ColumnSelector filterSelector;
TextBox minBox, maxBox;
Button btnApplyFilter;
Checkbox xLogBox, yLogBox;

// Filter & log state
float filterMin = -Float.MAX_VALUE;
float filterMax =  Float.MAX_VALUE;
int filterCol = -1;
boolean xLog = false;
boolean yLog = false;

// Colors
color[] rainbow;

// Layout
float controlTop = 0;
float controlHeight = 220;  // top panel height
float plotMarginLeft = 80;
float plotMarginRight = 40;
float plotMarginBottom = 60;
float plotMarginTopExtra = 10;

void setup() {
  size(1200, 800);
  surface.setTitle("CSV Plotter (Log options, axis labels)");

  float colBoxY = 80;
  float colBoxH = 110;
  float colW = (width - 40) / 3.0;

  btnLoadCSV = new Button(20, 15, 120, 25, "Load CSV");

  xLogBox = new Checkbox(170, 15, "X log");
  yLogBox = new Checkbox(250, 15, "Y log");

  xSelector      = new ColumnSelector(20,        colBoxY, colW - 10, colBoxH, "X Column");
  ySelector      = new MultiColumnSelector(20+colW,  colBoxY, colW - 10, colBoxH, "Y Columns");
  filterSelector = new ColumnSelector(20+2*colW, colBoxY, colW - 10, colBoxH, "Filter Column");

  float textY = colBoxY + colBoxH + 40;
  minBox = new TextBox(20,  textY, 90, 28, "min");
  maxBox = new TextBox(120, textY, 90, 28, "max");
  btnApplyFilter = new Button(220, textY, 120, 25, "Apply Filter");

  textFont(createFont("Sans", 12));
}

void draw() {
  background(245);

  // Control panel background
  noStroke();
  fill(230);
  rect(0, controlTop, width, controlHeight);

  // GUI
  btnLoadCSV.draw();
  xLogBox.draw();
  yLogBox.draw();
  xSelector.draw();
  ySelector.draw();
  filterSelector.draw();
  minBox.draw();
  maxBox.draw();
  btnApplyFilter.draw();

  stroke(0);
  line(0, controlHeight, width, controlHeight); // separator line

  if (!dataLoaded) {
    fill(80);
    textSize(16);
    textAlign(LEFT, TOP);
    text("Load a CSV file (with header row, numeric columns) to begin.", 20, controlHeight + 20);
    return;
  }

  drawPlot();
}

// ---------- Mouse & keyboard ----------

void mousePressed() {
  if (btnLoadCSV.isClicked()) {
    selectInput("Select CSV file:", "fileSelected");
    return;
  }

  if (xLogBox.handleClick()) {
    xLog = xLogBox.checked;
    return;
  }

  if (yLogBox.handleClick()) {
    yLog = yLogBox.checked;
    return;
  }

  if (xSelector.handleClick()) return;
  if (ySelector.handleClick()) return;
  if (filterSelector.handleClick()) return;
  if (minBox.handleClick()) return;
  if (maxBox.handleClick()) return;

  if (btnApplyFilter.isClicked()) {
    applyFilter();
    return;
  }
}

void keyTyped() {
  if (minBox.active) minBox.handleKey(key);
  if (maxBox.active) maxBox.handleKey(key);
}

// ---------- CSV loading ----------

public void fileSelected(File f) {
  if (f == null) return;

  table = loadTable(f.getAbsolutePath(), "header");
  if (table == null) {
    println("Failed to load table.");
    return;
  }

  rowCount = table.getRowCount();
  colCount = table.getColumnCount();
  colNames = table.getColumnTitles();

  values = new float[rowCount][colCount];

  for (int r = 0; r < rowCount; r++) {
    for (int c = 0; c < colCount; c++) {
      String s = table.getString(r, c);
      float v = Float.NaN;
      if (s != null) {
        s = s.trim();
        if (s.length() > 0) {
          try { v = Float.parseFloat(s); }
          catch (Exception e) { }
        }
      }
      values[r][c] = v;
    }
  }

  buildRainbow();
  xSelector.setColumns(colNames);
  ySelector.setColumns(colNames);
  filterSelector.setColumns(colNames);

  dataLoaded = true;
  filterCol = -1;
  filterMin = -Float.MAX_VALUE;
  filterMax =  Float.MAX_VALUE;
}

// ---------- Filter ----------

void applyFilter() {
  filterCol = filterSelector.selected;

  try {
    filterMin = Float.parseFloat(minBox.text);
  } catch (Exception e) {
    filterMin = -Float.MAX_VALUE;
  }

  try {
    filterMax = Float.parseFloat(maxBox.text);
  } catch (Exception e) {
    filterMax = Float.MAX_VALUE;
  }
}

boolean passFilter(int r) {
  if (filterCol < 0) return true;
  float v = values[r][filterCol];
  if (Float.isNaN(v)) return false;
  return (v >= filterMin && v <= filterMax);
}

// ---------- Math helpers ----------

float log10f(float v) {
  return log(v) / log(10);
}

// ---------- Plotting ----------

void drawPlot() {
  float left   = plotMarginLeft;
  float right  = width - plotMarginRight;
  float top    = controlHeight + plotMarginTopExtra;
  float bottom = height - plotMarginBottom;

  int xCol = xSelector.selected;
  int[] yCols = ySelector.getSelected();

  if (xCol < 0 || yCols.length == 0) {
    fill(80);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Select one X column and at least one Y column.", left, top);
    return;
  }

  boolean anyValid = false;
  float xMin = Float.POSITIVE_INFINITY;
  float xMax = Float.NEGATIVE_INFINITY;
  float yMin = Float.POSITIVE_INFINITY;
  float yMax = Float.NEGATIVE_INFINITY;

  // Ranges with log options
  for (int r = 0; r < rowCount; r++) {
    if (!passFilter(r)) continue;
    float xv = values[r][xCol];
    if (Float.isNaN(xv)) continue;
    if (xLog && xv <= 0) continue;
    float tx = xLog ? log10f(xv) : xv;

    for (int c : yCols) {
      float yv = values[r][c];
      if (Float.isNaN(yv)) continue;
      if (yLog && yv <= 0) continue;
      float ty = yLog ? log10f(yv) : yv;

      if (tx < xMin) xMin = tx;
      if (tx > xMax) xMax = tx;
      if (ty < yMin) yMin = ty;
      if (ty > yMax) yMax = ty;
      anyValid = true;
    }
  }

  if (!anyValid) {
    fill(80);
    textSize(14);
    textAlign(LEFT, TOP);
    text("No valid data for current filter/log settings.", left, top);
    return;
  }

  if (xMin == xMax) { xMin -= 0.5; xMax += 0.5; }
  if (yMin == yMax) { yMin -= 0.5; yMax += 0.5; }

  // Plot frame
  stroke(0);
  noFill();
  rect(left, top, right-left, bottom-top);

  // Axis labels
  fill(0);
  textSize(12);
  textAlign(CENTER, TOP);
  String xLabel = "X: " + colNames[xCol] + (xLog ? " (log10)" : "");
  text(xLabel, (left + right)/2, bottom + 25);

  StringBuilder yLabel = new StringBuilder("Y: ");
  for (int i = 0; i < yCols.length; i++) {
    if (i > 0) yLabel.append(", ");
    yLabel.append(colNames[yCols[i]]);
  }
  if (yLog) yLabel.append(" (log10)");

  pushMatrix();
  translate(left - 45, (top + bottom)/2);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text(yLabel.toString(), 0, 0);
  popMatrix();

  // Simple ticks (already in transformed space)
  textAlign(CENTER, TOP);
  text(nf(xMin, 1, 4), left, bottom + 8);
  text(nf((xMin + xMax)*0.5, 1, 4), (left+right)/2, bottom + 8);
  text(nf(xMax, 1, 4), right, bottom + 8);

  textAlign(RIGHT, CENTER);
  text(nf(yMax, 1, 4), left - 5, top);
  text(nf((yMin + yMax)*0.5, 1, 4), left - 5, (top+bottom)/2);
  text(nf(yMin, 1, 4), left - 5, bottom);

  // Draw Y series
  strokeWeight(1.7);
  for (int cIndex = 0; cIndex < yCols.length; cIndex++) {
    int col = yCols[cIndex];
    stroke(rainbow[col]);

    boolean hasPrev = false;
    float px = 0, py = 0;

    for (int r = 0; r < rowCount; r++) {
      if (!passFilter(r)) {
        hasPrev = false;
        continue;
      }

      float xv = values[r][xCol];
      float yv = values[r][col];
      if (Float.isNaN(xv) || Float.isNaN(yv)) {
        hasPrev = false;
        continue;
      }
      if (xLog && xv <= 0) { hasPrev = false; continue; }
      if (yLog && yv <= 0) { hasPrev = false; continue; }

      float tx = xLog ? log10f(xv) : xv;
      float ty = yLog ? log10f(yv) : yv;

      float sx = map(tx, xMin, xMax, left, right);
      float sy = map(ty, yMin, yMax, bottom, top);

      if (hasPrev) line(px, py, sx, sy);

      px = sx;
      py = sy;
      hasPrev = true;
    }
  }

  // Legend
  float lx = right - 200;
  float ly = top + 10;
  fill(0);
  textAlign(LEFT, TOP);
  text("Legend (Y columns):", lx, ly);
  ly += 16;

  for (int c : yCols) {
    fill(rainbow[c]);
    noStroke();
    rect(lx, ly + 4, 12, 12);
    fill(0);
    text(colNames[c], lx + 20, ly + 2);
    ly += 18;
  }

  // Filter status
  textAlign(LEFT, TOP);
  String fStr = "Filter: ";
  if (filterCol < 0) {
    fStr += "NONE";
  } else {
    fStr += colNames[filterCol] + " in [" +
            printableFilter(filterMin, -Float.MAX_VALUE) + ", " +
            printableFilter(filterMax, Float.MAX_VALUE) + "]";
  }
  text(fStr, left, bottom + 40);
}

String printableFilter(float v, float sentinel) {
  if (v == sentinel) return "∞";
  return nf(v, 1, 4);
}

// ---------- Colors ----------

void buildRainbow() {
  rainbow = new color[colCount];
  colorMode(HSB, 360, 100, 100);
  for (int i = 0; i < colCount; i++) {
    float h = map(i, 0, max(1, colCount-1), 0, 360);
    rainbow[i] = color(h, 90, 90);
  }
  colorMode(RGB, 255);
}

// =========================================================
// GUI COMPONENTS
// =========================================================

class Button {
  float x, y, w, h;
  String label;
  Button(float x, float y, float w, float h, String label) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label;
  }
  void draw() {
    stroke(0);
    fill(245);
    rect(x, y, w, h, 4);
    fill(0);
    textAlign(CENTER, CENTER);
    text(label, x + w/2, y + h/2);
  }
  boolean isClicked() {
    return mouseX > x && mouseX < x+w &&
           mouseY > y && mouseY < y+h;
  }
}

class Checkbox {
  float x, y, boxSize=14;
  String label;
  boolean checked = false;
  Checkbox(float x, float y, String label) {
    this.x=x; this.y=y; this.label=label;
  }
  void draw() {
    stroke(0);
    fill(255);
    rect(x, y, boxSize, boxSize);
    if (checked) {
      line(x, y, x+boxSize, y+boxSize);
      line(x, y+boxSize, x+boxSize, y);
    }
    fill(0);
    textAlign(LEFT, CENTER);
    text(label, x + boxSize + 5, y + boxSize/2);
  }
  boolean handleClick() {
    if (mouseX > x && mouseX < x+boxSize &&
        mouseY > y && mouseY < y+boxSize) {
      checked = !checked;
      return true;
    }
    return false;
  }
}

class ColumnSelector {
  float x, y, w, h;
  String title;
  String[] cols = {};
  int selected = -1;
  ColumnSelector(float x, float y, float w, float h, String title) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.title=title;
  }
  void setColumns(String[] c) { cols = c; selected = -1; }
  void draw() {
    stroke(0);
    fill(250);
    rect(x, y, w, h);
    fill(0);
    textAlign(LEFT, TOP);
    text(title, x+5, y+4);
    if (cols.length == 0) return;
    float yy = y + 22;
    for (int i = 0; i < cols.length; i++) {
      if (i == selected) {
        fill(180, 220, 255);
        noStroke();
        rect(x+4, yy-2, w-8, 16);
        stroke(0);
      }
      fill(0);
      text(cols[i], x+8, yy);
      yy += 16;
      if (yy > y + h - 5) break;
    }
  }
  boolean handleClick() {
    if (mouseX < x || mouseX > x+w ||
        mouseY < y || mouseY > y+h) return false;
    if (cols.length == 0) return true;
    float yy = y + 22;
    for (int i = 0; i < cols.length; i++) {
      if (mouseY >= yy-2 && mouseY <= yy+14) {
        selected = i;
        return true;
      }
      yy += 16;
      if (yy > y + h - 5) break;
    }
    return true;
  }
}

class MultiColumnSelector {
  float x, y, w, h;
  String title;
  String[] cols = {};
  boolean[] selected;
  MultiColumnSelector(float x, float y, float w, float h, String title) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.title=title;
  }
  void setColumns(String[] c) {
    cols = c;
    selected = new boolean[c.length];
  }
  void draw() {
    stroke(0);
    fill(250);
    rect(x, y, w, h);
    fill(0);
    textAlign(LEFT, TOP);
    text(title, x+5, y+4);
    if (cols.length == 0) return;
    float yy = y + 22;
    for (int i = 0; i < cols.length; i++) {
      fill(255);
      stroke(0);
      rect(x+4, yy-2, 12, 12);
      if (selected != null && selected[i]) {
        line(x+4, yy-2, x+16, yy+10);
        line(x+4, yy+10, x+16, yy-2);
      }
      fill(0);
      text(cols[i], x+20, yy);
      yy += 16;
      if (yy > y + h - 5) break;
    }
  }
  boolean handleClick() {
    if (mouseX < x || mouseX > x+w ||
        mouseY < y || mouseY > y+h) return false;
    if (cols.length == 0 || selected == null) return true;
    float yy = y + 22;
    for (int i = 0; i < cols.length; i++) {
      if (mouseY >= yy-2 && mouseY <= yy+14 &&
          mouseX >= x+4 && mouseX <= x+16) {
        selected[i] = !selected[i];
        return true;
      }
      yy += 16;
      if (yy > y + h - 5) break;
    }
    return true;
  }
  int[] getSelected() {
    if (selected == null) return new int[0];
    int cnt = 0;
    for (boolean b : selected) if (b) cnt++;
    int[] out = new int[cnt];
    int idx = 0;
    for (int i = 0; i < selected.length; i++)
      if (selected[i]) out[idx++] = i;
    return out;
  }
}

class TextBox {
  float x, y, w, h;
  String placeholder;
  String text = "";
  boolean active = false;
  TextBox(float x, float y, float w, float h, String placeholder) {
    this.x=x; this.y=y; this.w=w; this.h=h; this.placeholder=placeholder;
  }
  void draw() {
    stroke(active ? color(0, 120, 255) : 0);
    fill(255);
    rect(x, y, w, h);
    fill(0);
    textAlign(LEFT, CENTER);
    String disp = (text.length() > 0) ? text : placeholder;
    text(disp, x+4, y + h/2);
  }
  boolean handleClick() {
    active = (mouseX > x && mouseX < x+w &&
              mouseY > y && mouseY < y+h);
    return active;
  }
  void handleKey(char k) {
    if (k == BACKSPACE) {
      if (text.length() > 0) text = text.substring(0, text.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '-' || k == '.' || k=='e' || k=='E') {
      text += k;
    }
  }
}
