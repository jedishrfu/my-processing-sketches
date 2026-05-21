// Ackermann Function Demo
// Processing 4.x

int m = 0;
int n = 0;

String resultText = "";
String traceText = "";

int maxDepth = 10000;
int callCount = 0;
boolean overflowed = false;

void setup() {
  size(1000, 700);
  textFont(createFont("Monospaced", 18));
  computeAckermann();
}

void draw() {
  background(20);

  fill(255);
  textSize(26);
  text("Ackermann Function Demo", 30, 45);

  textSize(18);
  fill(220);
  text("A(m, n) =", 30, 90);
  text("  n + 1                    if m = 0", 30, 120);
  text("  A(m - 1, 1)              if m > 0 and n = 0", 30, 150);
  text("  A(m - 1, A(m, n - 1))    if m > 0 and n > 0", 30, 180);

  fill(255, 220, 120);
  textSize(22);
  text("Current: A(" + m + ", " + n + ")", 30, 235);

  fill(120, 220, 255);
  text(resultText, 30, 270);

  fill(180);
  textSize(16);
  text("Controls:", 30, 330);
  text("LEFT / RIGHT  : decrease / increase n", 30, 360);
  text("DOWN / UP     : decrease / increase m", 30, 385);
  text("R             : reset to A(0, 0)", 30, 410);

  fill(255, 150, 150);
  text("Safety limits: m ≤ 4, n ≤ 3. Ackermann grows insanely fast.", 30, 455);

  fill(210);
  text("Recursive call trace:", 30, 505);

  fill(170, 220, 170);
  textSize(14);
  text(traceText, 30, 535, width - 60, height - 550);
}

void keyPressed() {
  if (keyCode == RIGHT) {
    n++;
  } else if (keyCode == LEFT) {
    n = max(0, n - 1);
  } else if (keyCode == UP) {
    m++;
  } else if (keyCode == DOWN) {
    m = max(0, m - 1);
  } else if (key == 'r' || key == 'R') {
    m = 0;
    n = 0;
  }

  // Keep the demo from exploding
  m = constrain(m, 0, 4);
  n = constrain(n, 0, 3);

  computeAckermann();
}

void computeAckermann() {
  callCount = 0;
  overflowed = false;
  traceText = "";

  int value = ackermann(m, n, 0);

  if (overflowed) {
    resultText = "Too many recursive calls — computation stopped.";
  } else {
    resultText = "A(" + m + ", " + n + ") = " + value +
                 "    calls: " + callCount;
  }
}

int ackermann(int m, int n, int depth) {
  callCount++;

  if (callCount > maxDepth) {
    overflowed = true;
    return -1;
  }

  if (depth < 18) {
    for (int i = 0; i < depth; i++) traceText += "  ";
    traceText += "A(" + m + ", " + n + ")\n";
  } else if (depth == 18) {
    traceText += "  ... trace truncated ...\n";
  }

  if (m == 0) {
    return n + 1;
  }

  if (n == 0) {
    return ackermann(m - 1, 1, depth + 1);
  }

  int inner = ackermann(m, n - 1, depth + 1);

  if (overflowed) return -1;

  return ackermann(m - 1, inner, depth + 1);
}
