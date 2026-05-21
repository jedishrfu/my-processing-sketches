// =============================================================
// Sketch B: Animated Fuxi / Fu Hsi Sequence of 64 Hexagrams
// =============================================================

int cellSize = 200;
int[] FUXI = {
  1,43,14,34,9,5,26,11,
  10,58,38,54,61,60,41,19,
  13,49,30,55,37,63,22,36,
  25,17,21,51,42,3,27,24,
  44,28,50,32,57,48,18,46,
  6,47,64,40,59,29,4,7,
  33,31,56,62,53,39,52,15,
  12,45,35,16,20,8,23,2
};

int idx = 0;
boolean running = true;

void setup() {
  size(300, 300);
  frameRate(1);
}

void draw() {
  background(0);
  drawHexagram(FUXI[idx] - 1, 50, 50, 200);

  fill(255);
  textSize(18);
  text("Fuxi sequence index: " + idx, 10, 20);

  if (running) {
    idx = (idx + 1) % 64;
  }
}

void keyPressed() {
  if (key == ' ') running = !running;
}

void drawHexagram(int n, int x, int y, int size) {
  pushMatrix();
  translate(x, y);

  float lineH = size / 7.0;
  float margin = size * 0.15;

  for (int i = 0; i < 6; i++) {
    int bit = (n >> i) & 1;
    float yy = size - (i+1)*lineH;

    stroke(255);
    strokeWeight(8);

    if (bit == 1) {
      line(margin, yy, size-margin, yy);
    } else {
      float gap = size * 0.12;
      line(margin, yy, size/2-gap, yy);
      line(size/2+gap, yy, size-margin, yy);
    }
  }

  popMatrix();
}
