import java.util.*;

// ============================================================
// Interactive SSSP Visualizer
// - Dijkstra
// - Bellman-Ford Push
// - Bellman-Ford Pull
// - Chaotic
// ============================================================

final int MIN_NODES = 100;
final int MAX_NODES = 3000;
int nodeCount = 1000;

final int K_NEAREST = 4;
final int RANDOM_EDGES = 2;

final float TOP_BAR_H = 86;
final float LEGEND_H = 64;
final float WORLD_MARGIN = 30;

final int MODE_SINGLE = 0;
final int MODE_ALL = 1;

final int ALG_DIJKSTRA = 0;
final int ALG_PUSH = 1;
final int ALG_PULL = 2;
final int ALG_CHAOTIC = 3;

int viewMode = MODE_SINGLE;
int selectedAlgorithm = ALG_DIJKSTRA;

Node[] nodes;
ArrayList<Edge>[] outEdges;
ArrayList<Edge>[] inEdges;
ArrayList<Edge> allEdges = new ArrayList<Edge>();

int source = 0;
int target = 1;

boolean paused = false;
boolean pickingSource = false;
boolean pickingTarget = false;

int opsPerFrame = 35;

Runner[] runners = new Runner[4];
Button[] buttons;

// Colors
int NODE_BLUE;
int PATH_GREEN;
int CURRENT_ORANGE;
int IDLE_GRAY;
int FRONTIER_YELLOW;
int FRONTIER_DIJKSTRA;
int FRONTIER_PUSH;
int FRONTIER_PULL;
int FRONTIER_CHAOTIC;
int SOURCE_RING;
int TARGET_RING;

void settings() {
  size(1100, 700);
  smooth(4);
}

void setup() {
  textFont(createFont("Arial", 13));

  NODE_BLUE = color(60, 120, 255);
  PATH_GREEN = color(30, 200, 70);
  CURRENT_ORANGE = color(255, 140, 30);
  IDLE_GRAY = color(175);
  FRONTIER_YELLOW = color(255, 220, 40);

  FRONTIER_DIJKSTRA = color(255, 220, 40);
  FRONTIER_PUSH = color(255, 95, 95);
  FRONTIER_PULL = color(90, 220, 220);
  FRONTIER_CHAOTIC = color(210, 100, 255);

  SOURCE_RING = color(0, 180, 70);
  TARGET_RING = color(220, 40, 180);

  buildButtons();
  generateGraph();
  restartAlgorithms();
}

void draw() {
  background(240);

  if (!paused) {
    if (viewMode == MODE_SINGLE) {
      runners[selectedAlgorithm].stepMany(opsPerFrame);
    } else {
      for (int i = 0; i < 4; i++) {
        runners[i].stepMany(opsPerFrame);
      }
    }
  }

  drawTopBar();
  drawLegend();
  drawMainView();
}

void keyPressed() {
  if (key == ' ') paused = !paused;
}

void mousePressed() {
  if (handleButtons()) return;

  if (mouseY < TOP_BAR_H + LEGEND_H) return;

  int idx = findNearestNodeOnScreen(mouseX, mouseY, 12);
  if (idx < 0) return;

  if (pickingSource) {
    source = idx;
    if (source == target) target = (target + 1) % nodeCount;
    pickingSource = false;
    restartAlgorithms();
    return;
  }

  if (pickingTarget) {
    target = idx;
    if (target == source) source = (source + 1) % nodeCount;
    pickingTarget = false;
    restartAlgorithms();
    return;
  }
}

// ============================================================
// UI
// ============================================================

class Button {
  float x, y, w, h;
  String label;

  Button(float x, float y, float w, float h, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
  }

  boolean contains(float px, float py) {
    return px >= x && px <= x + w && py >= y && py <= y + h;
  }

  void draw(boolean active) {
    stroke(160);
    strokeWeight(1);
    if (active) fill(220, 235, 255);
    else fill(252);
    rect(x, y, w, h, 8);

    fill(0);
    textAlign(CENTER, CENTER);
    text(label, x + w / 2.0f, y + h / 2.0f);
  }
}

