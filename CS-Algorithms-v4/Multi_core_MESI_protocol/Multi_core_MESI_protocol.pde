// MESI Protocol Visualization in Processing
// -----------------------------------------
// Shows 3 CPUs, each with a small cache, and a shared main memory.
// Visualizes MESI states and transitions for:
// - Read Hit / Miss
// - Write Hit / Miss
//
// Controls:
//   1/2/3 : select active CPU
//   r     : read from active CPU, current address
//   w     : write from active CPU, current address
//   a/d   : change address (0..3)
//   s     : toggle auto scenario
//   c     : clear / reset
//
// MESI states (per cache line):
//   M = Modified (red)
//   E = Exclusive (orange)
//   S = Shared (green)
//   I = Invalid (gray)

static final int NUM_CPUS = 3;
static final int NUM_LINES = 4;   // "addresses" 0..3

// MESI encoded as ints
static final int I = 0;
static final int S = 1;
static final int E = 2;
static final int M = 3;

String[] mesiNames = { "I", "S", "E", "M" };

class CacheLine {
  int addr;      // 0..NUM_LINES-1
  int mesi;      // I/S/E/M
  int value;     // simple integer value
  CacheLine(int addr) {
    this.addr = addr;
    this.mesi = I;
    this.value = 0;
  }
}

class Cpu {
  int id;
  CacheLine[] lines;
  Cpu(int id) {
    this.id = id;
    lines = new CacheLine[NUM_LINES];
    for (int i = 0; i < NUM_LINES; i++) {
      lines[i] = new CacheLine(i);
    }
  }
}

class MemLine {
  int addr;
  int value;
  MemLine(int addr) {
    this.addr = addr;
    this.value = 0;
  }
}

// Simple bus transaction for drawing
class BusEvent {
  int srcCpu;         // which CPU initiated
  String type;        // "BusRd", "BusRdX", "BusUpgr"
  int addr;
  int ttl;            // frames remaining
  BusEvent(int srcCpu, String type, int addr) {
    this.srcCpu = srcCpu;
    this.type = type;
    this.addr = addr;
    this.ttl = 60;
  }
}

Cpu[] cpus = new Cpu[NUM_CPUS];
MemLine[] mem = new MemLine[NUM_LINES];
ArrayList<BusEvent> busEvents = new ArrayList<BusEvent>();

int activeCpu = 0;        // selected CPU 0..2
int currentAddr = 0;      // selected address 0..3

// Scenario scripting
int scenarioStep = 0;
boolean autoStep = false;
int autoStepDelay = 0;

// For logging recent actions
ArrayList<String> logLines = new ArrayList<String>();
int MAX_LOG = 10;

void setup() {
  size(1000, 700);   // window tall enough for all bands [web:107]
  textFont(createFont("Consolas", 14));
  initSystem();
}

void initSystem() {
  for (int i = 0; i < NUM_CPUS; i++) {
    cpus[i] = new Cpu(i);
  }
  for (int i = 0; i < NUM_LINES; i++) {
    mem[i] = new MemLine(i);
  }
  busEvents.clear();
  scenarioStep = 0;
  autoStep = false;
  autoStepDelay = 0;
  logLines.clear();
  log("System reset. All lines in I, memory = 0.");
}

void draw() {
  background(25);
  drawTitle();
  drawCpusAndCaches();
  drawMemory();
  drawBus();
  drawControls();  // bottom-left
  drawLog();       // bottom-right

  stepBusEvents();
  if (autoStep) {
    autoStepDelay--;
    if (autoStepDelay <= 0) {
      doScenarioStep();
      autoStepDelay = 90;
    }
  }
}

void drawTitle() {
  fill(255);
  textAlign(LEFT, TOP);
  textSize(18);
  text("MESI Protocol Visualization (Read/Write Hits & Misses)", 20, 10);
  textSize(12);
  text("Active CPU: " + (activeCpu+1) + "   Address: " + currentAddr, 20, 32);
}

