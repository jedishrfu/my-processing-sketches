/**
 * Multi-Core CPU Load/Store + Cache/DRAM Block Diagram (Processing)
 *
 * Requested upgrades implemented:
 *  - Cache “tables” are drawn INSIDE the L1/L2/L3 boxes.
 *  - DRAM “memory table” is drawn INSIDE the Mem Controller box (DRAM box remains as endpoint).
 *  - Press '0' to run:   c = a + b on Core 0  (LOAD a, LOAD b, ADD, STORE c)
 *  - Press '1' to run:   c = a + b on Core 1
 *  - Balls follow bent-bus arrows.
 *  - Variable speeds by hop:
 *      Core <-> L1 : base speed
 *      L1   <-> L2 : 1/2 speed
 *      L2   <-> L3 : 1/4 speed
 *      L3   <-> MemCtrl/DRAM : 1/10 speed
 *  - Show last value loaded/stored/added in the relevant boxes.
 *  - Highlight the last memory address accessed and show new value on store.
 *
 * Other controls:
 *  - R = reset (clears caches, re-seeds memory)
 *  - SPACE = pause/resume
 */

import java.util.*;

final int NCORES = 2;
final int ADDR_SPACE = 16;

// Base speed in pixels/frame (Core<->L1)
final float BASE_SPEED = 1.0;
final float ELBOW_PAD  = 26;

boolean paused = false;

// Program (c=a+b) addresses
final int ADDR_A = 2;
final int ADDR_B = 5;
final int ADDR_C = 9;

// --------------------------- Cache model (stores values) ---------------------------

class CacheLine {
  int addr = -1;
  int val  = 0;
  boolean valid = false;
  boolean dirty = false;
}

class Cache {
  String name;
  int capacity;
  CacheLine[] lines;

  // highlight state
  int[] hiTimer;     // frames remaining
  int[] hiType;      // 0 none, 1 load, 2 store

  // last info for box display
  String lastInfo = "";

  Cache(String name, int capacity) {
    this.name = name;
    this.capacity = capacity;
    lines = new CacheLine[capacity];
    hiTimer = new int[capacity];
    hiType  = new int[capacity];
    for (int i=0;i<capacity;i++) {
      lines[i] = new CacheLine();
      hiTimer[i] = 0;
      hiType[i] = 0;
    }
  }

  int find(int a) {
    for (int i=0;i<capacity;i++) {
      if (lines[i].valid && lines[i].addr == a) return i;
    }
    return -1;
  }

  int put(int a, int v, boolean dirtyFlag) {
    int idx = find(a);
    if (idx >= 0) {
      lines[idx].val = v;
      lines[idx].dirty = lines[idx].dirty || dirtyFlag;
      return idx;
    }
    // first invalid else random victim
    for (int i=0;i<capacity;i++) {
      if (!lines[i].valid) {
        lines[i].addr = a;
        lines[i].val = v;
        lines[i].valid = true;
        lines[i].dirty = dirtyFlag;
        return i;
      }
    }
    int victim = (int)random(capacity);
    lines[victim].addr = a;
    lines[victim].val = v;
    lines[victim].valid = true;
    lines[victim].dirty = dirtyFlag;
    return victim;
  }

  void invalidateAddr(int a) {
    int idx = find(a);
    if (idx >= 0) {
      lines[idx].valid = false;
      lines[idx].dirty = false;
      lines[idx].addr = -1;
      lines[idx].val  = 0;
      hiTimer[idx] = 0;
      hiType[idx] = 0;
    }
  }

  void touch(int idx, int type, String info) {
    if (idx < 0 || idx >= capacity) return;
    hiTimer[idx] = 55;
    hiType[idx]  = type;
    lastInfo = info;
  }

  void decay() {
    for (int i=0;i<capacity;i++) {
      if (hiTimer[i] > 0) hiTimer[i]--;
      if (hiTimer[i] == 0) hiType[i] = 0;
    }
  }

  void clear() {
    for (int i=0;i<capacity;i++) {
      lines[i].addr = -1;
      lines[i].val  = 0;
      lines[i].valid = false;
      lines[i].dirty = false;
      hiTimer[i] = 0;
      hiType[i] = 0;
    }
    lastInfo = "";
  }
}

