// EML Symbolic Regression Demo
// eml(x,y) = exp(x) - ln(y)
//
// Keys:
// r = make random curve
// l = load little-endian fp32 file
// e = evolve one generation
// a = auto-evolve on/off
// space = evolve 100 generations
// z/x = zoom in/out
// [/] = page left/right
// -/+ = fewer/more visible samples
// h = clear approximation history
// n/m = fewer/more fp32 values to read
// d/f = decrease/increase tree depth

import java.io.*;
import java.nio.*;
import java.util.*;

float[] data;
float[] bestFit;
ArrayList<float[]> oldFits = new ArrayList<float[]>();

int numToRead = 2048;
int visibleCount = 512;
int pageStart = 0;

boolean autoEvolve = false;

int popSize = 120;
int maxDepth = 4;
ArrayList<Node> population = new ArrayList<Node>();
Node bestTree = null;

float bestMSE = Float.MAX_VALUE;
int generation = 0;

PFont font;

void setup() {
  size(1300, 780);
  font = createFont("Arial", 15);
  textFont(font);

  makeRandomCurve();
  initPopulation();
}

void draw() {
  background(20);

  if (autoEvolve) {
    for (int i = 0; i < 5; i++) evolveOneGeneration();
  }

  drawPlot();
  drawInfo();
}

// ------------------------------------------------------------
// EML operator
// ------------------------------------------------------------

float eml(float x, float y) {
  // Real EML requires y > 0.
  // This keeps evolved trees numerically safe.
  y = abs(y) + 1e-6;

  float ex = exp(constrain(x, -12, 12));
  float ly = log(y);

  float v = ex - ly;

  if (Float.isNaN(v) || Float.isInfinite(v)) return 1e6;
  return constrain(v, -1e6, 1e6);
}

// ------------------------------------------------------------
// Data
// ------------------------------------------------------------

void makeRandomCurve() {
  int n = numToRead;
  data = new float[n];

  float a = random(0.5, 2.5);
  float b = random(0.5, 4.0);
  float c = random(-1.0, 1.0);
  float d = random(0.2, 1.0);
  float e = random(-0.6, 0.6);

  for (int i = 0; i < n; i++) {
    float x = normX(i, n);

    // random-ish smooth target
    float y =
      a * sin(TWO_PI * b * x)
      + c * cos(TWO_PI * 0.5 * b * x)
      + d * x * x
      + e * x
      + randomGaussian() * 0.03;

    data[i] = y;
  }

  normalizeData();
  pageStart = 0;
  oldFits.clear();
  initPopulation();
}

void normalizeData() {
  float mean = 0;
  for (float v : data) mean += v;
  mean /= data.length;

  float maxAbs = 1e-6;
  for (int i = 0; i < data.length; i++) {
    data[i] -= mean;
    maxAbs = max(maxAbs, abs(data[i]));
  }

  for (int i = 0; i < data.length; i++) {
    data[i] /= maxAbs;
  }
}

float normX(int i, int n) {
  if (n <= 1) return 0;
  return map(i, 0, n - 1, -1, 1);
}

void loadFP32LittleEndian(File file) {
  if (file == null) return;

  try {
    byte[] bytes = loadBytes(file.getAbsolutePath());
    int count = min(numToRead, bytes.length / 4);

    data = new float[count];

    ByteBuffer bb = ByteBuffer.wrap(bytes);
    bb.order(ByteOrder.LITTLE_ENDIAN);

    for (int i = 0; i < count; i++) {
      data[i] = bb.getFloat();
    }

    normalizeData();
    pageStart = 0;
    oldFits.clear();
    initPopulation();
  }
  catch (Exception ex) {
    println("Load failed: " + ex.getMessage());
  }
}

// ------------------------------------------------------------
// Symbolic regression
// ------------------------------------------------------------

void initPopulation() {
  population.clear();

  for (int i = 0; i < popSize; i++) {
    population.add(randomTree(maxDepth));
  }

  bestTree = null;
  bestFit = null;
  bestMSE = Float.MAX_VALUE;
  generation = 0;
}