void buildButtons() {
  ArrayList<Button> list = new ArrayList<Button>();

  float x = 12;
  float y = 12;
  float h = 28;
  float gap = 8;

  list.add(new Button(x, y, 105, h, "Reset Graph")); x += 105 + gap;
  list.add(new Button(x, y, 42, h, "-N")); x += 42 + gap;
  list.add(new Button(x, y, 42, h, "+N")); x += 42 + gap;
  list.add(new Button(x, y, 95, h, "Pick Source")); x += 95 + gap;
  list.add(new Button(x, y, 95, h, "Pick Target")); x += 95 + gap;
  list.add(new Button(x, y, 85, h, "Dijkstra")); x += 85 + gap;
  list.add(new Button(x, y, 90, h, "BF Push")); x += 90 + gap;
  list.add(new Button(x, y, 90, h, "BF Pull")); x += 90 + gap;
  list.add(new Button(x, y, 115, h, "Chaotic")); x += 115 + gap;
  list.add(new Button(x, y, 70, h, "Run All")); x += 70 + gap;
  list.add(new Button(x, y, 95, h, "Pause/Run"));

  buttons = list.toArray(new Button[0]);
}

boolean handleButtons() {
  for (int i = 0; i < buttons.length; i++) {
    if (buttons[i].contains(mouseX, mouseY)) {
      onButton(i);
      return true;
    }
  }
  return false;
}

void onButton(int idx) {
  switch(idx) {
  case 0:
    generateGraph();
    restartAlgorithms();
    break;
  case 1:
    nodeCount = max(MIN_NODES, nodeCount - 100);
    generateGraph();
    restartAlgorithms();
    break;
  case 2:
    nodeCount = min(MAX_NODES, nodeCount + 100);
    generateGraph();
    restartAlgorithms();
    break;
  case 3:
    pickingSource = true;
    pickingTarget = false;
    break;
  case 4:
    pickingTarget = true;
    pickingSource = false;
    break;
  case 5:
    viewMode = MODE_SINGLE;
    selectedAlgorithm = ALG_DIJKSTRA;
    restartAlgorithms();
    break;
  case 6:
    viewMode = MODE_SINGLE;
    selectedAlgorithm = ALG_PUSH;
    restartAlgorithms();
    break;
  case 7:
    viewMode = MODE_SINGLE;
    selectedAlgorithm = ALG_PULL;
    restartAlgorithms();
    break;
  case 8:
    viewMode = MODE_SINGLE;
    selectedAlgorithm = ALG_CHAOTIC;
    restartAlgorithms();
    break;
  case 9:
    viewMode = MODE_ALL;
    restartAlgorithms();
    break;
  case 10:
    paused = !paused;
    break;
  }
}

void drawTopBar() {
  fill(255);
  noStroke();
  rect(0, 0, width, TOP_BAR_H);

  for (int i = 0; i < buttons.length; i++) {
    boolean active = false;

    if (i == 3 && pickingSource) active = true;
    if (i == 4 && pickingTarget) active = true;
    if (i == 5 && viewMode == MODE_SINGLE && selectedAlgorithm == ALG_DIJKSTRA) active = true;
    if (i == 6 && viewMode == MODE_SINGLE && selectedAlgorithm == ALG_PUSH) active = true;
    if (i == 7 && viewMode == MODE_SINGLE && selectedAlgorithm == ALG_PULL) active = true;
    if (i == 8 && viewMode == MODE_SINGLE && selectedAlgorithm == ALG_CHAOTIC) active = true;
    if (i == 9 && viewMode == MODE_ALL) active = true;
    if (i == 10 && paused) active = true;

    buttons[i].draw(active);
  }

  fill(0);
  textAlign(LEFT, TOP);
  textSize(14);
  String modeStr = (viewMode == MODE_ALL) ? "All algorithms" : algorithmName(selectedAlgorithm);
  text("Nodes: " + nodeCount + "   Source: " + source + "   Target: " + target + "   Mode: " + modeStr, 12, 48);

  textSize(12);
  String pickMsg = "";
  if (pickingSource) pickMsg = "Click a node to choose the source.";
  if (pickingTarget) pickMsg = "Click a node to choose the target.";
  text(pickMsg, 12, 66);
}

