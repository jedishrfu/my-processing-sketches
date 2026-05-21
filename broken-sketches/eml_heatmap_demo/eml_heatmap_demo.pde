// EML Concept Visualizer
// eml(x,y) = exp(x) - ln(y)
//
// Keys:
// 1 = heatmap of eml(x,y)
// 2 = compare exp(x), ln(y), and eml(x,y)
// 3 = nested EML expression tree
// 4 = symbolic-regression style population demo
// SPACE = randomize trees
// +/- = change tree depth

int mode = 1;
int maxDepth = 3;
ArrayList<Node> population = new ArrayList<Node>();

float xmin = -2;
float xmax = 2;
float ymin = 0.1;
float ymax = 5;

PFont font;

void setup() {
  size(1200, 750);
  font = createFont("Arial", 16);
  textFont(font);
  randomizePopulation();
}

void draw() {
  background(18);

  drawHeader();

  if (mode == 1) drawHeatmap();
  if (mode == 2) drawFunctionComparison();
  if (mode == 3) drawTreeDemo();
  if (mode == 4) drawPopulationDemo();

  drawFooter();
}

float eml(float x, float y) {
  y = max(y, 0.0001);     // ln(y) requires y > 0
  return exp(x) - log(y);
}

void drawHeader() {
  fill(255);
  textSize(24);
  text("EML Operator Visualizer: eml(x,y) = exp(x) - ln(y)", 30, 38);

  textSize(15);
  fill(210);
  text("One binary operator mixes exponential growth with logarithmic compression.", 30, 65);
  text("The point: repeated nesting of this single operator can represent richer arithmetic structure.", 30, 87);

  fill(255, 220, 120);
  text("Mode " + mode + "   |   Depth: " + maxDepth, 980, 38);
}

void drawFooter() {
  fill(180);
  textSize(14);
  text("Keys: 1 heatmap   2 curves   3 expression tree   4 population search   SPACE randomize   +/- depth", 30, height - 25);
}

// ------------------------------------------------------------
// MODE 1: Heatmap
// ------------------------------------------------------------

void drawHeatmap() {
  int left = 70;
  int top = 130;
  int w = 720;
  int h = 500;

  float minVal = 999999;
  float maxVal = -999999;

  for (int i = 0; i < w; i += 4) {
    for (int j = 0; j < h; j += 4) {
      float x = map(i, 0, w, xmin, xmax);
      float y = map(j, h, 0, ymin, ymax);
      float z = eml(x, y);
      minVal = min(minVal, z);
      maxVal = max(maxVal, z);
    }
  }

  noStroke();

  for (int i = 0; i < w; i += 4) {
    for (int j = 0; j < h; j += 4) {
      float x = map(i, 0, w, xmin, xmax);
      float y = map(j, h, 0, ymin, ymax);
      float z = eml(x, y);

      float t = map(z, minVal, maxVal, 0, 1);
      fill(lerpColor(color(40, 70, 180), color(255, 190, 60), t));
      rect(left + i, top + j, 4, 4);
    }
  }

  stroke(255);
  noFill();
  rect(left, top, w, h);

  fill(255);
  textSize(18);
  text("Heatmap of eml(x,y)", left, top - 20);

  textSize(14);
  text("x from " + xmin + " to " + xmax, left + 250, top + h + 35);
  pushMatrix();
  translate(left - 45, top + h / 2 + 60);
  rotate(-HALF_PI);
  text("y from " + ymin + " to " + ymax, 0, 0);
  popMatrix();

  fill(230);
  textSize(16);
  text("Interpretation", 850, 160);

  textSize(14);
  fill(200);
  text("Bright regions mean eml(x,y) is large.", 850, 195);
  text("Large x makes exp(x) dominate.", 850, 220);
  text("Small y makes -ln(y) positive and large.", 850, 245);
  text("Large y subtracts more because ln(y) grows.", 850, 270);

  fill(255, 220, 120);
  text("eml(x,1) = exp(x)", 850, 330);
  text("because ln(1) = 0", 850, 355);

  fill(150, 220, 255);
  text("eml(ln(a), exp(b)) = a - b", 850, 415);
  text("because exp(ln(a)) = a", 850, 440);
  text("and ln(exp(b)) = b", 850, 465);
}