void evolveOneGeneration() {
  if (data == null || data.length == 0) return;

  Collections.sort(population, new Comparator<Node>() {
    public int compare(Node a, Node b) {
      return Float.compare(score(a), score(b));
    }
  });

  Node genBest = population.get(0);
  float genBestScore = score(genBest);

  if (genBestScore < bestMSE) {
    bestMSE = genBestScore;
    bestTree = genBest.copy();

    if (bestFit != null) {
      oldFits.add(bestFit);
      if (oldFits.size() > 10) oldFits.remove(0);
    }

    bestFit = evalTree(bestTree);
  }

  ArrayList<Node> next = new ArrayList<Node>();

  // elitism
  for (int i = 0; i < 10; i++) {
    next.add(population.get(i).copy());
  }

  while (next.size() < popSize) {
    Node parent = tournament();
    Node child = parent.copy();

    if (random(1) < 0.8) child.mutate(maxDepth);
    if (random(1) < 0.25) child = crossover(child, tournament());

    next.add(child);
  }

  population = next;
  generation++;
}

Node tournament() {
  Node best = null;
  float bestS = Float.MAX_VALUE;

  for (int i = 0; i < 5; i++) {
    Node n = population.get((int)random(population.size()));
    float s = score(n);

    if (s < bestS) {
      bestS = s;
      best = n;
    }
  }

  return best;
}

Node crossover(Node a, Node b) {
  // Simple demo crossover: occasionally replace a subtree with b.
  if (random(1) < 0.3) return b.copy();

  Node c = a.copy();

  if (c.left != null && random(1) < 0.5) c.left = b.copy();
  else if (c.right != null) c.right = b.copy();

  return c;
}

float score(Node tree) {
  float mse = 0;
  int n = data.length;

  for (int i = 0; i < n; i++) {
    float x = normX(i, n);
    float y = tree.eval(x);

    if (Float.isNaN(y) || Float.isInfinite(y)) y = 1e6;

    float diff = y - data[i];
    mse += diff * diff;
  }

  mse /= n;

  // modest complexity penalty
  mse += 0.0005 * tree.size();

  return mse;
}

float[] evalTree(Node tree) {
  float[] out = new float[data.length];

  for (int i = 0; i < data.length; i++) {
    float x = normX(i, data.length);
    out[i] = tree.eval(x);
  }

  return out;
}

// ------------------------------------------------------------
// Metrics
// ------------------------------------------------------------

Stats computeStats(float[] target, float[] approx) {
  Stats s = new Stats();

  if (target == null || approx == null) return s;

  int n = min(target.length, approx.length);

  float minV = Float.MAX_VALUE;
  float maxV = -Float.MAX_VALUE;

  for (int i = 0; i < n; i++) {
    minV = min(minV, target[i]);
    maxV = max(maxV, target[i]);
  }

  float peak = max(abs(minV), abs(maxV));
  if (peak < 1e-6) peak = 1;

  for (int i = 0; i < n; i++) {
    float err = approx[i] - target[i];

    s.mse += err * err;
    s.mae += abs(err);
    s.maxAbsError = max(s.maxAbsError, abs(err));

    s.meanTarget += target[i];
    s.meanApprox += approx[i];
  }

  s.mse /= n;
  s.mae /= n;
  s.rmse = sqrt(s.mse);
  s.meanTarget /= n;
  s.meanApprox /= n;

  s.psnr = 20.0 * log10(peak / max(s.rmse, 1e-9));

  return s;
}

float log10(float x) {
  return log(x) / log(10);
}

class Stats {
  float mse = 0;
  float mae = 0;
  float rmse = 0;
  float psnr = 0;
  float maxAbsError = 0;
  float meanTarget = 0;
  float meanApprox = 0;
}

// ------------------------------------------------------------
// Drawing
// ------------------------------------------------------------