void drawLegend() {
  float y = TOP_BAR_H;
  fill(250);
  noStroke();
  rect(0, y, width, LEGEND_H);

  textAlign(LEFT, TOP);
  fill(0);
  textSize(13);
  text("Legend", 12, y + 8);

  float lx = 90;
  drawLegendDot(lx, y + 18, NODE_BLUE, "nodes"); lx += 120;
  drawLegendDot(lx, y + 18, CURRENT_ORANGE, "current node"); lx += 150;
  drawLegendDot(lx, y + 18, PATH_GREEN, "shortest path"); lx += 150;

  if (viewMode == MODE_SINGLE) {
    drawLegendDot(lx, y + 18, FRONTIER_YELLOW, "frontier");
  } else {
    drawLegendDot(lx, y + 18, FRONTIER_DIJKSTRA, "Dijkstra frontier"); lx += 165;
    drawLegendDot(lx, y + 18, FRONTIER_PUSH, "BF Push frontier"); lx += 150;
    drawLegendDot(lx, y + 18, FRONTIER_PULL, "BF Pull frontier"); lx += 150;
    drawLegendDot(lx, y + 18, FRONTIER_CHAOTIC, "Chaotic frontier");
  }

  fill(0);
  textAlign(LEFT, TOP);
  text("Source = green ring    Target = magenta ring", 12, y + 38);
}

void drawLegendDot(float x, float y, int c, String label) {
  noStroke();
  fill(c);
  ellipse(x, y, 12, 12);
  fill(0);
  textAlign(LEFT, CENTER);
  text(label, x + 12, y);
}

void drawMainView() {
  if (viewMode == MODE_SINGLE) {
    float x = 10;
    float y = TOP_BAR_H + LEGEND_H + 8;
    float w = width - 20;
    float h = height - y - 10;
    runners[selectedAlgorithm].drawPanel(x, y, w, h, true);
  } else {
    float pad = 10;
    float y0 = TOP_BAR_H + LEGEND_H + 8;
    float w = (width - 3 * pad) / 2.0f;
    float h = (height - y0 - 3 * pad) / 2.0f;

    runners[ALG_DIJKSTRA].drawPanel(pad, y0, w, h, false);
    runners[ALG_PUSH].drawPanel(2 * pad + w, y0, w, h, false);
    runners[ALG_PULL].drawPanel(pad, y0 + h + pad, w, h, false);
    runners[ALG_CHAOTIC].drawPanel(2 * pad + w, y0 + h + pad, w, h, false);
  }
}

// ============================================================
// Graph generation
// ============================================================

void generateGraph() {
  allEdges.clear();

  nodes = new Node[nodeCount];
  outEdges = (ArrayList<Edge>[]) new ArrayList[nodeCount];
  inEdges = (ArrayList<Edge>[]) new ArrayList[nodeCount];

  for (int i = 0; i < nodeCount; i++) {
    outEdges[i] = new ArrayList<Edge>();
    inEdges[i] = new ArrayList<Edge>();
  }

  nodes[0] = new Node(WORLD_MARGIN, TOP_BAR_H + LEGEND_H + 20);
  nodes[nodeCount - 1] = new Node(width - WORLD_MARGIN, height - WORLD_MARGIN);

  for (int i = 1; i < nodeCount - 1; i++) {
    float x = random(WORLD_MARGIN + 10, width - WORLD_MARGIN - 10);
    float y = random(TOP_BAR_H + LEGEND_H + 30, height - WORLD_MARGIN - 10);
    nodes[i] = new Node(x, y);
  }

  source = 0;
  target = max(1, nodeCount - 1);

  for (int i = 0; i < nodeCount; i++) {
    int[] near = kNearest(i, K_NEAREST);
    for (int j = 0; j < near.length; j++) {
      int v = near[j];
      if (v >= 0 && v != i) {
        addDirectedEdge(i, v, randomWeight());
        addDirectedEdge(v, i, randomWeight());
      }
    }
  }

  for (int i = 0; i < nodeCount; i++) {
    for (int r = 0; r < RANDOM_EDGES; r++) {
      int v = (int)random(nodeCount);
      if (v != i) addDirectedEdge(i, v, randomWeight());
    }
  }

  int[] nearS = kNearest(source, 10);
  for (int i = 0; i < nearS.length; i++) {
    int v = nearS[i];
    if (v >= 0 && v != source) addDirectedEdge(source, v, randomWeight());
  }

  int[] nearT = kNearest(target, 10);
  for (int i = 0; i < nearT.length; i++) {
    int v = nearT[i];
    if (v >= 0 && v != target) addDirectedEdge(v, target, randomWeight());
  }
}

