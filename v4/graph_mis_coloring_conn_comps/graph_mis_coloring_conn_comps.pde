// Graph Algorithms Visualizer in Processing
// Shows:
// 1) MIS (Maximal Independent Set)
// 2) Graph Coloring
// 3) Connected Components
//
// Controls:
//   1 = MIS
//   2 = Coloring
//   3 = Connected Components
//   SPACE = single step
//   a = toggle auto-run
//   r = regenerate graph
//   c = reset current algorithm
//
// Works in Processing Java mode.

final int MODE_MIS = 0;
final int MODE_COLORING = 1;
final int MODE_COMPONENTS = 2;

int mode = MODE_MIS;

int n = 28;
float edgeRadius = 135;

ArrayList<Node> nodes = new ArrayList<Node>();
ArrayList<Edge> edges = new ArrayList<Edge>();

boolean autoRun = true;
int stepDelay = 25;
int lastStepFrame = 0;

// ---------- MIS state ----------
boolean misDone = false;
ArrayList<Integer> misOrder = new ArrayList<Integer>();
int misIndex = 0;

// node.state for MIS:
// 0 = undecided
// 1 = in MIS
// 2 = excluded

// ---------- Coloring state ----------
boolean coloringDone = false;
int coloringIndex = 0;
int[] palette;

// node.colorId for coloring:
// -1 = uncolored
// 0..k = palette index

// ---------- Connected components state ----------
boolean ccDone = false;
int ccSeedIndex = 0;
ArrayList<Integer> ccQueue = new ArrayList<Integer>();
int currentComponent = -1;

// node.componentId:
// -1 = unassigned
// 0..k = component ID

void setup() {
  size(1200, 820);
  smooth(8);
  textFont(createFont("Arial", 16));
  palette = new int[] {
    color(231, 76, 60),
    color(52, 152, 219),
    color(46, 204, 113),
    color(241, 196, 15),
    color(155, 89, 182),
    color(26, 188, 156),
    color(230, 126, 34),
    color(149, 165, 166),
    color(243, 156, 18),
    color(127, 140, 141),
    color(192, 57, 43),
    color(41, 128, 185),
    color(39, 174, 96),
    color(142, 68, 173)
  };
  generateGraph();
  resetAllAlgorithms();
}

void draw() {
  background(248);

  if (autoRun && frameCount - lastStepFrame >= stepDelay) {
    stepAlgorithm();
    lastStepFrame = frameCount;
  }

  drawEdges();
  drawNodes();
  drawHUD();
}

// ======================================================
// Graph generation
// ======================================================

void generateGraph() {
  nodes.clear();
  edges.clear();

  // Place nodes with a little spacing
  int attemptsLimit = 5000;
  for (int i = 0; i < n; i++) {
    boolean placed = false;
    int attempts = 0;
    while (!placed && attempts < attemptsLimit) {
      float x = random(70, width - 70);
      float y = random(90, height - 110);

      boolean ok = true;
      for (Node other : nodes) {
        if (dist(x, y, other.x, other.y) < 48) {
          ok = false;
          break;
        }
      }

      if (ok) {
        nodes.add(new Node(i, x, y));
        placed = true;
      }
      attempts++;
    }

    // fallback if spacing gets hard
    if (!placed) {
      nodes.add(new Node(i, random(70, width - 70), random(90, height - 110)));
    }
  }

  // Build a random geometric graph
  for (int i = 0; i < nodes.size(); i++) {
    for (int j = i + 1; j < nodes.size(); j++) {
      Node a = nodes.get(i);
      Node b = nodes.get(j);
      float d = dist(a.x, a.y, b.x, b.y);

      if (d < edgeRadius) {
        a.neighbors.add(j);
        b.neighbors.add(i);
        edges.add(new Edge(i, j));
      }
    }
  }

  // Make sure graph isn't too sparse: add a few random extra edges if needed
  int minEdges = n;
  int tries = 0;
  while (edges.size() < minEdges && tries < 5000) {
    int i = int(random(n));
    int j = int(random(n));
    if (i != j && !areNeighbors(i, j)) {
      Node a = nodes.get(i);
      Node b = nodes.get(j);
      a.neighbors.add(j);
      b.neighbors.add(i);
      edges.add(new Edge(i, j));
    }
    tries++;
  }
}

