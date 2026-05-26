// Processing (Java mode)
// Visual MIS demo: greedy maximal independent set (MIS)
// Green = in MIS, Red = excluded by neighbors, Gray = undecided
// Controls: g=go (full), n=next step, a=auto, r=randomize graph, c=clear states, 1..5=density

import java.util.Collections; // put at the top of the sketch

// ---------------- Config ----------------
int N = 18;                 // number of nodes
float R = 240;              // layout radius
int densityLevel = 3;       // 1..5 (edge probability)
int stepDelayMs = 400;      // auto-step delay

// ---------------- State -----------------
ArrayList<Node> nodes = new ArrayList<>();
boolean[][] adj;            // adjacency matrix
ArrayList<Integer> order = new ArrayList<>(); // node processing order
int cursor = 0;             // where we are in order[]
boolean autoPlay = false;
PFont f;

// Node states
final int UNDECIDED = 0;
final int IN_MIS = 1;
final int EXCLUDED = 2;

// ---------------- Setup -----------------
void setup() {
  size(900, 700);
  smooth(8);
  f = createFont("Menlo", 14, true);
  textFont(f);
  buildGraph();
}

// Build circular layout + random edges
void buildGraph() {
  nodes.clear();
  adj = new boolean[N][N];
  float cx = width*0.32, cy = height*0.52;

  // place nodes roughly on a circle with small jitter
  for (int i=0; i<N; i++) {
    float ang = TWO_PI * i / N;
    float jitter = 22;
    float x = cx + R*cos(ang) + random(-jitter, jitter);
    float y = cy + R*sin(ang) + random(-jitter, jitter);
    nodes.add(new Node(i, x, y));
  }

  // random edges by probability derived from densityLevel
  float p = map(densityLevel, 1, 5, 0.06, 0.35);
  for (int i=0; i<N; i++) {
    for (int j=i+1; j<N; j++) {
      if (random(1) < p) {
        adj[i][j] = adj[j][i] = true;
      }
    }
  }

  // precompute neighbor lists
  for (int i=0; i<N; i++) {
    nodes.get(i).neighbors.clear();
    for (int j=0; j<N; j++) if (adj[i][j]) {
      nodes.get(i).neighbors.add(j);
    }
  }

  clearStates();
  computeProcessingOrder();
}

void clearStates() {
  for (Node nd : nodes) nd.state = UNDECIDED;
  cursor = 0;
  autoPlay = false;
}

// simple processing order: ascending degree, then id (greedy heuristic)


void computeProcessingOrder() {
  order.clear();
  for (int i = 0; i < N; i++) order.add(i);

  // Sort by (degree asc, then id asc)
  Collections.sort(order, new java.util.Comparator<Integer>() {
    public int compare(Integer a, Integer b) {
      int da = nodes.get(a).neighbors.size();
      int db = nodes.get(b).neighbors.size();
      if (da != db) return da - db;
      return a - b;
    }
  });
}

// ---------------- Draw -----------------
void draw() {
  background(252);
  drawPanel();
  drawEdges();
  drawNodes();

  if (autoPlay && millis() % stepDelayMs < 20) {
    stepOnce();
  }
}