// Cache frame sized so all 4 lines fit fully inside
void drawCpusAndCaches() {
  float cpuWidth = width / 3.0;
  float top = 60;
  float cpuHeight = 230; // slightly shorter than previous 240

  for (int i = 0; i < NUM_CPUS; i++) {
    float x = i * cpuWidth;
    float y = top;

    // CPU box
    stroke(255);
    strokeWeight(1);
    fill(i == activeCpu ? color(80, 120, 255) : color(40));
    rect(x + 10, y, cpuWidth - 20, 40, 6);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(16);
    text("CPU " + (i+1), x + cpuWidth/2, y + 20);

    // Cache box
    float cacheTop = y + 50;
    float cacheHeight = cpuHeight - 50;
    fill(30);
    rect(x + 10, cacheTop, cpuWidth - 20, cacheHeight, 6);
    fill(255);
    textAlign(LEFT, TOP);
    textSize(12);
    text("Cache", x + 20, cacheTop + 5);

    // Lines inside cache
    float lineTop = cacheTop + 25;
    float lineHeight = 30;
    float lineSpacing = lineHeight + 6;

    for (int a = 0; a < NUM_LINES; a++) {
      CacheLine cl = cpus[i].lines[a];
      float ly = lineTop + a * lineSpacing;

      if (a == currentAddr) {
        noStroke();
        fill(60, 60, 100);
        rect(x + 15, ly - 2, cpuWidth - 30, lineHeight + 4, 4);
      }

      stroke(200);
      noFill();
      rect(x + 20, ly, cpuWidth - 40, lineHeight, 4);

      fill(mesiColor(cl.mesi));
      rect(x + 22, ly + 2, 40, lineHeight - 4, 3);

      fill(255);
      textAlign(LEFT, CENTER);
      text("A" + cl.addr, x + 70, ly + lineHeight/2);
      text("State: " + mesiNames[cl.mesi], x + 120, ly + lineHeight/2);
      text("Val: " + cl.value, x + 240, ly + lineHeight/2);
    }
  }
}

color mesiColor(int mesi) {
  switch (mesi) {
  case I: return color(90);
  case S: return color(0, 200, 0);
  case E: return color(255, 160, 0);
  case M: return color(230, 60, 60);
  default: return color(120);
  }
}

// Shared memory widened 5px left/right to align visually with caches
void drawMemory() {
  float margin = 15;                 // was 20; +5 each side
  float x = margin;
  float w = width - 2 * margin;
  float y = 300;
  float h = 90;

  stroke(255);
  fill(40);
  rect(x, y, w, h, 6);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Shared Main Memory", x + 10, y + 5);

  float cellWidth = (w - 40) / NUM_LINES;
  float cellTop = y + 30;
  float cellHeight = 40;

  for (int i = 0; i < NUM_LINES; i++) {
    float cx = x + 20 + i * cellWidth;
    stroke(200);
    noFill();
    rect(cx, cellTop, cellWidth - 10, cellHeight, 4);

    fill(255);
    textAlign(CENTER, CENTER);
    text("A" + i, cx + (cellWidth - 10)/2, cellTop + 12);
    text("Val: " + mem[i].value, cx + (cellWidth - 10)/2, cellTop + 28);
  }
}

// Bus between memory and bottom UI; messages drawn on the line
void drawBus() {
  float y = 410;
  stroke(180);
  strokeWeight(2);
  line(20, y, width - 20, y);
  strokeWeight(1);
  fill(255);
  textAlign(LEFT, BOTTOM);
  text("Bus (snooping): MESI coherence traffic", 25, y - 4);

  for (BusEvent e : busEvents) {
    float t = map(e.ttl, 0, 60, 1, 0);
    float xStart = 80 + e.srcCpu * (width/3.0);
    float xEnd   = width - 80;
    float x = lerp(xStart, xEnd, 1 - t);

    noStroke();
    fill(120, 200, 255, 180);
    ellipse(x, y, 80, 26);
    fill(0);
    textAlign(CENTER, CENTER);
    text(e.type + " A" + e.addr, x, y);
  }
}