boolean areNeighbors(int i, int j) {
  Node a = nodes.get(i);
  for (int nb : a.neighbors) {
    if (nb == j) return true;
  }
  return false;
}

// ======================================================
// Reset / mode handling
// ======================================================

void resetAllAlgorithms() {
  resetMIS();
  resetColoring();
  resetComponents();
}

void resetMIS() {
  misDone = false;
  misOrder.clear();
  for (Node v : nodes) {
    v.state = 0;
    misOrder.add(v.id);
  }
  shuffleList(misOrder);
  misIndex = 0;
}

void resetColoring() {
  coloringDone = false;
  coloringIndex = 0;
  for (Node v : nodes) {
    v.colorId = -1;
  }
}

void resetComponents() {
  ccDone = false;
  ccSeedIndex = 0;
  currentComponent = -1;
  ccQueue.clear();
  for (Node v : nodes) {
    v.componentId = -1;
  }
}

void resetCurrentMode() {
  if (mode == MODE_MIS) resetMIS();
  else if (mode == MODE_COLORING) resetColoring();
  else if (mode == MODE_COMPONENTS) resetComponents();
}

// ======================================================
// Algorithm steps
// ======================================================

void stepAlgorithm() {
  if (mode == MODE_MIS) stepMIS();
  else if (mode == MODE_COLORING) stepColoring();
  else if (mode == MODE_COMPONENTS) stepComponents();
}

// ---------- MIS ----------
// Simple greedy maximal independent set:
//
// Traverse nodes in random order.
// If a node is still undecided and none of its neighbors are already in MIS,
// put it in MIS and exclude all its neighbors.
// Otherwise exclude it if needed.
void stepMIS() {
  if (misDone) return;

  while (misIndex < misOrder.size()) {
    int vid = misOrder.get(misIndex);
    misIndex++;

    Node v = nodes.get(vid);
    if (v.state != 0) continue;

    boolean hasMISNeighbor = false;
    for (int nb : v.neighbors) {
      if (nodes.get(nb).state == 1) {
        hasMISNeighbor = true;
        break;
      }
    }

    if (!hasMISNeighbor) {
      v.state = 1; // in MIS
      for (int nb : v.neighbors) {
        Node u = nodes.get(nb);
        if (u.state == 0) u.state = 2; // excluded
      }
    } else {
      v.state = 2;
    }
    return;
  }

  misDone = true;
}

// ---------- Coloring ----------
// Greedy coloring:
//
// Visit vertices in ID order.
// Give each vertex the smallest color not used by its neighbors.
void stepColoring() {
  if (coloringDone) return;

  while (coloringIndex < nodes.size()) {
    Node v = nodes.get(coloringIndex);

    if (v.colorId == -1) {
      boolean[] used = new boolean[palette.length];

      for (int nb : v.neighbors) {
        int c = nodes.get(nb).colorId;
        if (c >= 0 && c < used.length) used[c] = true;
      }

      int chosen = 0;
      while (chosen < used.length && used[chosen]) chosen++;

      // if palette overflows, wrap visually, though graph should usually fit
      if (chosen >= palette.length) chosen = palette.length - 1;

      v.colorId = chosen;
      coloringIndex++;
      return;
    } else {
      coloringIndex++;
    }
  }

  coloringDone = true;
}