int[] kNearest(int idx, int k) {
  float[] bestD = new float[k];
  int[] bestI = new int[k];

  for (int i = 0; i < k; i++) {
    bestD[i] = Float.MAX_VALUE;
    bestI[i] = -1;
  }

  Node a = nodes[idx];

  for (int j = 0; j < nodeCount; j++) {
    if (j == idx) continue;

    Node b = nodes[j];
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    float d2 = dx * dx + dy * dy;

    int worst = 0;
    for (int t = 1; t < k; t++) {
      if (bestD[t] > bestD[worst]) worst = t;
    }

    if (d2 < bestD[worst]) {
      bestD[worst] = d2;
      bestI[worst] = j;
    }
  }

  return bestI;
}

void addDirectedEdge(int u, int v, int w) {
  for (int i = 0; i < outEdges[u].size(); i++) {
    Edge e = outEdges[u].get(i);
    if (e.dst == v) return;
  }

  Edge e = new Edge(u, v, w);
  outEdges[u].add(e);
  inEdges[v].add(e);
  allEdges.add(e);
}

int randomWeight() {
  if (random(1) < 0.5f) return 1;
  return 1 + (int)random(10);
}

// ============================================================
// Algorithms
// ============================================================

void restartAlgorithms() {
  runners[ALG_DIJKSTRA] = new Runner(ALG_DIJKSTRA);
  runners[ALG_PUSH] = new Runner(ALG_PUSH);
  runners[ALG_PULL] = new Runner(ALG_PULL);
  runners[ALG_CHAOTIC] = new Runner(ALG_CHAOTIC);
}

String algorithmName(int alg) {
  if (alg == ALG_DIJKSTRA) return "Dijkstra";
  if (alg == ALG_PUSH) return "Bellman-Ford Push";
  if (alg == ALG_PULL) return "Bellman-Ford Pull";
  return "Chaotic";
}

int frontierColorFor(int alg, boolean singleMode) {
  if (singleMode) return FRONTIER_YELLOW;
  if (alg == ALG_DIJKSTRA) return FRONTIER_DIJKSTRA;
  if (alg == ALG_PUSH) return FRONTIER_PUSH;
  if (alg == ALG_PULL) return FRONTIER_PULL;
  return FRONTIER_CHAOTIC;
}

class Runner {
  int alg;
  String name;
  boolean finished;
  String status;
  long steps;

  float[] dist;
  int[] parent;
  boolean[] frontier;
  int current;

  PriorityQueue<PQItem> pq;
  boolean[] inPQ;
  boolean[] settled;

  int pushVertex;
  int pushPass;
  boolean[] pushNextFrontier;
  boolean pushChangedAny;

  int pullVertex;
  int pullPass;
  boolean[] pullNextFrontier;
  boolean pullChangedAny;

  ArrayDeque<Integer> q;
  boolean[] inQueue;

  Runner(int alg) {
    this.alg = alg;
    this.name = algorithmName(alg);
    this.finished = false;
    this.status = "running";
    this.steps = 0;
    this.current = -1;

    dist = new float[nodeCount];
    parent = new int[nodeCount];
    frontier = new boolean[nodeCount];

    for (int i = 0; i < nodeCount; i++) {
      dist[i] = Float.POSITIVE_INFINITY;
      parent[i] = -1;
      frontier[i] = false;
    }
    dist[source] = 0;
    frontier[source] = true;

    if (alg == ALG_DIJKSTRA) {
      pq = new PriorityQueue<PQItem>();
      inPQ = new boolean[nodeCount];
      settled = new boolean[nodeCount];
      pq.add(new PQItem(source, 0));
      inPQ[source] = true;
    } else if (alg == ALG_PUSH) {
      pushVertex = 0;
      pushPass = 0;
      pushNextFrontier = new boolean[nodeCount];
      pushChangedAny = false;
    } else if (alg == ALG_PULL) {
      pullVertex = 0;
      pullPass = 0;
      pullNextFrontier = new boolean[nodeCount];
      pullChangedAny = false;
    } else if (alg == ALG_CHAOTIC) {
      q = new ArrayDeque<Integer>();
      inQueue = new boolean[nodeCount];
      q.add(source);
      inQueue[source] = true;
      frontier[source] = true;
    }
  }

