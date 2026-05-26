// =============================================================
// Sketch A: Grid of All 64 I-Ching Hexagrams (Binary Order)
// =============================================================

int cellSize = 80;
int cols = 8;
int rows = 8;

void settings() {
    size(cols * cellSize, rows * cellSize);
}
void setup() {

  noLoop();
}

void draw() {
  background(0);

  int index = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      drawHexagram(index, c * cellSize, r * cellSize, cellSize);
      index++;
    }
  }
}

// Draw hexagram from 6-bit index
void drawHexagram(int n, int x, int y, int size) {
  pushMatrix();
  translate(x, y);

  fill(0);
  stroke(255);
  rect(0, 0, size, size);

  float lineH = size / 7.0;
  float margin = size * 0.15;

  for (int i = 0; i < 6; i++) {
    int bit = (n >> i) & 1;  // Yin=0, Yang=1
    float yy = size - (i+1) * lineH - 4;

    if (bit == 1) { // Yang (solid)
      strokeWeight(6);
      line(margin, yy, size - margin, yy);
    } else { // Yin (broken)
      strokeWeight(6);
      float gap = size * 0.12;
      line(margin, yy, size/2 - gap, yy);
      line(size/2 + gap, yy, size - margin, yy);
    }
  }

  popMatrix();
}
