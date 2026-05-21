// Lightning with quasi-electrostatics (Processing / Java)
// ------------------------------------------------------
// This version solves Laplace's equation ∇²V = 0 on a grid each frame
// with Dirichlet boundary conditions: cloud (top) at Vcloud, ground (bottom) at 0.
// Leader/streamer cells are treated as fixed-potential electrodes.
// Growth probabilities for each candidate frontier cell are ∝ |∇V|^η.
//
// Keys:  r = reset,  g = toggle fast growth, click = toggle tall ground object at mouse X
// Tune GW, GH, RELAX_PER_FRAME for performance vs. quality.

import java.util.List;

int CANV_W = 900, CANV_H = 1200;

// -------- Grid / physics --------
int GW = 140;                 // grid width  (cells)
int GH = 200;                 // grid height (cells)
float CELLW, CELLH;

int SKY_H = 18;               // top cloud band height (cells)
int GROUND_H = 8;             // ground band height

float Vcloud = 1.0f;          // cloud potential (ground = 0)
float eta = 1.6f;             // growth sharpness (1..2 typical)
int RELAX_PER_FRAME = 130;    // relaxation sweeps per frame (increase for smoother fields)
boolean fastGrowth = false;   // if true, grow more per update

// -------- States --------
final int AIR = 0, DOWN = 1, UP = 2, CONDUCT = 3;

// Simulation arrays
float[][] V;                  // potential
boolean[][] fixed;            // fixed-potential mask
float[][] Vfixed;             // fixed values where fixed==true
int[][] state;                // cell state

short[][] pxd, pyd;           // parents for DOWN tree
short[][] pxu, pyu;           // parents for UP tree

ArrayList<P> tipsDown = new ArrayList<>();
ArrayList<P> tipsUp   = new ArrayList<>();

boolean[] groundTall;         // preferred streamer launch columns

// Phases
enum Phase { RELAX_GROW, FLASH, AFTERGLOW }
Phase phase = Phase.RELAX_GROW;

ArrayList<P> connectedPath = new ArrayList<>();
int flashIdx = 0;
int afterglow = 0;

// Visuals
int skyCol = color(8, 12, 24);
int groundCol = color(20, 28, 36);
int leaderCol = color(120, 185, 255, 150);
int streamerCol = color(255, 210, 140, 130);
int pathColBright = color(245, 255, 255);
int pathColDim = color(120, 190, 255);

void settings() {
  size(CANV_W, CANV_H, P2D);
  smooth(4);
}

void setup() {
  CELLW = (float)width / GW;
  CELLH = (float)height / GH;
  initSim();
}

void initSim() {
  V = new float[GW][GH];
  fixed = new boolean[GW][GH];
  Vfixed = new float[GW][GH];
  state = new int[GW][GH];

  pxd = new short[GW][GH]; pyd = new short[GW][GH];
  pxu = new short[GW][GH]; pyu = new short[GW][GH];
  groundTall = new boolean[GW];

  tipsDown.clear(); tipsUp.clear();
  connectedPath.clear(); flashIdx = 0; afterglow = 0;
  phase = Phase.RELAX_GROW;

  // Boundaries: top cloud at Vcloud, bottom ground at 0
  for (int x=0; x<GW; x++) {
    for (int y=0; y<GH; y++) {
      V[x][y] = 0.0f;
      fixed[x][y] = false;
      Vfixed[x][y] = 0.0f;
      state[x][y] = AIR;
      pxd[x][y] = (short)x; pyd[x][y] = (short)y;
      pxu[x][y] = (short)x; pyu[x][y] = (short)y;
    }
  }
  for (int x=0; x<GW; x++) {
    for (int y=0; y<SKY_H; y++) { // cloud band
      fixed[x][y] = true;
      Vfixed[x][y] = Vcloud;
      V[x][y] = Vcloud;
    }
  }
  for (int x=0; x<GW; x++) {
    for (int y=GH-GROUND_H; y<GH; y++) { // ground band
      fixed[x][y] = true;
      Vfixed[x][y] = 0.0f;
      V[x][y] = 0.0f;
    }
  }

  // Random tall objects
  for (int x=0; x<GW; x++) {
    groundTall[x] = (random(1)<0.06);
  }

  // Seed downward leader below cloud
  int sx = constrain(GW/2 + (int)random(-10, 11), 2, GW-3);
  int sy = SKY_H;
  setDown(sx, sy, sx, sy);
  tipsDown.add(new P(sx, sy));

  // Seed upward streamers at ground (tall) + a few random
  for (int x=2; x<GW-2; x++) {
    if (groundTall[x] || random(1)<0.025) {
      int y = GH - GROUND_H - 1;
      setUp(x, y, x, y);
      tipsUp.add(new P(x, y));
    }
  }
}