// ---------- Connected Components ----------
// Breadth-first exploration one node at a time.
void stepComponents() {
  if (ccDone) return;

  // If queue has work, expand one node
  if (ccQueue.size() > 0) {
    int vid = ccQueue.remove(0);
    Node v = nodes.get(vid);

    for (int nb : v.neighbors) {
      Node u = nodes.get(nb);
      if (u.componentId == -1) {
        u.componentId = currentComponent;
        ccQueue.add(nb);
      }
    }
    return;
  }

  // Start a new component from next unassigned node
  while (ccSeedIndex < nodes.size()) {
    Node seed = nodes.get(ccSeedIndex);
    ccSeedIndex++;

    if (seed.componentId == -1) {
      currentComponent++;
      seed.componentId = currentComponent;
      ccQueue.add(seed.id);
      return;
    }
  }

  ccDone = true;
}

// ======================================================
// Drawing
// ======================================================

void drawEdges() {
  strokeWeight(2);

  for (Edge e : edges) {
    Node a = nodes.get(e.a);
    Node b = nodes.get(e.b);

    if (mode == MODE_MIS) {
      if (a.state == 1 && b.state == 1) {
        stroke(220, 60, 60); // should not happen in a correct MIS
      } else if (a.state == 1 || b.state == 1) {
        stroke(130, 170, 130);
      } else {
        stroke(190);
      }
    } else if (mode == MODE_COLORING) {
      if (a.colorId >= 0 && a.colorId == b.colorId) {
        stroke(220, 60, 60); // conflict edge
      } else {
        stroke(180);
      }
    } else if (mode == MODE_COMPONENTS) {
      if (a.componentId >= 0 && a.componentId == b.componentId) {
        stroke(colorForComponent(a.componentId), 170);
      } else {
        stroke(190);
      }
    }

    line(a.x, a.y, b.x, b.y);
  }
}

void drawNodes() {
  textAlign(CENTER, CENTER);

  for (Node v : nodes) {
    strokeWeight(2);

    if (mode == MODE_MIS) {
      if (v.state == 0) {
        fill(255);
        stroke(120);
      } else if (v.state == 1) {
        fill(60, 190, 90);
        stroke(30, 120, 50);
      } else {
        fill(220);
        stroke(140);
      }
    } else if (mode == MODE_COLORING) {
      if (v.colorId == -1) {
        fill(255);
        stroke(120);
      } else {
        fill(palette[v.colorId]);
        stroke(60);
      }
    } else if (mode == MODE_COMPONENTS) {
      if (v.componentId == -1) {
        fill(255);
        stroke(120);
      } else {
        fill(colorForComponent(v.componentId));
        stroke(60);
      }
    }

    ellipse(v.x, v.y, 34, 34);
    fill(20);
    text(v.id, v.x, v.y);
  }
}

void drawHUD() {
  fill(20);
  textAlign(LEFT, TOP);
  textSize(24);

  String title = "";
  String subtitle = "";

  if (mode == MODE_MIS) {
    title = "MIS (Maximal Independent Set)";
    subtitle = "Greedy rule: pick an undecided vertex if none of its neighbors are already in the set.";
  } else if (mode == MODE_COLORING) {
    title = "Graph Coloring";
    subtitle = "Greedy coloring: each vertex gets the smallest color not used by its neighbors.";
  } else if (mode == MODE_COMPONENTS) {
    title = "Connected Components";
    subtitle = "Breadth-first expansion labels one component at a time.";
  }

  text(title, 20, 16);
  textSize(14);
  fill(60);
  text(subtitle, 20, 50);

  String status = algorithmStatus();
  text("Status: " + status, 20, height - 86);

  String controls =
    "Controls: 1=MIS   2=Coloring   3=Connected Components   SPACE=step   a=auto   c=reset current   r=new graph";
  text(controls, 20, height - 62);

  String graphInfo = "Vertices: " + nodes.size() + "    Edges: " + edges.size() + "    Auto-run: " + (autoRun ? "ON" : "OFF");
  text(graphInfo, 20, height - 38);

  drawLegend();
}