// --------------------------- Diagram geometry ---------------------------

class Box {
  String label;
  float x, y, w, h;

  // last info for box display
  String lastInfo = "";

  Box(String label, float x, float y, float w, float h) {
    this.label = label;
    this.x=x; this.y=y; this.w=w; this.h=h;
  }

  PVector center() { return new PVector(x + w/2.0, y + h/2.0); }
  float left()   { return x; }
  float right()  { return x + w; }
  float top()    { return y; }
  float bottom() { return y + h; }
}

PVector anchorRight(Box b)  { return new PVector(b.right(), b.y + b.h/2.0); }
PVector anchorLeft(Box b)   { return new PVector(b.left(),  b.y + b.h/2.0); }
PVector anchorTop(Box b)    { return new PVector(b.x + b.w/2.0, b.top()); }
PVector anchorBottom(Box b) { return new PVector(b.x + b.w/2.0, b.bottom()); }

PVector bestOut(Box a, Box b) {
  if (b.center().x >= a.center().x + 1) return anchorRight(a);
  if (b.center().x <= a.center().x - 1) return anchorLeft(a);
  if (b.center().y >= a.center().y)     return anchorBottom(a);
  return anchorTop(a);
}
PVector bestIn(Box a, Box b) {
  if (a.center().x <= b.center().x - 1) return anchorLeft(b);
  if (a.center().x >= b.center().x + 1) return anchorRight(b);
  if (a.center().y <= b.center().y)     return anchorTop(b);
  return anchorBottom(b);
}

// --------------------------- Layout ---------------------------

Box[] core = new Box[NCORES];
Box[] l1   = new Box[NCORES];
Box[] l2   = new Box[NCORES];
Box l3, memctrl, dram;

Cache[] L1 = new Cache[NCORES];
Cache[] L2 = new Cache[NCORES];
Cache L3;

int[] DRAM = new int[ADDR_SPACE];

// Mem highlight
int memHiAddr = -1;
int memHiTimer = 0;
int memHiNewVal = 0;
boolean memHiWasStore = false;

// Core registers for the c=a+b demo
int[] regA = new int[NCORES];
int[] regB = new int[NCORES];
int[] regC = new int[NCORES];
String[] coreInfo = new String[NCORES];

// --------------------------- Bent path helpers ---------------------------

class Path2 {
  PVector p0, p1, p2;
  float len01, len12, len;

  Path2(PVector p0, PVector p1, PVector p2) {
    this.p0=p0; this.p1=p1; this.p2=p2;
    len01 = PVector.dist(p0, p1);
    len12 = PVector.dist(p1, p2);
    len = len01 + len12;
  }

  PVector pointAt(float t) {
    float d = t * len;
    if (d <= len01 || len12 < 1e-6) {
      float tt = (len01 < 1e-6) ? 1 : (d / len01);
      return PVector.lerp(p0, p1, constrain(tt, 0, 1));
    } else {
      float dd = d - len01;
      float tt = (len12 < 1e-6) ? 1 : (dd / len12);
      return PVector.lerp(p1, p2, constrain(tt, 0, 1));
    }
  }

  void drawPolyline() {
    line(p0.x, p0.y, p1.x, p1.y);
    line(p1.x, p1.y, p2.x, p2.y);
  }
}

Path2 makeBentPath(PVector a, PVector b) {
  float dx = abs(b.x - a.x);
  float dy = abs(b.y - a.y);

  PVector a2 = a.copy();
  if (dx >= dy) a2.x += (b.x >= a.x ? ELBOW_PAD : -ELBOW_PAD);
  else          a2.y += (b.y >= a.y ? ELBOW_PAD : -ELBOW_PAD);

  PVector p1;
  if (dx >= dy) p1 = new PVector(a2.x, b.y);
  else          p1 = new PVector(b.x, a2.y);

  return new Path2(a2, p1, b.copy());
}

// --------------------------- Animation transactions ---------------------------

enum OpKind { LOAD, STORE, ALU_ADD }

class Hop {
  Box src;
  Box dst;
  String text;
  PVector start;
  PVector end;
  Path2 path;
  float speed; // pixels/frame for THIS hop