void stepBusEvents() {
  for (int i = busEvents.size()-1; i >= 0; i--) {
    BusEvent e = busEvents.get(i);
    e.ttl--;
    if (e.ttl <= 0) {
      busEvents.remove(i);
    }
  }
}

// Bottom LEFT: controls and patterns
void drawControls() {
  float y = 440;

  fill(255);
  textAlign(LEFT, TOP);
  text("Controls:", 20, y);
  text("1/2/3: CPU   a/d: addr   r: read   w: write   s: auto   c: reset", 20, y+18);

  y += 40;
  text("MESI:  M=Modified  E=Exclusive  S=Shared  I=Invalid", 20, y);

  y += 20;
  text("Patterns:", 20, y);
  float tx = 35;
  float ty = y + 18;

  text("- Read miss: I -> BusRd, data from memory/peer, S/E.", tx, ty);
  ty += 16;
  text("- Write miss: I/S -> BusRdX, others I, M.", tx, ty);
  ty += 16;
  text("- Write hit: E/M -> local write, M.", tx, ty);
  ty += 16;
  text("- Read hit: S/E/M -> local read, no change.", tx, ty);
}

// Bottom RIGHT: scrolling log
void drawLog() {
  float x = width * 0.52;
  float y = 440;

  fill(255);
  textAlign(LEFT, TOP);
  text("Recent events:", x, y);
  y += 16;

  for (int i = max(0, logLines.size()-MAX_LOG); i < logLines.size(); i++) {
    text(logLines.get(i), x, y);
    y += 16;
  }
}

void log(String s) {
  logLines.add(s);
}

// ------------------ MESI operations ------------------

class CopyInfo {
  int numCopies;
  boolean anyModified;
  boolean anyExclusive;
  CopyInfo(int n, boolean m, boolean e) {
    numCopies = n;
    anyModified = m;
    anyExclusive = e;
  }
}

CopyInfo getCopies(int addr) {
  int n = 0;
  boolean m = false;
  boolean e = false;
  for (int i = 0; i < NUM_CPUS; i++) {
    CacheLine cl = cpus[i].lines[addr];
    if (cl.mesi != I) {
      n++;
      if (cl.mesi == M) m = true;
      if (cl.mesi == E) e = true;
    }
  }
  return new CopyInfo(n, m, e);
}

void localRead(int cpuId, int addr) {
  Cpu c = cpus[cpuId];
  CacheLine cl = c.lines[addr];
  if (cl.mesi == M || cl.mesi == E || cl.mesi == S) {
    log("CPU" + (cpuId+1) + " READ HIT A" + addr + " (" + mesiNames[cl.mesi] + ")");
  } else {
    log("CPU" + (cpuId+1) + " READ MISS A" + addr + " -> BusRd");
    busEvents.add(new BusEvent(cpuId, "BusRd", addr));

    CopyInfo info = getCopies(addr);

    int data;
    if (info.anyModified) {
      for (int i = 0; i < NUM_CPUS; i++) {
        CacheLine other = cpus[i].lines[addr];
        if (other.mesi == M) {
          data = other.value;
          other.mesi = S;
          log("  Snooping: CPU" + (i+1) + " supplies A" + addr + " M->S");
          cl.value = data;
        }
      }
      cl.mesi = S;
    } else {
      data = mem[addr].value;
      cl.value = data;
      if (info.numCopies == 0) {
        cl.mesi = E;
        log("  No other copies, CPU" + (cpuId+1) + " A" + addr + " I->E");
      } else {
        cl.mesi = S;
        log("  Other copies, CPU" + (cpuId+1) + " A" + addr + " I->S");
        for (int i = 0; i < NUM_CPUS; i++) {
          if (i == cpuId) continue;
          CacheLine other = cpus[i].lines[addr];
          if (other.mesi == E) {
            other.mesi = S;
            log("  Snooping: CPU" + (i+1) + " A" + addr + " E->S");
          }
        }
      }
    }
  }
}