  void stepMany(int count) {
    if (finished) return;
    for (int i = 0; i < count; i++) {
      if (!stepOne()) {
        finished = true;
        break;
      }
    }
  }

  boolean stepOne() {
    steps++;
    if (alg == ALG_DIJKSTRA) return stepDijkstra();
    if (alg == ALG_PUSH) return stepPush();
    if (alg == ALG_PULL) return stepPull();
    return stepChaotic();
  }

  boolean stepDijkstra() {
    while (!pq.isEmpty()) {
      PQItem item = pq.poll();
      int u = item.v;
      inPQ[u] = false;

      if (settled[u]) continue;
      if (item.dist > dist[u]) continue;

      settled[u] = true;
      current = u;

      for (int i = 0; i < outEdges[u].size(); i++) {
        Edge e = outEdges[u].get(i);
        int v = e.dst;
        float nd = dist[u] + e.w;
        if (nd < dist[v]) {
          dist[v] = nd;
          parent[v] = u;
          pq.add(new PQItem(v, nd));
          inPQ[v] = true;
        }
      }

      Arrays.fill(frontier, false);
      for (int i = 0; i < nodeCount; i++) {
        frontier[i] = inPQ[i] && !settled[i];
      }

      status = "processing PQ";
      if (u == target) {
        status = "finished";
        return false;
      }
      return true;
    }

    status = "finished";
    return false;
  }

  boolean stepPush() {
    if (pushPass >= nodeCount - 1) {
      status = "finished";
      return false;
    }

    current = pushVertex;

    if (dist[current] < Float.POSITIVE_INFINITY) {
      for (int i = 0; i < outEdges[current].size(); i++) {
        Edge e = outEdges[current].get(i);
        int v = e.dst;
        float nd = dist[current] + e.w;
        if (nd < dist[v]) {
          dist[v] = nd;
          parent[v] = current;
          pushNextFrontier[v] = true;
          pushChangedAny = true;
        }
      }
    }

    pushVertex++;

    if (pushVertex >= nodeCount) {
      pushVertex = 0;
      pushPass++;

      boolean[] tmp = frontier;
      frontier = pushNextFrontier;
      pushNextFrontier = tmp;
      Arrays.fill(pushNextFrontier, false);

      if (!pushChangedAny) {
        status = "finished early";
        return false;
      }
      pushChangedAny = false;
    }

    status = "pass " + pushPass;
    return true;
  }

  boolean stepPull() {
    if (pullPass >= nodeCount - 1) {
      status = "finished";
      return false;
    }

    current = pullVertex;

    float best = dist[current];
    int bestParent = parent[current];

    for (int i = 0; i < inEdges[current].size(); i++) {
      Edge e = inEdges[current].get(i);
      int u = e.src;
      if (dist[u] < Float.POSITIVE_INFINITY) {
        float nd = dist[u] + e.w;
        if (nd < best) {
          best = nd;
          bestParent = u;
        }
      }
    }

    if (best < dist[current]) {
      dist[current] = best;
      parent[current] = bestParent;
      pullNextFrontier[current] = true;
      pullChangedAny = true;
    }

    pullVertex++;

    if (pullVertex >= nodeCount) {
      pullVertex = 0;
      pullPass++;

      boolean[] tmp = frontier;
      frontier = pullNextFrontier;
      pullNextFrontier = tmp;
      Arrays.fill(pullNextFrontier, false);

      if (!pullChangedAny) {
        status = "finished early";
        return false;
      }
      pullChangedAny = false;
    }

    status = "pass " + pullPass;
    return true;
  }

