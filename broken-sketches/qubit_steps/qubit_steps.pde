final int NUM_QUBITS = 7;
int[] qubits = new int[NUM_QUBITS];
boolean isMeasured = false;
int phase = 0; // 0: Superposition, 1: Entanglement, 2: Measurement

int boxSize = 60;
int spacing = 20;
int startX, startY;

void setup() {
  size(800, 300);
  textAlign(CENTER, CENTER);
  textSize(24);
  startX = (width - (NUM_QUBITS * (boxSize + spacing) - spacing)) / 2;
  startY = height / 2 - boxSize;
}

void draw() {
  background(255);
  drawQubits();

  fill(0);
  textSize(16);
  if (phase == 0) {
    text("Phase 1: Hadamard Superposition (Input Qubits)", width / 2, 30);
  } else if (phase == 1) {
    text("Phase 2: Modular Exponentiation (Entanglement)", width / 2, 30);
  } else if (phase == 2) {
    text("Phase 3: QFT + Measurement", width / 2, 30);
  }
  text("Click to advance phase", width / 2, height - 20);
}

void drawQubits() {
  for (int i = 0; i < NUM_QUBITS; i++) {
    int x = startX + i * (boxSize + spacing);
    int y = startY;

    // Update values based on phase
    if (phase == 0 && i < 3) {
      qubits[i] = int(random(2)); // Superposition on input qubits
    } else if (phase == 1 && i >= 3) {
      qubits[i] = qubits[i - 3]; // Output mimics input (simplified entanglement)
    } else if (phase == 2 && !isMeasured) {
      for (int j = 0; j < NUM_QUBITS; j++) {
        qubits[j] = int(random(2)); // Collapse to measurement
      }
      isMeasured = true;
    }

    // Draw box
    stroke(0);
    fill(240);
    rect(x, y, boxSize, boxSize);

    // Draw qubit value
    fill(0);
    textSize(24);
    text(qubits[i], x + boxSize / 2, y + boxSize / 2);

    // Label
    textSize(12);
    text("q" + i, x + boxSize / 2, y + boxSize + 15);
  }
}

void mousePressed() {
  if (phase < 2) {
    phase++;
  } else {
    phase = 0;
    isMeasured = false;
  }
}