void drawLegend() {
  float x = width - 310;
  float y = 18;

  fill(255, 250);
  stroke(180);
  rect(x, y, 285, 120, 10);

  fill(20);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Legend", x + 12, y + 10);

  if (mode == MODE_MIS) {
    drawLegendItem(x + 16, y + 38, color(60, 190, 90), "In MIS");
    drawLegendItem(x + 16, y + 66, color(220), "Excluded");
    drawLegendItem(x + 16, y + 94, color(255), "Undecided");
  } else if (mode == MODE_COLORING) {
    drawLegendItem(x + 16, y + 38, palette[0], "Assigned color");
    drawLegendItem(x + 16, y + 66, color(255), "Uncolored");
    fill(60);
    text("Red edge means coloring conflict", x + 42, y + 90);
  } else if (mode == MODE_COMPONENTS) {
    drawLegendItem(x + 16, y + 38, colorForComponent(0), "One component");
    drawLegendItem(x + 16, y + 66, colorForComponent(1), "Another component");
    drawLegendItem(x + 16, y + 94, color(255), "Unassigned");
  }
}

void drawLegendItem(float x, float y, int c, String label) {
  stroke(90);
  fill(c);
  ellipse(x, y, 18, 18);
  fill(40);
  text(label, x + 20, y - 8);
}

String algorithmStatus() {
  if (mode == MODE_MIS) {
    int inCount = 0;
    int exCount = 0;
    int unCount = 0;
    for (Node v : nodes) {
      if (v.state == 1) inCount++;
      else if (v.state == 2) exCount++;
      else unCount++;
    }
    return "MIS vertices = " + inCount + ", excluded = " + exCount + ", undecided = " + unCount +
           (misDone ? "   [DONE]" : "");
  }

  if (mode == MODE_COLORING) {
    int colored = 0;
    int maxColor = -1;
    for (Node v : nodes) {
      if (v.colorId >= 0) {
        colored++;
        maxColor = max(maxColor, v.colorId);
      }
    }
    return "Colored vertices = " + colored + "/" + nodes.size() +
           ", colors used = " + (maxColor + 1) +
           (coloringDone ? "   [DONE]" : "");
  }

  int assigned = 0;
  int maxComp = -1;
  for (Node v : nodes) {
    if (v.componentId >= 0) {
      assigned++;
      maxComp = max(maxComp, v.componentId);
    }
  }
  return "Assigned vertices = " + assigned + "/" + nodes.size() +
         ", components found = " + (maxComp + 1) +
         (ccDone ? "   [DONE]" : "");
}

// ======================================================
// Utilities
// ======================================================

void shuffleList(ArrayList<Integer> list) {
  for (int i = list.size() - 1; i > 0; i--) {
    int j = int(random(i + 1));
    int tmp = list.get(i);
    list.set(i, list.get(j));
    list.set(j, tmp);
  }
}

int colorForComponent(int c) {
  return palette[c % palette.length];
}

// ======================================================
// Input
// ======================================================

void keyPressed() {
  if (key == '1') {
    mode = MODE_MIS;
  } else if (key == '2') {
    mode = MODE_COLORING;
  } else if (key == '3') {
    mode = MODE_COMPONENTS;
  } else if (key == 'a' || key == 'A') {
    autoRun = !autoRun;
  } else if (key == 'r' || key == 'R') {
    generateGraph();
    resetAllAlgorithms();
  } else if (key == 'c' || key == 'C') {
    resetCurrentMode();
  } else if (key == ' ') {
    stepAlgorithm();
  }
}

// ======================================================
// Classes
// ======================================================

class Node {
  int id;
  float x, y;
  ArrayList<Integer> neighbors = new ArrayList<Integer>();

  // MIS
  int state = 0;

  // Coloring
  int colorId = -1;

  // Connected Components
  int componentId = -1;

  Node(int id, float x, float y) {
    this.id = id;
    this.x = x;
    this.y = y;
  }
}

class Edge {
  int a, b;
  Edge(int a, int b) {
    this.a = a;
    this.b = b;
  }
}
