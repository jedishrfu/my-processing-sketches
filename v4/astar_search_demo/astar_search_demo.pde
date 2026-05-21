// A* Pathfinding Visualization (10x10 Grid) — drag A & B
// Processing (Java mode)
//
// Start A = green, Goal B = red
// Walls: black; Open set: blue; Closed set: light gray; Final path: yellow
//
// Controls:
//   • Left-click/drag on empty cells: paint/erase walls (drag keeps same action)
//   • Left-click + drag on Start (A)   : move A following the mouse
//   • Left-click + drag on Goal  (B)   : move B following the mouse
//   • Right-click                      : set Start (A) to mouse cell
//   • Shift + Left-click               : set Goal  (B) to mouse cell
//   • ENTER: auto-run A*   • S: single-step
//   • R: reset A* (keep walls & A/B)   • C: clear walls
//   • D: toggle diagonals on/off

import java.util.HashSet;

final int COLS = 75, ROWS = 75;
final int CELL = 10;                  // 600x600 window
final int W = COLS * CELL, H = ROWS * CELL;

Node[][] grid = new Node[COLS][ROWS];
ArrayList<Node> openSet = new ArrayList<>();
HashSet<Node> closedSet = new HashSet<>();
ArrayList<Node> path = new ArrayList<>();

int sx = 0, sy = 0;                 // start (A)
int gx = COLS - 1, gy = ROWS - 1;   // goal  (B)

boolean running = false;
boolean diagonals = false;
boolean finished = false;
boolean found = false;

// Drag state
boolean draggingWalls = false;
boolean draggingA = false;
boolean draggingB = false;
boolean paintState = false;         // true=paint walls, false=erase

void settings(){ size(W, H); }

void setup() {
  surface.setTitle("A* on 10x10 — drag A & B");
  initGrid();
  // Optional sample walls
  for (int i = 1; i < 9; i++) grid[i][i].wall = (i != 5);
  reSeedAStar();
}

void initGrid() {
  openSet.clear(); closedSet.clear(); path.clear();
  finished = false; found = false;

  for (int x = 0; x < COLS; x++) for (int y = 0; y < ROWS; y++) grid[x][y] = new Node(x, y);
  rebuildNeighbors();
  reSeedAStar();
}

void rebuildNeighbors() {
  for (int x = 0; x < COLS; x++) for (int y = 0; y < ROWS; y++) grid[x][y].buildNeighbors(diagonals);
}

void reSeedAStar() {
  openSet.clear(); closedSet.clear(); path.clear();
  finished = false; found = false;
  // ensure A/B not walls
  grid[sx][sy].wall = false;
  grid[gx][gy].wall = false;

  for (int x = 0; x < COLS; x++) for (int y = 0; y < ROWS; y++) grid[x][y].resetScores();

  Node start = grid[sx][sy], goal = grid[gx][gy];
  start.g = 0;
  start.h = heuristic(start, goal);
  start.f = start.h;
  openSet.add(start);
}

void draw() {
  background(245);
  if (running && !finished) astarStep();

  // cells
  stroke(220);
  for (int x = 0; x < COLS; x++) {
    for (int y = 0; y < ROWS; y++) {
      Node n = grid[x][y];
      if (n.wall) fill(0); else fill(255);
      if (closedSet.contains(n) && !n.wall) fill(230);
      if (openSet.contains(n)   && !n.wall) fill(180, 210, 255);
      if (path.contains(n)      && !n.wall) fill(255, 235, 100);
      if (n.x == sx && n.y == sy) fill(120, 220, 120);
      if (n.x == gx && n.y == gy) fill(240, 90, 90);
      rect(n.x*CELL, n.y*CELL, CELL, CELL);
    }
  }

  // grid lines
  stroke(200);
  for (int x = 0; x <= COLS; x++) line(x*CELL, 0, x*CELL, H);
  for (int y = 0; y <= ROWS; y++) line(0, y*CELL, W, y*CELL);

  // status
  fill(30);
  textAlign(LEFT, TOP);
  text(
    "ENTER=run  S=step  R=reset  C=clear  D=diagonals(" + (diagonals ? "on" : "off") + ")\n" +
    "Walls: drag on empty cells  |  Drag A/B to move  |  Right-click=A  |  Shift+Left=B\n" +
    "Open: " + openSet.size() + "  Closed: " + closedSet.size() +
    (finished ? (found ? "  ✓ Path found" : "  ✗ No path") : ""),
    8, 8
  );
}

void astarStep() {
  if (openSet.isEmpty()) { finished = true; found = false; path.clear(); running = false; return; }

  int best = 0;
  for (int i = 1; i < openSet.size(); i++) {
    Node a = openSet.get(i), b = openSet.get(best);
    if (a.f < b.f || (a.f == b.f && a.g > b.g)) best = i;
  }
  Node current = openSet.get(best);

  if (current.x == gx && current.y == gy) {
    reconstructPath(current);
    finished = true; found = true; running = false;
    return;
  }

  openSet.remove(best);
  closedSet.add(current);

  for (Node nb : current.neighbors) {
    if (nb.wall || closedSet.contains(nb)) continue;
    float tentativeG = current.g + cost(current, nb);
    if (!openSet.contains(nb)) {
      openSet.add(nb);
    } else if (tentativeG >= nb.g) {
      continue;
    }
    nb.cameFrom = current;
    nb.g = tentativeG;
    nb.h = heuristic(nb, grid[gx][gy]);
    nb.f = nb.g + nb.h;
  }

  reconstructPath(current); // live preview
}