  Hop(Box s, Box d, String text) {
    src=s; dst=d; this.text=text;
    start = bestOut(src, dst);
    end   = bestIn(src, dst);
    path  = makeBentPath(start, end);
    speed = speedForEdge(src, dst);
  }
}

// Speed multiplier by level transitions
float speedForEdge(Box a, Box b) {
  // Identify level by box label
  String A = a.label;
  String B = b.label;

  // Core<->L1
  if (A.startsWith("Core") && B.equals("L1")) return BASE_SPEED;
  if (A.equals("L1") && B.startsWith("Core")) return BASE_SPEED;

  // L1<->L2
  if (A.equals("L1") && B.equals("L2")) return BASE_SPEED * 0.5;
  if (A.equals("L2") && B.equals("L1")) return BASE_SPEED * 0.5;

  // L2<->L3
  if (A.equals("L2") && B.equals("Shared L3")) return BASE_SPEED * 0.25;
  if (A.equals("Shared L3") && B.equals("L2")) return BASE_SPEED * 0.25;

  // L1<->L3 (rare)
  if (A.equals("L1") && B.equals("Shared L3")) return BASE_SPEED * 0.25;
  if (A.equals("Shared L3") && B.equals("L1")) return BASE_SPEED * 0.25;

  // L3<->MemCtrl/DRAM
  if (A.equals("Shared L3") && B.equals("Mem Ctrl")) return BASE_SPEED * 0.1;
  if (A.equals("Mem Ctrl") && B.equals("Shared L3")) return BASE_SPEED * 0.1;
  if (A.equals("Mem Ctrl") && B.equals("DRAM"))      return BASE_SPEED * 0.1;
  if (A.equals("DRAM") && B.equals("Mem Ctrl"))      return BASE_SPEED * 0.1;

  // default
  return BASE_SPEED * 0.5;
}

class Txn {
  int coreId;
  OpKind kind;
  int addr;
  int value;          // for store; for load filled when resolved; for add result
  String label;       // text displayed
  ArrayList<Hop> hops = new ArrayList<Hop>();
  int hopIndex = 0;
  float progPx = 0;

  // callbacks
  Runnable onFinish = null;

  // visuals
  int ballColor;

  Txn(int coreId, OpKind kind, int addr, int value, String label) {
    this.coreId = coreId;
    this.kind = kind;
    this.addr = addr;
    this.value = value;
    this.label = label;

    if (kind == OpKind.STORE) ballColor = color(255, 120, 120);
    else if (kind == OpKind.LOAD) ballColor = color(120, 200, 255);
    else ballColor = color(180, 180, 180);
  }

  boolean done() { return hopIndex >= hops.size(); }

  void update() {
    if (done()) return;
    Hop h = hops.get(hopIndex);
    progPx += h.speed;
    if (progPx >= h.path.len) {
      progPx = 0;
      hopIndex++;
      if (hopIndex >= hops.size() && onFinish != null) onFinish.run();
    }
  }

  void draw() {
    if (done()) return;
    Hop h = hops.get(hopIndex);
    float t = (h.path.len < 1e-6) ? 1 : (progPx / h.path.len);
    PVector p = h.path.pointAt(constrain(t, 0, 1));

    noStroke();
    fill(ballColor);
    ellipse(p.x, p.y, 14, 14);

    fill(20);
    textAlign(LEFT, CENTER);
    textSize(12);
    text(label, p.x + 10, p.y - 10);

    PVector mid = h.path.pointAt(0.55);
    fill(60);
    textSize(11);
    text(h.text, mid.x + 8, mid.y);
  }
}

ArrayList<Txn> txns = new ArrayList<Txn>();
ArrayDeque<Txn> pending = new ArrayDeque<Txn>(); // serialized program execution

// --------------------------- Setup / draw ---------------------------

void setup() {
  size(1320, 760);
  smooth(4);
  initLayoutAndState();
}