  boolean stepChaotic() {
    if (q.isEmpty()) {
      status = "finished";
      return false;
    }

    current = q.poll();
    inQueue[current] = false;
    frontier[current] = false;

    if (dist[current] < Float.POSITIVE_INFINITY) {
      for (int i = 0; i < outEdges[current].size(); i++) {
        Edge e = outEdges[current].get(i);
        int v = e.dst;
        float nd = dist[current] + e.w;
        if (nd < dist[v]) {
          dist[v] = nd;
          parent[v] = current;
          if (!inQueue[v]) {
            q.add(v);
            inQueue[v] = true;
            frontier[v] = true;
          }
        }
      }
    }

    status = "queue size " + q.size();
    return true;
  }

  void drawPanel(float x, float y, float w, float h, boolean singleMode) {
    fill(252);
    stroke(170);
    strokeWeight(1);
    rect(x, y, w, h, 14);

    float headerH = 60;
    fill(247);
    noStroke();
    rect(x + 1, y + 1, w - 2, headerH, 14, 14, 0, 0);

    fill(0);
    textAlign(LEFT, TOP);
    textSize(18);
    text(name, x + 12, y + 10);

    textSize(12);
    String td = finite(dist[target]) ? nf(dist[target], 0, 0) : "INF";
    text("status: " + status + "   steps: " + steps + "   target dist: " + td, x + 12, y + 34);

    float gx = x + 8;
    float gy = y + headerH + 8;
    float gw = w - 16;
    float gh = h - headerH - 16;

    drawGraphView(gx, gy, gw, gh, singleMode);
  }

  void drawGraphView(float x, float y, float w, float h, boolean singleMode) {
    float minX = WORLD_MARGIN;
    float maxX = width - WORLD_MARGIN;
    float minY = TOP_BAR_H + LEGEND_H + 20;
    float maxY = height - WORLD_MARGIN;

    float sx = w / max(1.0f, maxX - minX);
    float sy = h / max(1.0f, maxY - minY);

    stroke(100, 100, 120, 18);
    strokeWeight(1);
    for (int i = 0; i < allEdges.size(); i++) {
      Edge e = allEdges.get(i);
      Node a = nodes[e.src];
      Node b = nodes[e.dst];
      float x1 = x + (a.x - minX) * sx;
      float y1 = y + (a.y - minY) * sy;
      float x2 = x + (b.x - minX) * sx;
      float y2 = y + (b.y - minY) * sy;
      line(x1, y1, x2, y2);
    }

    if (finite(dist[target])) {
      ArrayList<Integer> path = reconstructPath(target);
      if (path.size() >= 2) {
        stroke(PATH_GREEN);
        strokeWeight(4);
        noFill();
        beginShape();
        for (int i = 0; i < path.size(); i++) {
          int idx = path.get(i);
          Node n = nodes[idx];
          vertex(x + (n.x - minX) * sx, y + (n.y - minY) * sy);
        }
        endShape();
      }
    }

    noStroke();
    int fColor = frontierColorFor(alg, singleMode);

    for (int i = 0; i < nodeCount; i++) {
      Node n = nodes[i];
      float px = x + (n.x - minX) * sx;
      float py = y + (n.y - minY) * sy;

      float r = 4.5f;
      int c = finite(dist[i]) ? NODE_BLUE : IDLE_GRAY;

      if (frontier[i]) {
        c = fColor;
        r = 6.8f;
      }

      if (i == current) {
        c = CURRENT_ORANGE;
        r = 7.8f;
      }

      fill(c);
      ellipse(px, py, r, r);
    }

    if (finite(dist[target])) {
      ArrayList<Integer> path = reconstructPath(target);
      for (int i = 0; i < path.size(); i++) {
        int idx = path.get(i);
        if (frontier[idx]) {
          Node n = nodes[idx];
          float px = x + (n.x - minX) * sx;
          float py = y + (n.y - minY) * sy;
          fill(fColor);
          ellipse(px, py, 10, 10);
        }
      }
    }

    drawRingAtNode(x, y, sx, sy, minX, minY, source, SOURCE_RING, 14);
    drawRingAtNode(x, y, sx, sy, minX, minY, target, TARGET_RING, 14);
  }