void draw() {
  drawBackground();

  if (phase == Phase.RELAX_GROW) {
    // Relax potential field a number of sweeps
    for (int i=0; i<RELAX_PER_FRAME; i++) relaxSweepRedBlack();

    // After relaxation, compute one growth step using |∇V|
    int growsDown = fastGrowth ? 3 : 2;
    int growsUp   = fastGrowth ? 2 : 1;
    boolean connected = false;
    connected |= growOnce(true,  growsDown);
    if (!connected) connected |= growOnce(false, growsUp);

    // Render current state
    renderTrees();
    if (!connectedPath.isEmpty()) drawPath(connectedPath, pathColDim, 2.0f);

    if (connected) {
      phase = Phase.FLASH;
    }
  }
  else if (phase == Phase.FLASH) {
    // Fast bright return stroke animation
    renderTrees();
    flashIdx = min(flashIdx + 50, connectedPath.size());
    drawPath(connectedPath.subList(0, flashIdx), pathColBright, 5.0f);
    fill(255, 255, 255, 24);
    rect(0, 0, width, height);
    if (flashIdx >= connectedPath.size()) phase = Phase.AFTERGLOW;
  }
  else if (phase == Phase.AFTERGLOW) {
    renderTrees();
    drawPath(connectedPath, pathColDim, 3.0f);
    afterglow++;
    if (afterglow > 240) initSim();
  }

  drawHUD();
}

// ===== Potential solver (Red-Black Gauss–Seidel) =====
void relaxSweepRedBlack() {
  // Red cells
  for (int y=SKY_H+1; y<GH-GROUND_H-1; y++) {
    int xstart = ((y & 1)==0) ? 2 : 1;
    for (int x=xstart; x<GW-1; x+=2) {
      if (!fixed[x][y]) {
        V[x][y] = 0.25f*(V[x+1][y]+V[x-1][y]+V[x][y+1]+V[x][y-1]);
      }
    }
  }
  // Black cells
  for (int y=SKY_H+1; y<GH-GROUND_H-1; y++) {
    int xstart = ((y & 1)==0) ? 1 : 2;
    for (int x=xstart; x<GW-1; x+=2) {
      if (!fixed[x][y]) {
        V[x][y] = 0.25f*(V[x+1][y]+V[x-1][y]+V[x][y+1]+V[x][y-1]);
      }
    }
  }
}