void initLayoutAndState() {
  // Layout
  float leftX = 60;
  float topY  = 95;
  float laneH = 260;

  float coreW = 190, coreH = 120;
  float cacheW = 170, cacheH = 140;
  float l3W = 220, l3H = 200;
  float mcW = 260, mcH = 260;
  float dramW = 180, dramH = 110;

  for (int i=0;i<NCORES;i++) {
    float y = topY + i*laneH;
    core[i] = new Box("Core " + i, leftX, y, coreW, coreH);
    float cacheX = leftX + 230;
    l1[i] = new Box("L1", cacheX, y - 10, cacheW, cacheH);
    l2[i] = new Box("L2", cacheX, y + 140, cacheW, cacheH);

    // capacities chosen to fit inside box
    L1[i] = new Cache("L1", 4);
    L2[i] = new Cache("L2", 4);

    regA[i] = 0; regB[i] = 0; regC[i] = 0;
    coreInfo[i] = "";
  }

  l3      = new Box("Shared L3", 560, 250, l3W, l3H);
  memctrl = new Box("Mem Ctrl",  840, 210, mcW, mcH);
  dram    = new Box("DRAM",     1140, 250, dramW, dramH);

  L3 = new Cache("L3", 6);

  // Seed memory with deterministic-ish values so demo is repeatable
  randomSeed((int)millis());
  for (int a=0;a<ADDR_SPACE;a++) DRAM[a] = (int)random(10, 99);

  // Make sure a and b are nice demo numbers
  DRAM[ADDR_A] = 12;
  DRAM[ADDR_B] = 34;
  DRAM[ADDR_C] = 0;

  memHiAddr = -1;
  memHiTimer = 0;
  memHiNewVal = 0;
  memHiWasStore = false;

  txns.clear();
  pending.clear();

  logLines.clear();
  log("Press 0 to run c=a+b on Core 0, press 1 to run on Core 1. R resets.");
}

void draw() {
  background(248);

  drawTitle();

  // wiring behind
  drawWiringBent();

  // boxes
  drawBoxes();

  // decay highlights
  if (!paused) {
    for (int i=0;i<NCORES;i++) { L1[i].decay(); L2[i].decay(); }
    L3.decay();
    if (memHiTimer > 0) memHiTimer--;
  }

  // draw internals
  drawCoreInside(0);
  drawCoreInside(1);
  drawCacheInside(l1[0], L1[0]);
  drawCacheInside(l2[0], L2[0]);
  drawCacheInside(l1[1], L1[1]);
  drawCacheInside(l2[1], L2[1]);
  drawCacheInside(l3, L3);
  drawMemInside(memctrl);
  drawDramBoxInfo(dram);

  drawLegendAndControls();
  drawLog();

  // run serialized program queue if nothing active
  if (!paused) {
    if (txns.size() == 0 && pending.size() > 0) {
      txns.add(pending.removeFirst());
    }
  }

  // animate txns
  if (!paused) {
    for (Txn t : txns) t.update();
  }
  for (Txn t : txns) t.draw();

  // remove finished
  for (int i=txns.size()-1;i>=0;i--) {
    if (txns.get(i).done()) txns.remove(i);
  }
}

void keyPressed() {
  if (key == ' ') paused = !paused;
  if (key == 'r' || key == 'R') initLayoutAndState();

  if (key == '0') runEquationOnCore(0);
  if (key == '1') runEquationOnCore(1);
}

// --------------------------- Drawing primitives ---------------------------

void drawTitle() {
  fill(20);
  textAlign(LEFT, TOP);
  textSize(18);
  text("Multi-core CPU: caches inside boxes; memory table inside Mem Ctrl; demo: c = a + b", 40, 20);
  textSize(12);
  fill(70);
  text("Speed tiers: Core↔L1=1×, L1↔L2=1/2×, L2↔L3=1/4×, L3↔Mem/DRAM=1/10×. Address highlights shown in Mem Ctrl.", 40, 45);
}

void drawBoxes() {
  drawBox(core[0]);
  drawBox(l1[0]);
  drawBox(l2[0]);

  drawBox(core[1]);
  drawBox(l1[1]);
  drawBox(l2[1]);

  drawBox(l3);
  drawBox(memctrl);
  drawBox(dram);
}

void drawBox(Box b) {
  stroke(40);
  strokeWeight(2);
  fill(255);
  rect(b.x, b.y, b.w, b.h, 14);

  fill(20);
  textAlign(CENTER, TOP);
  textSize(14);
  text(b.label, b.x + b.w/2, b.y + 8);

  // last info line at bottom of box
  if (b.lastInfo != null && b.lastInfo.length() > 0) {
    fill(60);
    textAlign(CENTER, BOTTOM);
    textSize(11);
    text(b.lastInfo, b.x + b.w/2, b.y + b.h - 6);
  }
}