  void drawRingAtNode(float x, float y, float sx, float sy, float minX, float minY, int idx, int c, float d) {
    Node n = nodes[idx];
    float px = x + (n.x - minX) * sx;
    float py = y + (n.y - minY) * sy;
    noFill();
    stroke(c);
    strokeWeight(2.4f);
    ellipse(px, py, d, d);
  }

  ArrayList<Integer> reconstructPath(int v) {
    ArrayList<Integer> rev = new ArrayList<Integer>();
    int guard = 0;
    while (v != -1 && guard <= nodeCount) {
      rev.add(v);
      if (v == source) break;
      v = parent[v];
      guard++;
    }
    Collections.reverse(rev);
    if (rev.size() == 0 || rev.get(0) != source) rev.clear();
    return rev;
  }
}

// ============================================================
// Picking helpers
// ============================================================

int findNearestNodeOnScreen(float mx, float my, float radius) {
  if (viewMode == MODE_SINGLE) {
    float x = 10 + 8;
    float y = TOP_BAR_H + LEGEND_H + 8 + 60 + 8;
    float w = width - 20 - 16;
    float h = height - (TOP_BAR_H + LEGEND_H + 8) - 10 - 60 - 16;
    return findNearestNodeInRect(mx, my, x, y, w, h, radius);
  } else {
    float pad = 10;
    float y0 = TOP_BAR_H + LEGEND_H + 8;
    float w = (width - 3 * pad) / 2.0f;
    float h = (height - y0 - 3 * pad) / 2.0f;

    int idx;

    idx = findNearestNodeInRect(mx, my, pad + 8, y0 + 60 + 8, w - 16, h - 76, radius);
    if (idx >= 0) return idx;

    idx = findNearestNodeInRect(mx, my, 2 * pad + w + 8, y0 + 60 + 8, w - 16, h - 76, radius);
    if (idx >= 0) return idx;

    idx = findNearestNodeInRect(mx, my, pad + 8, y0 + h + pad + 60 + 8, w - 16, h - 76, radius);
    if (idx >= 0) return idx;

    idx = findNearestNodeInRect(mx, my, 2 * pad + w + 8, y0 + h + pad + 60 + 8, w - 16, h - 76, radius);
    if (idx >= 0) return idx;
  }

  return -1;
}

int findNearestNodeInRect(float mx, float my, float x, float y, float w, float h, float radius) {
  float minX = WORLD_MARGIN;
  float maxX = width - WORLD_MARGIN;
  float minY = TOP_BAR_H + LEGEND_H + 20;
  float maxY = height - WORLD_MARGIN;

  float sx = w / max(1.0f, maxX - minX);
  float sy = h / max(1.0f, maxY - minY);

  int bestIdx = -1;
  float bestD2 = radius * radius;

  for (int i = 0; i < nodeCount; i++) {
    float px = x + (nodes[i].x - minX) * sx;
    float py = y + (nodes[i].y - minY) * sy;
    float dx = mx - px;
    float dy = my - py;
    float d2 = dx * dx + dy * dy;
    if (d2 < bestD2) {
      bestD2 = d2;
      bestIdx = i;
    }
  }

  return bestIdx;
}

// ============================================================
// Small helpers
// ============================================================

boolean finite(float x) {
  return x < Float.POSITIVE_INFINITY / 2.0f;
}

class Node {
  float x;
  float y;

  Node(float x, float y) {
    this.x = x;
    this.y = y;
  }
}

class Edge {
  int src;
  int dst;
  int w;

  Edge(int src, int dst, int w) {
    this.src = src;
    this.dst = dst;
    this.w = w;
  }
}

class PQItem implements Comparable<PQItem> {
  int v;
  float dist;

  PQItem(int v, float dist) {
    this.v = v;
    this.dist = dist;
  }

  public int compareTo(PQItem other) {
    if (this.dist < other.dist) return -1;
    if (this.dist > other.dist) return 1;
    return 0;
  }
}