void drawPanel() {
  // sidebar
  float x0 = width*0.64;
  noStroke();
  fill(245);
  rect(x0, 0, width-x0, height);

  fill(30);
  textAlign(LEFT, TOP);
  textSize(18);
  text("Maximal Independent Set (MIS)", x0+20, 20);

  textSize(13);
  float y = 60;
  String legend = 
    "Legend:\n" +
    "  ● Green  = In MIS (chosen)\n" +
    "  ● Red    = Excluded by a chosen neighbor\n" +
    "  ● Gray   = Undecided\n\n" +
    "Controls:\n" +
    "  g = run full MIS\n" +
    "  n = next step\n" +
    "  a = toggle auto-step\n" +
    "  r = new random graph\n" +
    "  c = clear states\n" +
    "  1..5 = density";
  text(legend, x0+20, y);

  y += 190;
  int in = countState(IN_MIS), ex = countState(EXCLUDED), un = countState(UNDECIDED);
  text("Stats:", x0+20, y);
  y += 20;
  text("  Nodes: " + N, x0+20, y); y += 18;
  text("  Edges: " + edgeCount(), x0+20, y); y += 18;
  text("  Degree (avg): " + nf(avgDegree(), 0, 2), x0+20, y); y += 18;
  text("  MIS size: " + in, x0+20, y); y += 18;
  text("  Excluded: " + ex, x0+20, y); y += 18;
  text("  Undecided: " + un, x0+20, y); y += 24;

  String mode = autoPlay ? "ON" : "OFF";
  text("Auto-step: " + mode, x0+20, y); y += 18;
  text("Density: " + densityLevel + " (1..5)", x0+20, y); y += 18;

  y += 12;
  text("Processing order (by degree):", x0+20, y); y += 20;
  // show order and a cursor marker
  StringBuilder sb = new StringBuilder();
  for (int i=0; i<order.size(); i++) {
    if (i == cursor) sb.append("[");
    sb.append(order.get(i));
    if (i == cursor) sb.append("]");
    if (i < order.size()-1) sb.append(" ");
  }
  text(sb.toString(), x0+20, y, width - (x0+40), 200);
}

void drawEdges() {
  stroke(200);
  strokeWeight(1.5);
  for (int i=0; i<N; i++) {
    Node a = nodes.get(i);
    for (int j=i+1; j<N; j++) if (adj[i][j]) {
      Node b = nodes.get(j);
      line(a.x, a.y, b.x, b.y);
    }
  }
}

void drawNodes() {
  textAlign(CENTER, CENTER);
  textSize(13);
  for (Node nd : nodes) {
    int st = nd.state;
    // colors
    if (st == IN_MIS) fill(37, 155, 66);
    else if (st == EXCLUDED) fill(220, 66, 66);
    else fill(150);

    stroke(30, 30, 30, 80);
    strokeWeight(1.5);
    float r = 18;
    ellipse(nd.x, nd.y, r*2, r*2);

    fill(255);
    noStroke();
    text(nd.id, nd.x, nd.y);
  }
}

// ---------------- Logic -----------------

// One greedy step: take next undecided node in order; if none of its neighbors is IN_MIS, include it; else exclude it.
boolean stepOnce() {
  while (cursor < order.size()) {
    int id = order.get(cursor++);
    Node v = nodes.get(id);
    if (v.state != UNDECIDED) continue; // already decided by neighbor
    if (hasChosenNeighbor(id)) {
      v.state = EXCLUDED;
      return true;
    } else {
      v.state = IN_MIS;
      // exclude its neighbors
      for (int nb : v.neighbors) {
        if (nodes.get(nb).state == UNDECIDED) nodes.get(nb).state = EXCLUDED;
      }
      return true;
    }
  }
  autoPlay = false;
  return false; // done
}

boolean hasChosenNeighbor(int id) {
  for (int nb : nodes.get(id).neighbors) {
    if (nodes.get(nb).state == IN_MIS) return true;
  }
  return false;
}

void runFull() {
  while (stepOnce()) { /* keep going */ }
}

int countState(int s) {
  int c=0; for (Node nd : nodes) if (nd.state==s) c++; return c;
}

int edgeCount() {
  int e=0; 
  for (int i=0; i<N; i++) for (int j=i+1; j<N; j++) if (adj[i][j]) e++;
  return e;
}

float avgDegree() {
  float sum=0;
  for (Node nd : nodes) sum += nd.neighbors.size();
  return sum / N;
}

// ---------------- Input -----------------
void keyPressed() {
  if (key == 'g' || key == 'G') runFull();
  else if (key == 'n' || key == 'N') stepOnce();
  else if (key == 'a' || key == 'A') autoPlay = !autoPlay;
  else if (key == 'r' || key == 'R') buildGraph();
  else if (key == 'c' || key == 'C') clearStates();
  else if (key >= '1' && key <= '5') {
    densityLevel = key - '0';
    buildGraph();
  }
}

// ---------------- Types -----------------
class Node {
  int id;
  float x, y;
  int state = UNDECIDED;
  ArrayList<Integer> neighbors = new ArrayList<>();
  Node(int id, float x, float y) { this.id=id; this.x=x; this.y=y; }
}