void drawWiringBent() {
  stroke(120);
  strokeWeight(2);

  // Core -> L1 / L2
  drawBentArrow(core[0], l1[0]);
  drawBentArrow(core[0], l2[0]);
  drawBentArrow(core[1], l1[1]);
  drawBentArrow(core[1], l2[1]);

  // L1/L2 -> L3
  drawBentArrow(l1[0], l3);
  drawBentArrow(l2[0], l3);
  drawBentArrow(l1[1], l3);
  drawBentArrow(l2[1], l3);

  // L3 -> MemCtrl -> DRAM
  drawBentArrow(l3, memctrl);
  drawBentArrow(memctrl, dram);
}

void drawBentArrow(Box src, Box dst) {
  PVector a = bestOut(src, dst);
  PVector b = bestIn(src, dst);
  Path2 p = makeBentPath(a, b);
  p.drawPolyline();
  drawArrowHead(p.p1, p.p2);
}

void drawArrowHead(PVector tail, PVector head) {
  PVector d = PVector.sub(head, tail);
  float ang = atan2(d.y, d.x);
  float len = 10;

  PVector p1 = new PVector(head.x - len*cos(ang - 0.35), head.y - len*sin(ang - 0.35));
  PVector p2 = new PVector(head.x - len*cos(ang + 0.35), head.y - len*sin(ang + 0.35));

  line(head.x, head.y, p1.x, p1.y);
  line(head.x, head.y, p2.x, p2.y);
}

// --------------------------- Inside-box renderers ---------------------------

void drawCacheInside(Box box, Cache c) {
  // interior region
  float pad = 10;
  float top = box.y + 28;
  float left = box.x + pad;
  float right = box.x + box.w - pad;
  float bottom = box.y + box.h - 26;

  // header
  fill(50);
  textAlign(LEFT, TOP);
  textSize(11);
  text("idx  addr  val  V D", left, top);

  float rowH = 18;
  float y = top + 14;

  for (int i=0;i<c.capacity;i++) {
    float ry = y + i*rowH;

    // highlight row if touched
    if (c.hiTimer[i] > 0) {
      if (c.hiType[i] == 1) fill(210, 235, 255);      // load
      else if (c.hiType[i] == 2) fill(255, 220, 220); // store
      else fill(240);
      noStroke();
      rect(left - 4, ry - 2, (right-left) + 8, rowH - 2, 6);
      stroke(40);
      strokeWeight(2);
    }

    CacheLine L = c.lines[i];
    String addrStr = L.valid ? ("A"+L.addr) : "--";
    String valStr  = L.valid ? nf(L.val, 2) : "--";
    String vd = (L.valid ? "1" : "0") + " " + (L.dirty ? "1" : "0");

    fill(30);
    textAlign(LEFT, TOP);
    text(i + "    " + addrStr + "   " + valStr + "   " + vd, left, ry);
  }

  // show last action line just above bottom info area
  if (c.lastInfo != null && c.lastInfo.length() > 0) {
    fill(70);
    textAlign(CENTER, BOTTOM);
    textSize(11);
    text(c.lastInfo, box.x + box.w/2, box.y + box.h - 26);
  }
}