// ------------------------------------------------------------
// MODE 2: Curves
// ------------------------------------------------------------

void drawFunctionComparison() {
  int left = 90;
  int top = 140;
  int w = 700;
  int h = 460;

  drawAxes(left, top, w, h, -2, 2, -4, 8);

  plotCurve(left, top, w, h, -2, 2, -4, 8, 0);
  plotCurve(left, top, w, h, -2, 2, -4, 8, 1);
  plotCurve(left, top, w, h, -2, 2, -4, 8, 2);

  fill(255);
  textSize(18);
  text("Three related curves", left, top - 30);

  fill(255, 160, 80);
  text("orange: exp(x)", 850, 180);

  fill(90, 190, 255);
  text("blue: ln(x + 2.2)", 850, 215);

  fill(150, 255, 150);
  text("green: eml(x, 2)", 850, 250);

  fill(220);
  textSize(15);
  text("EML combines exp and log into one primitive.", 850, 320);
  text("Fixing y = 1 gives pure exp(x).", 850, 350);
  text("Nested compositions can recover operations", 850, 380);
  text("like subtraction, addition, multiplication,", 850, 410);
  text("division, and intrinsic functions.", 850, 440);
}

void plotCurve(int left, int top, int w, int h,
               float ax, float bx, float ay, float by, int which) {
  noFill();

  if (which == 0) stroke(255, 160, 80);
  if (which == 1) stroke(90, 190, 255);
  if (which == 2) stroke(150, 255, 150);

  strokeWeight(3);
  beginShape();

  for (int i = 0; i < w; i++) {
    float x = map(i, 0, w, ax, bx);
    float yval = 0;

    if (which == 0) yval = exp(x);
    if (which == 1) yval = log(x + 2.2);
    if (which == 2) yval = eml(x, 2);

    float sx = left + i;
    float sy = map(yval, ay, by, top + h, top);
    vertex(sx, sy);
  }

  endShape();
  strokeWeight(1);
}

void drawAxes(int left, int top, int w, int h,
              float ax, float bx, float ay, float by) {
  stroke(150);
  noFill();
  rect(left, top, w, h);

  stroke(90);
  for (int i = 0; i <= 10; i++) {
    float x = left + i * w / 10.0;
    line(x, top, x, top + h);
  }

  for (int i = 0; i <= 10; i++) {
    float y = top + i * h / 10.0;
    line(left, y, left + w, y);
  }

  stroke(255);
  float zeroX = map(0, ax, bx, left, left + w);
  float zeroY = map(0, ay, by, top + h, top);

  if (zeroX >= left && zeroX <= left + w) line(zeroX, top, zeroX, top + h);
  if (zeroY >= top && zeroY <= top + h) line(left, zeroY, left + w, zeroY);
}

// ------------------------------------------------------------
// MODE 3: Tree demo
// ------------------------------------------------------------

void drawTreeDemo() {
  Node root = new Node("eml",
    new Node("eml", new Node("x"), new Node("1")),
    new Node("eml", new Node("y"), new Node("1"))
  );

  fill(255);
  textSize(18);
  text("A nested EML expression tree", 70, 130);

  drawTree(root, width / 2, 180, 260, 0);

  fill(220);
  textSize(15);
  text("This tree is not meant to be the simplest expression.", 70, 620);
  text("It shows the grammar idea:", 70, 645);

  fill(255, 220, 120);
  text("S → x | y | 1 | eml(S, S)", 70, 675);

  fill(220);
  text("A symbolic regression system searches over trees like this.", 70, 705);
}

