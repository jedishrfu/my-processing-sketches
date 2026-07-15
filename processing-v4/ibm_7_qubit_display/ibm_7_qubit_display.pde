final int NUM_QUBITS = 7;
int[] qubitValues = new int[NUM_QUBITS];
boolean[] measuredValues = new boolean[NUM_QUBITS];
boolean isMeasured = false;
int boxSize = 60;
int spacing = 20;
int startX, startY;

void setup() {
  size(800, 200);
  textAlign(CENTER, CENTER);
  textSize(32);
  startX = (width - (NUM_QUBITS * (boxSize + spacing) - spacing)) / 2;
  startY = height / 2 - boxSize / 2;
}

void draw() {
  background(255);

  for (int i = 0; i < NUM_QUBITS; i++) {
    int x = startX + i * (boxSize + spacing);
    int y = startY;

    // Update value if not yet measured
    if (!isMeasured) {
      qubitValues[i] = int(random(2));  // 0 or 1
    }

    // Draw box
    stroke(0);
    fill(240);
    rect(x, y, boxSize, boxSize);

    // Draw value
    textSize(32); // 🔧 Set font size for bit value
    fill(0);
    text(qubitValues[i], x + boxSize / 2, y + boxSize / 2);

    // Label qubit index
    textSize(12); // 🔧 Set font size for label
    text("q" + i, x + boxSize / 2, y + boxSize + 15);
  }

  // Instruction
  fill(0);
  textSize(14);
  String msg = isMeasured ? "Click to restart simulation" : "Click to measure qubits";
  text(msg, width / 2, height - 20);
}

void mousePressed() {
  isMeasured = !isMeasured;
}