void drawMemInside(Box mc) {
  // Draw memory table INSIDE Mem Ctrl box
  float pad = 12;
  float left = mc.x + pad;
  float top  = mc.y + 32;
  float w    = mc.w - 2*pad;

  fill(50);
  textAlign(LEFT, TOP);
  textSize(11);
  text("Memory (DRAM) shadow table:", left, top);

  int cols = 4;
  float cellW = w / cols;
  float cellH = 22;
  float y0 = top + 16;

  for (int a=0;a<ADDR_SPACE;a++) {
    int r = a / cols;
    int c = a % cols;
    float x = left + c*cellW;
    float y = y0 + r*cellH;

    boolean hi = (a == memHiAddr && memHiTimer > 0);

    if (hi) {
      if (memHiWasStore) fill(255, 220, 220);
      else fill(210, 235, 255);
      noStroke();
      rect(x+2, y+2, cellW-4, cellH-4, 6);
      stroke(40);
      strokeWeight(2);
    }

    fill(30);
    textAlign(LEFT, TOP);
    String txt = "A"+a+": "+DRAM[a];
    if (hi && memHiWasStore) txt = "A"+a+": "+DRAM[a]+" (new)";
    text(txt, x+6, y+4);
  }

  // small status line
  fill(70);
  textAlign(LEFT, BOTTOM);
  textSize(11);
  String s = (memHiAddr >= 0 && memHiTimer > 0)
    ? (memHiWasStore
        ? ("Last STORE: A"+memHiAddr+"="+DRAM[memHiAddr])
        : ("Last LOAD: A"+memHiAddr+"="+DRAM[memHiAddr]))
    : "Last: (none)";
  text(s, left, mc.y + mc.h - 10);
}

void drawDramBoxInfo(Box d) {
  // DRAM box is now just an endpoint + last info
  fill(60);
  textAlign(CENTER, CENTER);
  textSize(11);
  text("Physical DRAM\n(endpoint)", d.x + d.w/2, d.y + d.h/2 + 10);
}

void drawCoreInside(int cid) {
  Box b = core[cid];
  float pad = 12;
  float x = b.x + pad;
  float y = b.y + 34;

  fill(50);
  textAlign(LEFT, TOP);
  textSize(11);
  text("Regs:", x, y);
  fill(30);
  text("a=" + regA[cid] + "  b=" + regB[cid] + "  c=" + regC[cid], x, y + 16);

  fill(70);
  text("last: " + coreInfo[cid], x, y + 36);
}

// --------------------------- Legend / Log ---------------------------

ArrayList<String> logLines = new ArrayList<String>();

void drawLegendAndControls() {
  float x = 40, y = height - 120;

  stroke(180);
  fill(255);
  rect(x, y, 820, 90, 14);

  fill(20);
  textAlign(LEFT, TOP);
  textSize(12);
  text("Controls:", x + 14, y + 10);
  text("0: c=a+b on Core0   1: c=a+b on Core1   R: reset   SPACE: pause", x + 14, y + 30);

  fill(20);
  text("Legend:", x + 14, y + 55);

  noStroke();
  fill(120, 200, 255);
  ellipse(x + 82, y + 72, 12, 12);
  fill(20);
  text("LOAD / read path", x + 95, y + 64);

  fill(255, 120, 120);
  ellipse(x + 240, y + 72, 12, 12);
  fill(20);
  text("STORE / write path", x + 253, y + 64);

  fill(180);
  ellipse(x + 405, y + 72, 12, 12);
  fill(20);
  text("ALU add (no bus traffic)", x + 418, y + 64);
}

void drawLog() {
  float x = 890;
  float y = height - 120;

  stroke(180);
  fill(255);
  rect(x, y, 390, 90, 14);

  fill(20);
  textAlign(LEFT, TOP);
  textSize(12);
  text("Event log:", x + 14, y + 10);

  textSize(11);
  float yy = y + 30;
  for (int i=max(0, logLines.size()-3); i<logLines.size(); i++) {
    fill(40);
    text("• " + logLines.get(i), x + 14, yy);
    yy += 18;
  }

  fill(70);
  textAlign(RIGHT, TOP);
  text(paused ? "PAUSED" : "RUNNING", x + 370, y + 10);
}

void log(String s) {
  logLines.add(s);
  if (logLines.size() > 80) logLines.remove(0);
}

// --------------------------- Program: c=a+b ---------------------------

