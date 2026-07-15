// NVIDIA GPU SM / Warp Scheduler Toy Model
// Processing 4.x

int numSMs = 4;
int blocks = 16;
int threadsPerBlock = 256;

int warpSize = 32;
int maxResidentWarpsPerSM = 64;
int maxActiveWarpsPerSM = 4;

ArrayList<SM> sms = new ArrayList<SM>();

int selectedField = 0; // 0 = blocks, 1 = threads/block

void setup() {
  size(1200, 800);
  textFont(createFont("Arial", 14));
  initSimulation();
}

void draw() {
  background(28);
  drawUI();

  for (SM sm : sms) {
    sm.update();
    sm.display();
  }

  drawLegend();
}

void initSimulation() {
  sms.clear();

  int totalWarps = ceil(blocks * threadsPerBlock / float(warpSize));

  for (int i = 0; i < numSMs; i++) {
    float x = 40 + i * ((width - 80) / float(numSMs));
    float w = (width - 100) / float(numSMs);
    sms.add(new SM(i, x, 120, w - 15, 560));
  }

  int warpID = 0;

  while (warpID < totalWarps) {
    for (SM sm : sms) {
      if (warpID >= totalWarps) break;

      if (sm.warps.size() < maxResidentWarpsPerSM) {
        sm.warps.add(new Warp(warpID));
        warpID++;
      }
    }

    boolean allFull = true;
    for (SM sm : sms) {
      if (sm.warps.size() < maxResidentWarpsPerSM) {
        allFull = false;
        break;
      }
    }

    if (allFull) break;
  }
}

void drawUI() {
  fill(255);
  textSize(22);
  text("Toy NVIDIA GPU Model: SMs Managing Resident Warps", 40, 40);

  textSize(14);
  text("Press 1/2 to select a parameter. Use UP/DOWN to change it. Press R to reset.", 40, 68);

  drawParam("Blocks", blocks, 40, 92, selectedField == 0);
  drawParam("Threads per block", threadsPerBlock, 180, 92, selectedField == 1);

  int totalThreads = blocks * threadsPerBlock;
  int totalWarps = ceil(totalThreads / float(warpSize));
  int residentCapacity = numSMs * maxResidentWarpsPerSM;

  fill(230);
  text("Total threads: " + totalThreads +
       "    Total warps: " + totalWarps +
       "    Resident capacity shown: " + residentCapacity +
       " warps", 410, 100);
}

void drawParam(String label, int value, int x, int y, boolean selected) {
  if (selected) fill(80, 110, 180);
  else fill(55);

  stroke(150);
  rect(x, y - 22, 120, 32, 6);

  fill(255);
  text(label + ": " + value, x + 8, y);
}

void drawLegend() {
  int x = 40;
  int y = height - 70;

  drawLegendItem(x, y, color(170, 240, 170), "Active warp: selected by scheduler");
  drawLegendItem(x + 290, y, color(255, 210, 150), "Waiting on memory");
  drawLegendItem(x + 520, y, color(170, 210, 255), "Resident but inactive");
}

void drawLegendItem(int x, int y, color c, String label) {
  fill(c);
  stroke(40);
  rect(x, y, 22, 22, 4);

  fill(240);
  text(label, x + 30, y + 16);
}

void keyPressed() {
  if (key == '1') selectedField = 0;
  if (key == '2') selectedField = 1;

  if (key == 'r' || key == 'R') {
    initSimulation();
  }

  if (keyCode == UP) {
    if (selectedField == 0) blocks += 1;
    if (selectedField == 1) threadsPerBlock += 32;
    initSimulation();
  }

  if (keyCode == DOWN) {
    if (selectedField == 0) blocks = max(1, blocks - 1);
    if (selectedField == 1) threadsPerBlock = max(32, threadsPerBlock - 32);
    initSimulation();
  }
}

class SM {
  int id;
  float x, y, w, h;
  ArrayList<Warp> warps = new ArrayList<Warp>();

  SM(int id, float x, float y, float w, float h) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void update() {
    if (frameCount % 35 == 0) {
      for (Warp warp : warps) {
        float r = random(1);

        if (r < 0.18) warp.state = 1;       // memory wait
        else warp.state = 2;                // resident inactive
      }

      ArrayList<Warp> runnable = new ArrayList<Warp>();

      for (Warp warp : warps) {
        if (warp.state != 1) {
          runnable.add(warp);
        }
      }

      for (int i = 0; i < min(maxActiveWarpsPerSM, runnable.size()); i++) {
        int pick = int(random(runnable.size()));
        runnable.get(pick).state = 0;       // active
        runnable.remove(pick);
      }
    }
  }

  void display() {
    fill(45);
    stroke(180);
    strokeWeight(2);
    rect(x, y, w, h, 12);

    fill(255);
    textSize(18);
    text("SM " + id, x + 14, y + 28);

    textSize(12);
    text("Resident warps: " + warps.size() + " / " + maxResidentWarpsPerSM, x + 14, y + 50);
    text("Active limit: " + maxActiveWarpsPerSM, x + 14, y + 68);

    int cols = 8;
    int rows = 8;

    float pad = 12;
    float boxW = (w - 2 * pad) / cols;
    float boxH = (h - 100) / rows;

    for (int i = 0; i < maxResidentWarpsPerSM; i++) {
      int col = i % cols;
      int row = i / cols;

      float bx = x + pad + col * boxW;
      float by = y + 88 + row * boxH;

      if (i < warps.size()) {
        warps.get(i).display(bx, by, boxW - 4, boxH - 4);
      } else {
        fill(70);
        stroke(95);
        rect(bx, by, boxW - 4, boxH - 4, 5);
      }
    }
  }
}

class Warp {
  int id;

  // 0 = active
  // 1 = waiting on memory
  // 2 = resident inactive
  int state = 2;

  Warp(int id) {
    this.id = id;
  }

  void display(float x, float y, float w, float h) {
    if (state == 0) fill(170, 240, 170);
    else if (state == 1) fill(255, 210, 150);
    else fill(170, 210, 255);

    stroke(30);
    rect(x, y, w, h, 5);

    fill(20);
    textSize(10);
    text("W" + id, x + 4, y + 13);
  }
}