void drawTree(Node n, float x, float y, float spread, int depth) {
  if (n == null) return;

  if (n.left != null) {
    stroke(180);
    line(x, y, x - spread, y + 90);
    drawTree(n.left, x - spread, y + 90, spread * 0.55, depth + 1);
  }

  if (n.right != null) {
    stroke(180);
    line(x, y, x + spread, y + 90);
    drawTree(n.right, x + spread, y + 90, spread * 0.55, depth + 1);
  }

  if (n.label.equals("eml")) fill(255, 180, 80);
  else fill(80, 180, 255);

  stroke(255);
  ellipse(x, y, 68, 42);

  fill(0);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(n.label, x, y);
  textAlign(LEFT, BASELINE);
}

// ------------------------------------------------------------
// MODE 4: Population demo
// ------------------------------------------------------------

void drawPopulationDemo() {
  fill(255);
  textSize(18);
  text("Symbolic-regression style population", 70, 130);

  fill(210);
  textSize(14);
  text("Each candidate is a random EML tree. We test how close it is to target f(x,y)=x+y.", 70, 158);
  text("Lower error means the tree behaves more like addition over sampled inputs.", 70, 181);

  int startY = 230;

  population.sort((a, b) -> Float.compare(scoreTree(a), scoreTree(b)));

  for (int i = 0; i < min(10, population.size()); i++) {
    Node n = population.get(i);
    float err = scoreTree(n);

    fill(255);
    textSize(15);
    text("#" + (i + 1), 80, startY + i * 42);

    fill(255, 220, 120);
    text("error = " + nf(err, 1, 4), 130, startY + i * 42);

    fill(210);
    text(n.toExpr(), 280, startY + i * 42);
  }

  fill(220);
  textSize(15);
  text("Press SPACE to create a new random population.", 70, 690);
}

float scoreTree(Node n) {
  float total = 0;
  int count = 0;

  for (float x = -1; x <= 1.01; x += 0.5) {
    for (float y = 0.5; y <= 2.01; y += 0.5) {
      float target = x + y;
      float val = n.eval(x, y);

      if (Float.isNaN(val) || Float.isInfinite(val)) val = 9999;

      float diff = val - target;
      total += diff * diff;
      count++;
    }
  }

  return total / count;
}

void randomizePopulation() {
  population.clear();
  for (int i = 0; i < 40; i++) {
    population.add(randomTree(maxDepth));
  }
}

Node randomTree(int depth) {
  if (depth <= 0 || random(1) < 0.35) {
    float r = random(1);
    if (r < 0.33) return new Node("x");
    if (r < 0.66) return new Node("y");
    return new Node("1");
  }

  return new Node("eml", randomTree(depth - 1), randomTree(depth - 1));
}

// ------------------------------------------------------------
// Node class
// ------------------------------------------------------------

class Node {
  String label;
  Node left;
  Node right;

  Node(String label) {
    this.label = label;
  }

  Node(String label, Node left, Node right) {
    this.label = label;
    this.left = left;
    this.right = right;
  }

  float eval(float x, float y) {
    if (label.equals("x")) return x;
    if (label.equals("y")) return y;
    if (label.equals("1")) return 1;

    if (label.equals("eml")) {
      float a = left.eval(x, y);
      float b = right.eval(x, y);

      // keep log input positive
      b = max(abs(b), 0.0001);

      float v = eml(a, b);

      // clamp to avoid graph-killing explosions
      if (v > 1000) v = 1000;
      if (v < -1000) v = -1000;

      return v;
    }

    return 0;
  }

  String toExpr() {
    if (!label.equals("eml")) return label;

    String s = "eml(" + left.toExpr() + ", " + right.toExpr() + ")";

    if (s.length() > 95) {
      s = s.substring(0, 95) + "...";
    }

    return s;
  }
}

// ------------------------------------------------------------
// Input
// ------------------------------------------------------------

void keyPressed() {
  if (key == '1') mode = 1;
  if (key == '2') mode = 2;
  if (key == '3') mode = 3;
  if (key == '4') mode = 4;

  if (key == ' ') randomizePopulation();

  if (key == '+') {
    maxDepth++;
    maxDepth = min(maxDepth, 6);
    randomizePopulation();
  }

  if (key == '-') {
    maxDepth--;
    maxDepth = max(maxDepth, 1);
    randomizePopulation();
  }
}