void localWrite(int cpuId, int addr) {
  Cpu c = cpus[cpuId];
  CacheLine cl = c.lines[addr];

  cl.value++;

  if (cl.mesi == M) {
    log("CPU" + (cpuId+1) + " WRITE HIT A" + addr + " in M");
  } else if (cl.mesi == E) {
    log("CPU" + (cpuId+1) + " WRITE HIT A" + addr + " E->M (silent)");
    cl.mesi = M;
  } else if (cl.mesi == S) {
    log("CPU" + (cpuId+1) + " WRITE HIT A" + addr + " S->M via BusUpgr");
    busEvents.add(new BusEvent(cpuId, "BusUpgr", addr));

    for (int i = 0; i < NUM_CPUS; i++) {
      if (i == cpuId) continue;
      CacheLine other = cpus[i].lines[addr];
      if (other.mesi == S) {
        other.mesi = I;
        log("  Snooping: CPU" + (i+1) + " A" + addr + " S->I");
      } else if (other.mesi == E || other.mesi == M) {
        other.mesi = I;
        log("  Snooping: CPU" + (i+1) + " A" + addr + " -> I");
      }
    }
    cl.mesi = M;
  } else {
    log("CPU" + (cpuId+1) + " WRITE MISS A" + addr + " -> BusRdX");
    busEvents.add(new BusEvent(cpuId, "BusRdX", addr));

    CopyInfo info = getCopies(addr);
    int data = mem[addr].value;
    if (info.anyModified) {
      for (int i = 0; i < NUM_CPUS; i++) {
        CacheLine other = cpus[i].lines[addr];
        if (other.mesi == M) {
          data = other.value;
          other.mesi = I;
          log("  Snooping: CPU" + (i+1) + " supplies A" + addr + " M->I");
        } else if (other.mesi == S || other.mesi == E) {
          other.mesi = I;
          log("  Snooping: CPU" + (i+1) + " A" + addr + " S/E->I");
        }
      }
    } else {
      for (int i = 0; i < NUM_CPUS; i++) {
        CacheLine other = cpus[i].lines[addr];
        if (other.mesi == S || other.mesi == E) {
          other.mesi = I;
          log("  Snooping: CPU" + (i+1) + " A" + addr + " S/E->I");
        }
      }
    }
    cl.mesi = M;
  }

  mem[addr].value = cl.value;
}

// ------------------ Scenario ------------------

void doScenarioStep() {
  switch (scenarioStep) {
  case 0:
    activeCpu = 0;
    currentAddr = 0;
    localRead(activeCpu, currentAddr);
    break;
  case 1:
    activeCpu = 1;
    currentAddr = 0;
    localRead(activeCpu, currentAddr);
    break;
  case 2:
    activeCpu = 0;
    currentAddr = 0;
    localWrite(activeCpu, currentAddr);
    break;
  case 3:
    activeCpu = 2;
    currentAddr = 0;
    localRead(activeCpu, currentAddr);
    break;
  case 4:
    activeCpu = 1;
    currentAddr = 1;
    localWrite(activeCpu, currentAddr);
    break;
  case 5:
    activeCpu = 2;
    currentAddr = 1;
    localWrite(activeCpu, currentAddr);
    break;
  default:
    log("Scenario done.");
    autoStep = false;
    return;
  }
  scenarioStep++;
}

// ------------------ Input handling ------------------

void keyPressed() {
  if (key == '1') activeCpu = 0;
  if (key == '2') activeCpu = 1;
  if (key == '3') activeCpu = 2;

  if (key == 'a' || key == 'A') {
    currentAddr = (currentAddr + NUM_LINES - 1) % NUM_LINES;
  }
  if (key == 'd' || key == 'D') {
    currentAddr = (currentAddr + 1) % NUM_LINES;
  }

  if (key == 'r' || key == 'R') {
    localRead(activeCpu, currentAddr);
  }
  if (key == 'w' || key == 'W') {
    localWrite(activeCpu, currentAddr);
  }

  if (key == 's' || key == 'S') {
    autoStep = !autoStep;
    if (autoStep) {
      log("Starting auto scenario...");
      scenarioStep = 0;
      autoStepDelay = 10;
    } else {
      log("Stopping auto scenario.");
    }
  }

  if (key == 'c' || key == 'C') {
    initSystem();
  }
}