void reconstructPath(Node endNode) {
  path.clear();
  for (Node cur = endNode; cur != null; cur = cur.cameFrom) path.add(0, cur);
}

float heuristic(Node a, Node b) {
  if (!diagonals) return abs(a.x - b.x) + abs(a.y - b.y); // Manhattan
  float dx = abs(a.x - b.x), dy = abs(a.y - b.y);
  return (max(dx, dy) - min(dx, dy)) + 1.4142f * min(dx, dy); // Octile
}

float cost(Node a, Node b) {
  int dx = abs(a.x - b.x), dy = abs(a.y - b.y);
  return (dx + dy == 1) ? 1.0f : 1.41421356f;
}

// ---------------- Input ----------------
void keyPressed() {
  if (keyCode == ENTER || keyCode == RETURN) {
    if (!finished) running = true;
  } else if (key == 's' || key == 'S') {
    if (!finished) { running = false; astarStep(); }
  } else if (key == 'r' || key == 'R') {
    reSeedAStar(); running = false;
  } else if (key == 'c' || key == 'C') {
    for (int x = 0; x < COLS; x++) for (int y = 0; y < ROWS; y++) grid[x][y].wall = false;
    reSeedAStar(); running = false;
  } else if (key == 'd' || key == 'D') {
    diagonals = !diagonals; rebuildNeighbors(); reSeedAStar(); running = false;
  }
}

void mousePressed() {
  int cx = constrain(mouseX / CELL, 0, COLS-1);
  int cy = constrain(mouseY / CELL, 0, ROWS-1);

  // Shift+Left sets Goal (B)
  if (mouseButton == LEFT && keyPressed && keyCode == SHIFT) { setGoal(cx, cy); return; }

  // Right-click sets Start (A)
  if (mouseButton == RIGHT) { setStart(cx, cy); return; }

  // Left-click: decide what we're dragging
  if (mouseButton == LEFT) {
    if (cx == sx && cy == sy) {
      draggingA = true; running = false;
    } else if (cx == gx && cy == gy) {
      draggingB = true; running = false;
    } else {
      draggingWalls = true;
      paintState = !grid[cx][cy].wall;   // choose paint/erase mode from first cell
      applyWall(cx, cy, paintState);
    }
  }
}

void mouseDragged() {
  int cx = constrain(mouseX / CELL, 0, COLS-1);
  int cy = constrain(mouseY / CELL, 0, ROWS-1);

  if (draggingA) moveStartIfChanged(cx, cy);
  else if (draggingB) moveGoalIfChanged(cx, cy);
  else if (draggingWalls) applyWall(cx, cy, paintState);
}

void mouseReleased() {
  draggingA = draggingB = draggingWalls = false;
}

void moveStartIfChanged(int cx, int cy) {
  if (sx == cx && sy == cy) return;
  sx = cx; sy = cy;
  grid[sx][sy].wall = false;
  reSeedAStar(); running = false;
}

void moveGoalIfChanged(int cx, int cy) {
  if (gx == cx && gy == cy) return;
  gx = cx; gy = cy;
  grid[gx][gy].wall = false;
  reSeedAStar(); running = false;
}

void setStart(int cx, int cy) { sx = cx; sy = cy; grid[sx][sy].wall = false; reSeedAStar(); running = false; }
void setGoal (int cx, int cy) { gx = cx; gy = cy; grid[gx][gy].wall = false; reSeedAStar(); running = false; }

void applyWall(int cx, int cy, boolean state) {
  if ((cx == sx && cy == sy) || (cx == gx && cy == gy)) return; // don't cover A/B
  if (grid[cx][cy].wall == state) return;
  grid[cx][cy].wall = state;
  // Topology changed — restart search state for correctness
  reSeedAStar(); running = false;
}

// ---------------- Node ----------------
class Node {
  int x, y;
  boolean wall = false;
  float f = Float.MAX_VALUE, g = Float.MAX_VALUE, h = 0;
  Node cameFrom = null;
  ArrayList<Node> neighbors = new ArrayList<>();

  Node(int x, int y){ this.x = x; this.y = y; }

  void buildNeighbors(boolean diag){
    neighbors.clear();
    addIfValid(x+1, y); addIfValid(x-1, y); addIfValid(x, y+1); addIfValid(x, y-1);
    if (diag) { addIfValid(x+1, y+1); addIfValid(x-1, y-1); addIfValid(x+1, y-1); addIfValid(x-1, y+1); }
  }
  void addIfValid(int nx, int ny){
    if (nx >= 0 && nx < COLS && ny >= 0 && ny < ROWS) neighbors.add(grid[nx][ny]);
  }
  void resetScores(){ f = Float.MAX_VALUE; g = Float.MAX_VALUE; h = 0; cameFrom = null; }
}