void drawPlot() {
  int left = 70;
  int top = 95;
  int w = width - 120;
  int h = height - 220;

  fill(245);
  textSize(20);
  text("EML Regression Approximation", left, 40);

  noFill();
  stroke(120);
  rect(left, top, w, h);

  if (data == null) return;

  int end = min(data.length, pageStart + visibleCount);

  float ymin = Float.MAX_VALUE;
  float ymax = -Float.MAX_VALUE;

  for (int i = pageStart; i < end; i++) {
    ymin = min(ymin, data[i]);
    ymax = max(ymax, data[i]);

    if (bestFit != null) {
      ymin = min(ymin, bestFit[i]);
      ymax = max(ymax, bestFit[i]);
    }
  }

  if (abs(ymax - ymin) < 1e-6) {
    ymax += 1;
    ymin -= 1;
  }

  // Gray reference/original background trace
  stroke(120, 120, 120, 120);
  strokeWeight(2);
  plotArray(data, left, top, w, h, pageStart, end, ymin, ymax);

  // Older EML approximations in faded red
  for (int k = 0; k < oldFits.size(); k++) {
    float alpha = map(k, 0, max(1, oldFits.size() - 1), 35, 110);
    stroke(255, 80, 80, alpha);
    strokeWeight(1);
    plotArray(oldFits.get(k), left, top, w, h, pageStart, end, ymin, ymax);
  }

  // Original data in blue points
  stroke(80, 150, 255);
  fill(80, 150, 255);
  strokeWeight(1);

  for (int i = pageStart; i < end; i++) {
    float sx = map(i, pageStart, end - 1, left, left + w);
    float sy = map(data[i], ymin, ymax, top + h, top);
    ellipse(sx, sy, 3, 3);
  }

  // Latest fit in red
  if (bestFit != null) {
    stroke(255, 60, 60);
    strokeWeight(3);
    noFill();
    plotArray(bestFit, left, top, w, h, pageStart, end, ymin, ymax);
  }

  strokeWeight(1);

  fill(200);
  textSize(13);
  text("Samples " + pageStart + " to " + (end - 1) + " of " + data.length, left, top + h + 25);
  text("Y range: " + nf(ymin, 1, 4) + " to " + nf(ymax, 1, 4), left + 280, top + h + 25);
}

void plotArray(float[] arr, int left, int top, int w, int h,
               int start, int end, float ymin, float ymax) {
  if (arr == null) return;

  noFill();
  beginShape();

  for (int i = start; i < end; i++) {
    float sx = map(i, start, end - 1, left, left + w);
    float sy = map(arr[i], ymin, ymax, top + h, top);
    vertex(sx, sy);
  }

  endShape();
}

void drawInfo() {
  int y = height - 110;

  fill(235);
  textSize(15);

  Stats s = computeStats(data, bestFit);

  text("generation: " + generation, 70, y);
  text("best MSE: " + nf(bestMSE, 1, 8), 230, y);
  text("MAE: " + nf(s.mae, 1, 8), 430, y);
  text("RMSE: " + nf(s.rmse, 1, 8), 570, y);
  text("PSNR: " + nf(s.psnr, 1, 3) + " dB", 720, y);
  text("max |err|: " + nf(s.maxAbsError, 1, 6), 880, y);

  y += 25;

  text("numToRead: " + numToRead, 70, y);
  text("visibleCount: " + visibleCount, 230, y);
  text("tree depth: " + maxDepth, 430, y);
  text("auto: " + autoEvolve, 570, y);

  y += 25;

  fill(180);
  text("r random curve | l load fp32 little-endian | e evolve | a auto | space evolve 100 | z/x zoom | [/] page | +/- samples | d/f depth | h clear history", 70, y);

  y += 25;

  if (bestTree != null) {
    fill(255, 210, 120);
    text("best tree: " + bestTree.toExprLimited(145), 70, y);
  }
}

// ------------------------------------------------------------
// Tree node
// ------------------------------------------------------------

class Node {
  String type;
  Node left;
  Node right;

  // affine parameters per node
  float a = 1;
  float b = 0;

  Node(String type) {
    this.type = type;
    randomParams();
  }

  Node(String type, Node left, Node right) {
    this.type = type;
    this.left = left;
    this.right = right;
    randomParams();
  }

  void randomParams() {
    a = random(-2, 2);
    b = random(-1, 1);
  }