void runEquationOnCore(int cid) {
  if (pending.size() > 0 || txns.size() > 0) {
    log("Busy: wait for current demo to finish (or press R).");
    return;
  }

  // reset registers (demo clarity)
  regA[cid] = 0;
  regB[cid] = 0;
  regC[cid] = 0;
  coreInfo[cid] = "";

  log("Core" + cid + ": Begin demo: c = a + b  (a@A"+ADDR_A+", b@A"+ADDR_B+", c@A"+ADDR_C+")");

  // Step 1: LOAD a
  Txn t1 = makeLoadTxn(cid, ADDR_A, "LD A"+ADDR_A+" -> a");
  t1.onFinish = new Runnable() { public void run() {
    regA[cid] = t1.value;
    coreInfo[cid] = "loaded a=" + regA[cid];
    core[cid].lastInfo = "a=" + regA[cid];
    log("Core" + cid + ": a = " + regA[cid]);
  }};

  // Step 2: LOAD b
  Txn t2 = makeLoadTxn(cid, ADDR_B, "LD A"+ADDR_B+" -> b");
  t2.onFinish = new Runnable() { public void run() {
    regB[cid] = t2.value;
    coreInfo[cid] = "loaded b=" + regB[cid];
    core[cid].lastInfo = "b=" + regB[cid];
    log("Core" + cid + ": b = " + regB[cid]);
  }};

  // Step 3: ADD
  Txn t3 = makeAddTxn(cid, "ADD a+b -> c");
  t3.onFinish = new Runnable() { public void run() {
    regC[cid] = regA[cid] + regB[cid];
    coreInfo[cid] = "added c=" + regC[cid];
    core[cid].lastInfo = "c=" + regC[cid];
    log("Core" + cid + ": c = a + b = " + regC[cid]);
  }};

  // Step 4: STORE c
  Txn t4 = makeStoreTxn(cid, ADDR_C, regC[cid], "ST c -> A"+ADDR_C);
  t4.onFinish = new Runnable() { public void run() {
    coreInfo[cid] = "stored c=" + regC[cid] + " to A" + ADDR_C;
    core[cid].lastInfo = "stored c=" + regC[cid];
    log("Core" + cid + ": STORE A" + ADDR_C + " = " + DRAM[ADDR_C]);
  }};

  // Serialize
  pending.addLast(t1);
  pending.addLast(t2);
  pending.addLast(t3);
  pending.addLast(t4);
}

// --------------------------- Txn builders that also update cache/mem state ---------------------------

Txn makeAddTxn(int cid, String label) {
  // ALU add: animate a small "gray hop" inside core (tiny path core->core)
  Txn t = new Txn(cid, OpKind.ALU_ADD, -1, -1, label);
  // fake hop within the core box so you see a "tick"
  t.hops.add(new Hop(core[cid], core[cid], "ALU"));
  // slow-ish but visible
  t.hops.get(0).speed = BASE_SPEED * 0.8;
  return t;
}

