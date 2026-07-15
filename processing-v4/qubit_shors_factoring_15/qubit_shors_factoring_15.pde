// Shor’s Algorithm Visualization (factoring 15)
// Processing 3 or 4

int step = 0; // current stage
String[] stages = {
  "Initialize superposition of exponent register",
  "Apply modular exponentiation: |x>|1> -> |x>|2^x mod 15>",
  "Apply Quantum Fourier Transform (QFT)",
  "Measure -> deduce period r = 4",
  "Classical post-processing: gcd(2^(r/2) ± 1, 15) = 3, 5"
};

void setup() {
  size(900, 600);
  textAlign(CENTER, CENTER);
  textSize(16);
}

void draw() {
  background(245);
  
  // Title
  fill(0);
  textSize(20);
  text("Shor's Algorithm: Factoring 15", width/2, 30);
  textSize(16);
  
  // Draw registers
  drawRegister(100, 100, 8, "Exponent Register (8 qubits: q0–q7)");
  drawRegister(100, 250, 4, "Work Register (4 qubits: q8–q11)");
  
  // Draw arrows for operations
  drawStage(step);
  
  // Instructions
  fill(80);
  text("Press any key to step through stages", width/2, height - 40);
  
  // Show stage description
  fill(20);
  textSize(18);
  text("Stage " + step + ": " + stages[step], width/2, height - 80);
}

void drawRegister(float x, float y, int n, String label) {
  float boxW = 50;
  float boxH = 40;
  float spacing = 10;
  
  fill(0);
  text(label, width/2, y - 30);
  
  for (int i = 0; i < n; i++) {
    float bx = x + i*(boxW+spacing);
    stroke(0);
    fill(255);
    rect(bx, y, boxW, boxH);
    fill(0);
    text("q"+i, bx+boxW/2, y+boxH/2);
  }
}

void drawStage(int s) {
  stroke(0);
  strokeWeight(2);
  fill(0);
  textSize(14);
  
  if (s == 0) {
    // Hadamards on exponent register
    for (int i = 0; i < 8; i++) {
      float bx = 100 + i*60 + 25;
      line(bx, 100+40, bx, 250);
      text("H", bx, 90);
    }
  } else if (s == 1) {
    // Modular exponentiation arrows
    for (int i = 0; i < 8; i++) {
      float bx = 100 + i*60 + 25;
      line(bx, 100+40, bx, 250);
      text("2^x mod 15", bx, 200);
    }
  } else if (s == 2) {
    // QFT gates
    for (int i = 0; i < 8; i++) {
      float bx = 100 + i*60 + 25;
      text("QFT", bx, 90);
    }
  } else if (s == 3) {
    // Measurement
    for (int i = 0; i < 8; i++) {
      float bx = 100 + i*60 + 25;
      line(bx, 100+40, bx, 350);
      ellipse(bx, 360, 20, 20);
      line(bx, 370, bx, 390);
      line(bx-10, 390, bx+10, 390);
    }
  } else if (s == 4) {
    textSize(18);
    text("Result: Factors of 15 = 3 and 5", width/2, 450);
  }
}

void keyPressed() {
  step = (step + 1) % stages.length;
}