// ===== Growth using |∇V| =====
boolean growOnce(boolean isDown, int grows) {
  if ((isDown && tipsDown.isEmpty()) || (!isDown && tipsUp.isEmpty())) return false;

  ArrayList<Cand> frontier = new ArrayList<>();
  ArrayList<P> tips = isDown ? tipsDown : tipsUp;
  int myState = isDown ? DOWN : UP;

  // Build candidate set: empty neighbors of each active tip
  for (int i=tips.size()-1; i>=0; i--) {
    P t = tips.get(i);
    ArrayList<P> n4 = nbr4(t.x, t.y);
    boolean hasViable = false;
    for (P n : n4) {
      if (!inGrowBounds(n.x, n.y)) continue;
      if (state[n.x][n.y] != AIR) continue;

      // Compute local |∇V|
      float Ex = (V[n.x+1][n.y] - V[n.x-1][n.y]) * 0.5f; // centered difference
      float Ey = (V[n.x][n.y+1] - V[n.x][n.y-1]) * 0.5f;
      float Emag = sqrt(max(0, Ex*Ex + Ey*Ey));

      // Small directional bias: down leaders prefer +y, up streamers prefer -y
      float dirBias = isDown ? (n.y - t.y) : (t.y - n.y);
      dirBias = max(0.0f, dirBias) + 0.05f;

      // Boost near ground for UP, near cloud for DOWN (launch tendency)
      float launchBoost = 1.0f;
      if (!isDown && n.y >= GH-GROUND_H-8) {
        launchBoost = (groundTall[n.x] ? 1.8f : 1.2f);
      }
      if (isDown && n.y <= SKY_H+8) launchBoost = 1.2f;

      float w = pow(Emag*1.0f + dirBias*0.15f, eta) * launchBoost;
      if (w > 0) {
        frontier.add(new Cand(n.x, n.y, t.x, t.y, w, myState));
        hasViable = true;
      }
    }
    // retire dead tips with no moves
    if (!hasViable) tips.remove(i);
  }

  if (frontier.isEmpty()) return false;

  boolean connected = false;
  int attempts = grows;
  while (attempts-- > 0 && !frontier.isEmpty()) {
    Cand c = pickWeighted(frontier);

    // Check contact with opposite tree (4-neighbor)
    if (touchOpposite(c.x, c.y, c.mode)) {
      // Commit this cell then build path
      if (isDown) setDown(c.x, c.y, c.px, c.py);
      else        setUp  (c.x, c.y, c.px, c.py);
      buildPathAtContact(c.x, c.y, c.mode);
      connected = true;
      break;
    }

    // Grow and keep as new tip
    if (isDown) setDown(c.x, c.y, c.px, c.py);
    else        setUp  (c.x, c.y, c.px, c.py);
    tips.add(new P(c.x, c.y));
  }
  return connected;
}

boolean touchOpposite(int x, int y, int myMode) {
  int want = (myMode==DOWN)? UP: DOWN;
  if (state[x+1][y]==want) return true;
  if (state[x-1][y]==want) return true;
  if (state[x][y+1]==want) return true;
  if (state[x][y-1]==want) return true;
  return false;
}

void buildPathAtContact(int x, int y, int lastMode) {
  // Find neighbor in opposite tree
  int ox=x, oy=y;
  int want = (lastMode==DOWN)? UP: DOWN;
  if (state[x+1][y]==want) { ox=x+1; oy=y; }
  else if (state[x-1][y]==want) { ox=x-1; oy=y; }
  else if (state[x][y+1]==want) { ox=x; oy=y+1; }
  else if (state[x][y-1]==want) { ox=x; oy=y-1; }

  // Trace to cloud via DOWN parents
  ArrayList<P> downPath = new ArrayList<>();
  int cx = (lastMode==DOWN)? x : ox;
  int cy = (lastMode==DOWN)? y : oy;
  while (true) {
    downPath.add(new P(cx, cy));
    if (pxd[cx][cy]==cx && pyd[cx][cy]==cy) break;
    int nx = pxd[cx][cy], ny = pyd[cx][cy];
    cx = nx; cy = ny;
  }

  // Trace to ground via UP parents
  ArrayList<P> upPath = new ArrayList<>();
  cx = (lastMode==DOWN)? ox : x;
  cy = (lastMode==DOWN)? oy : y;
  while (true) {
    upPath.add(new P(cx, cy));
    if (pxu[cx][cy]==cx && pyu[cx][cy]==cy) break;
    int nx = pxu[cx][cy], ny = pyu[cx][cy];
    cx = nx; cy = ny;
  }

  connectedPath.clear();
  connectedPath.addAll(downPath);
  for (int i=upPath.size()-1; i>=0; i--) connectedPath.add(upPath.get(i));
}