Txn makeLoadTxn(int cid, int addr, String label) {
  Txn t = new Txn(cid, OpKind.LOAD, addr, 0, label);

  // Resolve value + path (hit/miss)
  // L1?
  int i1 = L1[cid].find(addr);
  if (i1 >= 0) {
    int v = L1[cid].lines[i1].val;
    t.value = v;

    L1[cid].touch(i1, 1, "LD A"+addr+"="+v);
    l1[cid].lastInfo = "LD A"+addr+"="+v;

    memMarkLoad(addr);

    t.hops.add(new Hop(core[cid], l1[cid], "L1 hit"));
    return t;
  }

  // L2?
  int i2 = L2[cid].find(addr);
  if (i2 >= 0) {
    int v = L2[cid].lines[i2].val;
    t.value = v;

    L2[cid].touch(i2, 1, "LD A"+addr+"="+v);
    l2[cid].lastInfo = "LD A"+addr+"="+v;

    int l1idx = L1[cid].put(addr, v, false);
    L1[cid].touch(l1idx, 1, "fill A"+addr+"="+v);
    l1[cid].lastInfo = "fill A"+addr+"="+v;

    memMarkLoad(addr);

    t.hops.add(new Hop(core[cid], l1[cid], "L1 miss"));
    t.hops.add(new Hop(l1[cid], l2[cid], "L2 hit"));
    t.hops.add(new Hop(l2[cid], l1[cid], "fill L1"));
    return t;
  }

  // L3?
  int i3 = L3.find(addr);
  if (i3 >= 0) {
    int v = L3.lines[i3].val;
    t.value = v;

    L3.touch(i3, 1, "LD A"+addr+"="+v);
    l3.lastInfo = "LD A"+addr+"="+v;

    int l2idx = L2[cid].put(addr, v, false);
    int l1idx = L1[cid].put(addr, v, false);
    L2[cid].touch(l2idx, 1, "fill A"+addr+"="+v);
    L1[cid].touch(l1idx, 1, "fill A"+addr+"="+v);
    l2[cid].lastInfo = "fill A"+addr+"="+v;
    l1[cid].lastInfo = "fill A"+addr+"="+v;

    memMarkLoad(addr);

    t.hops.add(new Hop(core[cid], l1[cid], "L1 miss"));
    t.hops.add(new Hop(l1[cid], l2[cid], "L2 miss"));
    t.hops.add(new Hop(l2[cid], l3, "L3 hit"));
    t.hops.add(new Hop(l3, l2[cid], "fill L2"));
    t.hops.add(new Hop(l2[cid], l1[cid], "fill L1"));
    return t;
  }

  // DRAM fetch
  int v = DRAM[addr];
  t.value = v;

  // Fill L3/L2/L1
  int l3idx = L3.put(addr, v, false);
  int l2idx = L2[cid].put(addr, v, false);
  int l1idx = L1[cid].put(addr, v, false);

  L3.touch(l3idx, 1, "fill A"+addr+"="+v);
  L2[cid].touch(l2idx, 1, "fill A"+addr+"="+v);
  L1[cid].touch(l1idx, 1, "fill A"+addr+"="+v);

  l3.lastInfo = "fill A"+addr+"="+v;
  l2[cid].lastInfo = "fill A"+addr+"="+v;
  l1[cid].lastInfo = "fill A"+addr+"="+v;

  memMarkLoad(addr);

  t.hops.add(new Hop(core[cid], l1[cid], "L1 miss"));
  t.hops.add(new Hop(l1[cid], l2[cid], "L2 miss"));
  t.hops.add(new Hop(l2[cid], l3, "L3 miss"));
  t.hops.add(new Hop(l3, memctrl, "to MemCtrl"));
  t.hops.add(new Hop(memctrl, dram, "read DRAM"));
  t.hops.add(new Hop(dram, memctrl, "data returns"));
  t.hops.add(new Hop(memctrl, l3, "fill L3"));
  t.hops.add(new Hop(l3, l2[cid], "fill L2"));
  t.hops.add(new Hop(l2[cid], l1[cid], "fill L1"));

  return t;
}

Txn makeStoreTxn(int cid, int addr, int value, String label) {
  Txn t = new Txn(cid, OpKind.STORE, addr, value, label);

  // Coherence (simplified): invalidate other core's copies
  int other = 1 - cid;
  if (L1[other].find(addr) >= 0 || L2[other].find(addr) >= 0) {
    L1[other].invalidateAddr(addr);
    L2[other].invalidateAddr(addr);
    log("Coherence: invalidated Core" + other + " for A" + addr);
  }

  // Update caches
  int l1idx = L1[cid].put(addr, value, true);
  int l2idx = L2[cid].put(addr, value, true);
  int l3idx = L3.put(addr, value, true);

  L1[cid].touch(l1idx, 2, "ST A"+addr+"="+value);
  L2[cid].touch(l2idx, 2, "ST A"+addr+"="+value);
  L3.touch(l3idx, 2, "ST A"+addr+"="+value);

  l1[cid].lastInfo = "ST A"+addr+"="+value;
  l2[cid].lastInfo = "ST A"+addr+"="+value;
  l3.lastInfo      = "ST A"+addr+"="+value;

  // Write to DRAM (simplified as immediate)
  DRAM[addr] = value;
  memMarkStore(addr, value);

  // Animate store path
  t.hops.add(new Hop(core[cid], l1[cid], "write L1"));
  t.hops.add(new Hop(l1[cid], l2[cid], "update L2"));
  t.hops.add(new Hop(l2[cid], l3, "update L3"));
  t.hops.add(new Hop(l3, memctrl, "to MemCtrl"));
  t.hops.add(new Hop(memctrl, dram, "store DRAM"));

  return t;
}

// --------------------------- Mem highlight helpers ---------------------------

void memMarkLoad(int addr) {
  memHiAddr = addr;
  memHiTimer = 80;
  memHiWasStore = false;
}

void memMarkStore(int addr, int newVal) {
  memHiAddr = addr;
  memHiTimer = 100;
  memHiNewVal = newVal;
  memHiWasStore = true;
}