  float eval(float x) {
    if (type.equals("x")) return x;
    if (type.equals("const")) return b;

    if (type.equals("eml")) {
      float lx = left.eval(x);
      float ry = right.eval(x);

      // Parametric hybrid EML:
      // eml(a*left+b, a*right+b)
      // The second branch is made positive inside eml().
      return eml(a * lx + b, a * ry + b);
    }

    return 0;
  }

  int size() {
    if (!type.equals("eml")) return 1;
    return 1 + left.size() + right.size();
  }

  Node copy() {
    Node n = new Node(type);
    n.a = a;
    n.b = b;

    if (left != null) n.left = left.copy();
    if (right != null) n.right = right.copy();

    return n;
  }

  void mutate(int depth) {
    float r = random(1);

    if (r < 0.25) {
      a += randomGaussian() * 0.25;
      b += randomGaussian() * 0.25;
    } else if (r < 0.45) {
      a = random(-2, 2);
      b = random(-1, 1);
    } else if (r < 0.65 && type.equals("eml")) {
      if (random(1) < 0.5) left = randomTree(max(1, depth - 1));
      else right = randomTree(max(1, depth - 1));
    } else if (r < 0.85 && type.equals("eml")) {
      if (random(1) < 0.5) left.mutate(depth - 1);
      else right.mutate(depth - 1);
    } else {
      Node repl = randomTree(depth);
      type = repl.type;
      left = repl.left;
      right = repl.right;
      a = repl.a;
      b = repl.b;
    }
  }

  String toExpr() {
    if (type.equals("x")) return "x";
    if (type.equals("const")) return nf(b, 1, 3);

    return "eml(" + left.toExpr() + ", " + right.toExpr() + ")";
  }

  String toExprLimited(int maxLen) {
    String s = toExpr();
    if (s.length() > maxLen) return s.substring(0, maxLen) + "...";
    return s;
  }
}

Node randomTree(int depth) {
  if (depth <= 0 || random(1) < 0.25) {
    if (random(1) < 0.7) return new Node("x");

    Node c = new Node("const");
    c.b = random(-1, 1);
    return c;
  }

  return new Node("eml", randomTree(depth - 1), randomTree(depth - 1));
}

// ------------------------------------------------------------
// Keys
// ------------------------------------------------------------

void keyPressed() {
  if (key == 'r') makeRandomCurve();

  if (key == 'l') {
    selectInput("Select little-endian fp32 binary file:", "fileSelected");
  }

  if (key == 'e') evolveOneGeneration();

  if (key == 'a') autoEvolve = !autoEvolve;

  if (key == ' ') {
    for (int i = 0; i < 100; i++) evolveOneGeneration();
  }

  if (key == 'h') oldFits.clear();

  if (key == 'z') {
    visibleCount = max(32, visibleCount / 2);
    pageStart = constrain(pageStart, 0, max(0, data.length - visibleCount));
  }

  if (key == 'x') {
    visibleCount = min(data.length, visibleCount * 2);
    pageStart = constrain(pageStart, 0, max(0, data.length - visibleCount));
  }

  if (key == '[') {
    pageStart -= visibleCount / 2;
    pageStart = max(0, pageStart);
  }

  if (key == ']') {
    pageStart += visibleCount / 2;
    pageStart = min(max(0, data.length - visibleCount), pageStart);
  }

  if (key == '-') {
    visibleCount = max(32, visibleCount - 128);
    pageStart = constrain(pageStart, 0, max(0, data.length - visibleCount));
  }

  if (key == '+') {
    visibleCount = min(data.length, visibleCount + 128);
    pageStart = constrain(pageStart, 0, max(0, data.length - visibleCount));
  }

  if (key == 'n') {
    numToRead = max(128, numToRead / 2);
    println("numToRead = " + numToRead);
  }

  if (key == 'm') {
    numToRead *= 2;
    println("numToRead = " + numToRead);
  }

  if (key == 'd') {
    maxDepth = max(1, maxDepth - 1);
    initPopulation();
  }

  if (key == 'f') {
    maxDepth = min(8, maxDepth + 1);
    initPopulation();
  }
}

void fileSelected(File selection) {
  loadFP32LittleEndian(selection);
}