// ===== Rendering =====
void drawBackground() {
  for (int y=0; y<height; y++) {
    float t = constrain(map(y, 0, height, 0, 1), 0, 1);
    stroke(lerpColor(skyCol, groundCol, t));
    line(0, y, width, y);
  }
  noStroke();
  // Cloud and ground bands
  fill(20, 40, 80, 180);
  rect(0, 0, width, SKY_H*CELLH);
  fill(30, 40, 50, 220);
  rect(0, (GH-GROUND_H)*CELLH, width, GROUND_H*CELLH);

  // Tall objects
  for (int x=0; x<GW; x++) if (groundTall[x]) {
    float gx = x*CELLW, gy=(GH-GROUND_H)*CELLH;
    fill(80, 90, 100, 230);
    rect(gx, gy-18, CELLW, 18);
    rect(gx+CELLW*0.45, gy-18-28, CELLW*0.1, 28);
  }
}

void renderTrees() {
  noStroke();
  for (int x=1; x<GW-1; x++) {
    for (int y=SKY_H; y<GH-GROUND_H; y++) {
      if (state[x][y]==DOWN) {
        fill(leaderCol);
        rect(x*CELLW, y*CELLH, CELLW, CELLH);
      } else if (state[x][y]==UP) {
        fill(streamerCol);
        rect(x*CELLW, y*CELLH, CELLW, CELLH);
      }
    }
  }
}

//void drawPath(List<P> path, int col, float thick) {
//  stroke(col);
//  strokeWeight(thick);
//  noFill();
//  beginShape();
//  for (P p : path) vertex((p.x+0.5f)*CELLW, (p.y+0.5f)*CELLH);
//  endShape();
//  strokeWeight(1);
//}

void drawPath(List<P> path, int col, float thick) {
  stroke(col);
  strokeWeight(thick);
  noFill();
  beginShape();
  for (P p : path) {
    vertex((p.x+0.5f)*CELLW, (p.y+0.5f)*CELLH);
  }
  endShape();
  strokeWeight(1);
}

// ===== Utilities =====
class P { int x,y; P(int x,int y){this.x=x; this.y=y;} }
class Cand { int x,y,px,py,mode; float w; Cand(int x,int y,int px,int py,float w,int m){this.x=x;this.y=y;this.px=px;this.py=py;this.w=w;this.mode=m;} }

ArrayList<P> nbr4(int x,int y){
  ArrayList<P> n = new ArrayList<>(4);
  n.add(new P(x+1,y)); n.add(new P(x-1,y)); n.add(new P(x,y+1)); n.add(new P(x,y-1));
  return n;
}

boolean inGrowBounds(int x,int y){
  return (x>=1 && x<GW-1 && y>=SKY_H && y<GH-GROUND_H);
}

Cand pickWeighted(ArrayList<Cand> arr){
  float sum=0; for (Cand c:arr) sum+=c.w;
  float r = random(sum), acc=0;
  for (int i=0;i<arr.size();i++){ acc+=arr.get(i).w; if (r<=acc) return arr.remove(i); }
  return arr.remove(arr.size()-1);
}

void setDown(int x,int y,int px,int py){
  state[x][y]=DOWN;
  pxd[x][y]=(short)px; pyd[x][y]=(short)py;
  fixed[x][y]=true; Vfixed[x][y]=Vcloud; V[x][y]=Vcloud; // cloud-side conductor
}

void setUp(int x,int y,int px,int py){
  state[x][y]=UP;
  pxu[x][y]=(short)px; pyu[x][y]=(short)py;
  fixed[x][y]=true; Vfixed[x][y]=0.0f; V[x][y]=0.0f;       // ground-side conductor
}

// HUD / input
void drawHUD(){
  fill(255);
  textFont(createFont("Menlo", 12));
  String st = (phase==Phase.RELAX_GROW)?"grow/relax":(phase==Phase.FLASH?"return stroke":"afterglow");
  text("Lightning (Laplace growth) — phase: "+st+
       "   tipsDown:"+tipsDown.size()+" tipsUp:"+tipsUp.size()+
       "   relax/frame:"+RELAX_PER_FRAME+"   [r]eset  [g]rowth speed  click: toggle tall object",
       10, height-14);
}

void keyPressed(){
  if (key=='r'||key=='R') initSim();
  if (key=='g'||key=='G') fastGrowth = !fastGrowth;
}

void mousePressed(){
  int gx = int(map(mouseX, 0, width, 0, GW));
  if (gx>=0 && gx<GW) groundTall[gx] = !groundTall[gx];
}
