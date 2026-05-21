// Lite-Brite Honeycomb — Nested Hex Lattice (Small/Medium/Large preserve placement)
//
// FIXED:
// - No duplicate methods (only one drawBottomPanel())
// - Multi-click on SAME PEG cycles colors reliably
// - Black cycles through shades of gray (BLACK -> grays -> WHITE -> hues -> HOLE)
//
// UI:
// Buttons order: { New, Load, Animate, Save, Hide UI, Small, Medium, Large }
// Save offers: JSON, JPG, PNG
// No palette label / no tip label
// UI restore: click bottom-right peg when hidden
//
// Lattice nesting:
// - Master lattice at small resolution (axial q,r)
// - Medium shows q,r multiples of 2
// - Large shows q,r multiples of 4

import java.io.File;
import java.util.HashMap;

// ---------------- Codes ----------------
final int CODE_HOLE  = -1;
final int CODE_BLACK = -2;
final int CODE_WHITE = -3;

// Gray shades (dark -> light). Negative range.
final int CODE_GRAY_0 = -10; // darkest gray
final int CODE_GRAY_1 = -11;
final int CODE_GRAY_2 = -12;
final int CODE_GRAY_3 = -13;
final int CODE_GRAY_4 = -14; // lightest gray

// Multi-click timing
final int MULTI_CLICK_MS = 650;

// ---------------- View modes ----------------
final int SIZE_SMALL  = 0;
final int SIZE_MEDIUM = 1;
final int SIZE_LARGE  = 2;
int sizeMode = SIZE_MEDIUM;

// ---------------- Geometry ----------------
final int MED_R = 12;
final float MED_SP = 6.0f;

final int SMALL_R = 6;
final float SMALL_SP = 3.0f;

final int LARGE_R = 24;
final float LARGE_SP = 12.0f;

// Current radius (depends on view)
int r = MED_R;

// Base lattice (small pitch/vStep)
float basePitch;   // 15
float baseVStep;

// View nesting step: 1 (small), 2 (medium), 4 (large)
int viewStep = 2;

// 24 hue palette
color[] huePalette = new color[24];

// Master color map by axial key (q,r)
HashMap<Long, Integer> colorByKey = new HashMap<Long, Integer>();

// Visible pegs for current view
class PegV {
  float x, y;
  int q, rr;
  int cidx;
  PegV(float x,float y,int q,int rr,int cidx){ this.x=x; this.y=y; this.q=q; this.rr=rr; this.cidx=cidx; }
}
ArrayList<PegV> viewPegs = new ArrayList<PegV>();

// Brush (palette selection)
int currentBrush = CODE_WHITE;

// Multi-click tracking
long lastClickedKey = Long.MIN_VALUE;
int lastClickMillis = -999999;

// UI
boolean uiHidden = false;
int panelH = 116;

Button btnNew, btnLoad, btnAnimate, btnSave, btnHide, btnSmall, btnMedium, btnLarge;
boolean showSaveMenu = false;
Button btnSaveJSON, btnSaveJPG, btnSavePNG, btnSaveCancel;
String pendingSaveKind = ""; // "json"|"jpg"|"png"

// Palette layout
int paletteX0 = 16;
int palettePad = 6;

// Animation
class StrokeEvent {
  long key;
  int newCidx;
  StrokeEvent(long key, int newCidx){ this.key=key; this.newCidx=newCidx; }
}
ArrayList<StrokeEvent> events = new ArrayList<StrokeEvent>();
boolean animPlaying = false;
int animIndex = 0;
int animLastMillis = 0;
final int ANIM_FPS = 8;
final int ANIM_INTERVAL_MS = 1000 / ANIM_FPS;

// Repaint
boolean fullRepaintNext = true;

// Hidden hint
int hiddenHintUntilMillis = 0;

// ---------------- Button ----------------
class Button {
  String label; int x,y,w,h;
  Button(String label, int x, int y, int w, int h){
    this.label=label; this.x=x; this.y=y; this.w=w; this.h=h;
  }
  void draw(boolean active){
    pushStyle();
    fill(active ? 60 : 30); noStroke();
    rect(x,y,w,h,10);
    stroke(active ? 200 : 90); noFill();
    rect(x,y,w,h,10);
    fill(230); noStroke();
    textAlign(CENTER,CENTER);
    textSize(12);
    text(label, x+w/2, y+h/2);
    popStyle();
  }
  void draw(){ draw(false); }
  boolean hit(int mx,int my){
    return mx>=x && mx<=x+w && my>=y && my<=y+h;
  }
}

// ---------------- Setup/Draw ----------------
void setup(){
  surface.setSize(1000, 720);
  pixelDensity(1);
  surface.setTitle("Lite-Brite — Multi-click Cycle + Gray Shades (fixed)");

  colorMode(HSB,360,100,100,255);
  buildHuePalette();

  basePitch = 2*SMALL_R + SMALL_SP;          // 15
  baseVStep = basePitch * sqrt(3) / 2.0f;

  layoutUI();
  setSizeMode(SIZE_MEDIUM);

  // init visible pegs to holes in master map
  for (PegV pv : viewPegs) setColor(pv.q, pv.rr, CODE_HOLE);

  fullRepaintNext = true;
}

void draw(){
  if (animPlaying) stepAnimationIfNeeded();

  if (fullRepaintNext){
    background(0);
    drawBoard();
    fullRepaintNext = false;
  }

  if (!uiHidden){
    drawBottomPanel();
    if (showSaveMenu) drawSaveMenu();
  } else {
    drawHiddenHint();
  }
}

// ---------------- Palette ----------------
void buildHuePalette(){
  for(int i=0;i<huePalette.length;i++){
    float h = map(i, 0, huePalette.length-1, 0, 270);
    huePalette[i] = color(h,100,100);
  }
}

color codeToColor(int cidx){
  if (cidx == CODE_BLACK) return color(0,0,0);
  if (cidx == CODE_WHITE) return color(0,0,100);

  // gray shades -10..-14
  if (cidx <= CODE_GRAY_0 && cidx >= CODE_GRAY_4){
    int idx = -(cidx + 10); // -10->0 ... -14->4
    float b = map(idx, 0, 4, 18, 85);
    return color(0, 0, b);
  }

  if (cidx >= 0 && cidx < huePalette.length) return huePalette[cidx];
  return color(0,0,0);
}

// ---------------- Key helpers ----------------
long packKey(int q, int rr){
  return (((long)q) << 32) ^ (rr & 0xffffffffL);
}

int getColor(int q, int rr){
  Integer v = colorByKey.get(packKey(q, rr));
  return (v == null) ? CODE_HOLE : v;
}

void setColor(int q, int rr, int cidx){
  colorByKey.put(packKey(q, rr), cidx);
}

void recordEvent(int q, int rr, int cidx){
  events.add(new StrokeEvent(packKey(q, rr), cidx));
}

// ---------------- Size mode / nesting ----------------
void setSizeMode(int mode){
  sizeMode = mode;

  if (mode == SIZE_SMALL){
    viewStep = 1;
    r = SMALL_R;
  } else if (mode == SIZE_MEDIUM){
    viewStep = 2;
    r = MED_R;
  } else {
    viewStep = 4;
    r = LARGE_R;
  }

  rebuildViewPegs();
  fullRepaintNext = true;
}

void rebuildViewPegs(){
  viewPegs.clear();

  int rrMin = floor(0 / baseVStep) - 2;
  int rrMax = ceil(height / baseVStep) + 2;

  for (int rr = rrMin; rr <= rrMax; rr++){
    if (rr % viewStep != 0) continue;

    float rrHalf = rr / 2.0f;
    int qMin = floor(0 / basePitch - rrHalf) - 6;
    int qMax = ceil(width / basePitch - rrHalf) + 6;

    for (int q = qMin; q <= qMax; q++){
      if (q % viewStep != 0) continue;

      float x = basePitch * (q + rrHalf);
      float y = baseVStep  * rr;

      if (x < r || x > width - r) continue;
      if (y < r || y > height - r) continue;

      int cidx = getColor(q, rr);
      viewPegs.add(new PegV(x, y, q, rr, cidx));
    }
  }
  syncViewColorsFromMaster();
  lastClickedKey = Long.MIN_VALUE;
}

void syncViewColorsFromMaster(){
  for (PegV pv : viewPegs){
    pv.cidx = getColor(pv.q, pv.rr);
  }
}

// ---------------- Cycling ----------------
int cycleNext(int cur){
  if (cur == CODE_HOLE) return CODE_BLACK;
  if (cur == CODE_BLACK) return CODE_GRAY_0;
  if (cur == CODE_GRAY_0) return CODE_GRAY_1;
  if (cur == CODE_GRAY_1) return CODE_GRAY_2;
  if (cur == CODE_GRAY_2) return CODE_GRAY_3;
  if (cur == CODE_GRAY_3) return CODE_GRAY_4;
  if (cur == CODE_GRAY_4) return CODE_WHITE;
  if (cur == CODE_WHITE) return 0;
  if (cur >= 0 && cur < 23) return cur + 1;
  if (cur == 23) return CODE_HOLE;
  return CODE_HOLE;
}

// ---------------- UI Layout ----------------
void layoutUI(){
  int topY = height - panelH + 10;

  btnNew     = new Button("New",     16,  topY, 70, 28);
  btnLoad    = new Button("Load",    92,  topY, 70, 28);
  btnAnimate = new Button("Animate", 168, topY, 90, 28);
  btnSave    = new Button("Save",    264, topY, 70, 28);
  btnHide    = new Button("Hide UI", 340, topY, 90, 28);

  btnSmall   = new Button("Small",   436, topY, 80, 28);
  btnMedium  = new Button("Medium",  522, topY, 80, 28);
  btnLarge   = new Button("Large",   608, topY, 80, 28);

  btnSaveJSON   = new Button("JSON",   0,0, 80, 28);
  btnSaveJPG    = new Button("JPG",    0,0, 80, 28);
  btnSavePNG    = new Button("PNG",    0,0, 80, 28);
  btnSaveCancel = new Button("Cancel", 0,0, 90, 28);
}

// ---------------- Board drawing ----------------
void drawBoard(){
  syncViewColorsFromMaster();
  noStroke();
  for (PegV pv : viewPegs) drawPeg(pv);
}

void drawPeg(PegV pv){
  int cidx = pv.cidx;

  if (cidx == CODE_HOLE){
    pushStyle();
    noFill();
    stroke(0, 0, 60, 180);
    strokeWeight(2);
    ellipse(pv.x, pv.y, r*2, r*2);
    popStyle();
    return;
  }

  color c = codeToColor(cidx);

  // halo
  if (cidx == CODE_BLACK)      fill(0,0,0,70);
  else if (cidx == CODE_WHITE) fill(0,0,100,50);
  else if (cidx <= CODE_GRAY_0 && cidx >= CODE_GRAY_4) fill(0,0,50,50);
  else                         fill(hue(c), 60, 40, 60);

  noStroke();
  ellipse(pv.x, pv.y, r*3.2, r*3.2);

  // face
  fill(c);
  ellipse(pv.x, pv.y, r*2, r*2);
}

// ---------------- Bottom panel + palette ----------------
void drawBottomPanel(){
  pushStyle();
  int top = height - panelH;
  noStroke(); fill(10);
  rect(0, top, width, panelH);
  stroke(40);
  line(0, top, width, top);
  noStroke();

  btnNew.draw();
  btnLoad.draw();
  btnAnimate.draw(animPlaying);
  btnSave.draw();
  btnHide.draw();

  btnSmall.draw(sizeMode == SIZE_SMALL);
  btnMedium.draw(sizeMode == SIZE_MEDIUM);
  btnLarge.draw(sizeMode == SIZE_LARGE);

  drawPaletteRow();

  popStyle();
}

int paletteCount(){ return 3 + 24; } // HOLE, BLACK, WHITE, 24 hues

void drawPaletteRow(){
  int n = paletteCount();
  int availW = width - 2*paletteX0;
  int sw = floor((availW - (n-1)*palettePad) / (float)n);
  sw = constrain(sw, 12, 28);

  int totalW = n*sw + (n-1)*palettePad;
  int x0 = paletteX0 + (availW - totalW)/2;
  int y0 = height - panelH + 54;

  int i = 0;
  drawSwatch(x0 + i*(sw+palettePad), y0, sw, CODE_HOLE);  i++;
  drawSwatch(x0 + i*(sw+palettePad), y0, sw, CODE_BLACK); i++;
  drawSwatch(x0 + i*(sw+palettePad), y0, sw, CODE_WHITE); i++;
  for (int k=0;k<24;k++){
    drawSwatch(x0 + i*(sw+palettePad), y0, sw, k);
    i++;
  }
}

void drawSwatch(int x, int y, int s, int code){
  pushStyle();

  if (code == CODE_HOLE){
    fill(0); rect(x, y, s, s, 5);
    noFill(); stroke(0,0,70); strokeWeight(2);
    rect(x, y, s, s, 5);
    ellipse(x + s/2, y + s/2, s*0.55, s*0.55);
  } else if (code == CODE_BLACK){
    fill(0); rect(x, y, s, s, 5);
    noFill(); stroke(0,0,70); strokeWeight(2);
    rect(x, y, s, s, 5);
  } else if (code == CODE_WHITE){
    fill(0,0,100); rect(x, y, s, s, 5);
    noFill(); stroke(0,0,70); strokeWeight(2);
    rect(x, y, s, s, 5);
  } else {
    fill(codeToColor(code)); rect(x, y, s, s, 5);
    noFill(); stroke(90);
    rect(x, y, s, s, 5);
  }

  if (currentBrush == code){
    noFill(); stroke(255); strokeWeight(2);
    rect(x-2, y-2, s+4, s+4, 7);
  }

  popStyle();
}

// ---------------- Save menu ----------------
int saveMenuW = 320, saveMenuH = 90;
int saveMenuX(){ return width - saveMenuW - 16; }
int saveMenuY(){ return height - panelH - saveMenuH - 10; }

boolean hitSaveMenu(int mx,int my){
  int x=saveMenuX(), y=saveMenuY();
  return mx>=x && mx<=x+saveMenuW && my>=y && my<=y+saveMenuH;
}

void drawSaveMenu(){
  pushStyle();
  int x=saveMenuX(), y=saveMenuY();

  fill(20, 235); noStroke();
  rect(x, y, saveMenuW, saveMenuH, 14);
  stroke(90); noFill();
  rect(x, y, saveMenuW, saveMenuH, 14);

  int by = y + 40;

  btnSaveJSON.x = x + 12;  btnSaveJSON.y = by;
  btnSaveJPG.x  = x + 98;  btnSaveJPG.y  = by;
  btnSavePNG.x  = x + 184; btnSavePNG.y  = by;

  btnSaveCancel.x = x + saveMenuW - 12 - btnSaveCancel.w;
  btnSaveCancel.y = y + 10;

  btnSaveJSON.draw();
  btnSaveJPG.draw();
  btnSavePNG.draw();
  btnSaveCancel.draw();

  popStyle();
}

// ---------------- Hidden hint ----------------
void drawHiddenHint(){
  int now = millis();
  if (now > hiddenHintUntilMillis) return;

  pushStyle();
  fill(0, 180); noStroke();
  rect(12, 12, 370, 34, 10);
  fill(255); textAlign(LEFT, CENTER); textSize(13);
  text("UI hidden — click bottom-right peg to show UI", 22, 29);
  popStyle();
}

// ---------------- Hit testing ----------------
int hitPaletteCode(int mx, int my){
  int n = paletteCount();
  int availW = width - 2*paletteX0;
  int sw = floor((availW - (n-1)*palettePad) / (float)n);
  sw = constrain(sw, 12, 28);
  int totalW = n*sw + (n-1)*palettePad;
  int x0 = paletteX0 + (availW - totalW)/2;
  int y0 = height - panelH + 54;

  if (my < y0 || my > y0 + sw) return Integer.MIN_VALUE;

  for(int i=0;i<n;i++){
    int x = x0 + i*(sw+palettePad);
    if (mx>=x && mx<=x+sw){
      if (i==0) return CODE_HOLE;
      if (i==1) return CODE_BLACK;
      if (i==2) return CODE_WHITE;
      return (i-3);
    }
  }
  return Integer.MIN_VALUE;
}

PegV hitPeg(float mx, float my){
  if (!uiHidden && my >= height - panelH) return null;

  PegV found = null;
  float best = 1e9;
  for (PegV pv : viewPegs){
    float d = dist(mx, my, pv.x, pv.y);
    if (d <= r && d < best){ best = d; found = pv; }
  }
  return found;
}

PegV bottomRightPeg(){
  PegV best = null;
  float bestY = -1, bestX = -1;
  for (PegV pv : viewPegs){
    if (pv.y > bestY + 1e-6){
      bestY = pv.y; bestX = pv.x; best = pv;
    } else if (abs(pv.y - bestY) < 1e-6 && pv.x > bestX){
      bestX = pv.x; best = pv;
    }
  }
  return best;
}

// ---------------- Interaction ----------------
void mousePressed(){
  if (animPlaying) return;

  // UI restore when hidden
  if (uiHidden){
    PegV pv = hitPeg(mouseX, mouseY);
    PegV br = bottomRightPeg();
    if (pv != null && br != null && pv.q == br.q && pv.rr == br.rr){
      toggleHideUI();
      return;
    }
  }

  // Save menu clicks
  if (!uiHidden && showSaveMenu && hitSaveMenu(mouseX, mouseY)){
    if (btnSaveCancel.hit(mouseX, mouseY)){
      showSaveMenu = false; fullRepaintNext = true; return;
    }
    if (btnSaveJSON.hit(mouseX, mouseY)){
      pendingSaveKind="json"; showSaveMenu=false;
      selectOutput("Save JSON (.json)", "fileSaveAsChosen");
      return;
    }
    if (btnSaveJPG.hit(mouseX, mouseY)){
      pendingSaveKind="jpg"; showSaveMenu=false;
      selectOutput("Save JPG (.jpg)", "fileSaveAsChosen");
      return;
    }
    if (btnSavePNG.hit(mouseX, mouseY)){
      pendingSaveKind="png"; showSaveMenu=false;
      selectOutput("Save PNG (.png)", "fileSaveAsChosen");
      return;
    }
    return;
  }

  // Bottom panel controls
  if (!uiHidden && mouseY >= height - panelH){
    int code = hitPaletteCode(mouseX, mouseY);
    if (code != Integer.MIN_VALUE){
      currentBrush = code;
      lastClickedKey = Long.MIN_VALUE;
      return;
    }

    if (btnNew.hit(mouseX, mouseY)){ newDrawing(); return; }
    if (btnLoad.hit(mouseX, mouseY)){ selectInput("Load JSON (.json)", "fileLoadPattern"); return; }
    if (btnAnimate.hit(mouseX, mouseY)){ toggleAnimation(); return; }
    if (btnSave.hit(mouseX, mouseY)){ showSaveMenu = true; fullRepaintNext = true; return; }
    if (btnHide.hit(mouseX, mouseY)){ toggleHideUI(); return; }

    if (btnSmall.hit(mouseX, mouseY)){ setSizeMode(SIZE_SMALL); return; }
    if (btnMedium.hit(mouseX, mouseY)){ setSizeMode(SIZE_MEDIUM); return; }
    if (btnLarge.hit(mouseX, mouseY)){ setSizeMode(SIZE_LARGE); return; }

    return;
  }

  // Board paint/cycle
  PegV pv = hitPeg(mouseX, mouseY);
  if (pv == null) return;

  long k = packKey(pv.q, pv.rr);
  int cur = getColor(pv.q, pv.rr);

  int now = millis();
  boolean samePeg = (k == lastClickedKey);
  boolean withinWindow = (now - lastClickMillis) <= MULTI_CLICK_MS;
  boolean doCycle = (mouseButton == LEFT) && samePeg && withinWindow;

  int newCode;
  if (mouseButton == RIGHT){
    newCode = CODE_HOLE;
  } else {
    newCode = doCycle ? cycleNext(cur) : currentBrush;
    if (doCycle) currentBrush = newCode; // optional: brush follows cycle
  }

  if (cur != newCode){
    setColor(pv.q, pv.rr, newCode);
    recordEvent(pv.q, pv.rr, newCode);
    fullRepaintNext = true;
  }

  lastClickedKey = k;
  lastClickMillis = now;
}

void mouseDragged(){
  if (animPlaying) return;

  PegV pv = hitPeg(mouseX, mouseY);
  if (pv == null) return;

  int cur = getColor(pv.q, pv.rr);
  int newCode = (mouseButton == RIGHT) ? CODE_HOLE : currentBrush;

  if (cur != newCode){
    setColor(pv.q, pv.rr, newCode);
    recordEvent(pv.q, pv.rr, newCode);
    fullRepaintNext = true;
  }

  lastClickedKey = packKey(pv.q, pv.rr);
  lastClickMillis = millis();
}

void newDrawing(){
  colorByKey.clear();
  events.clear();
  animPlaying = false;
  animIndex = 0;
  lastClickedKey = Long.MIN_VALUE;
  lastClickMillis = -999999;
  fullRepaintNext = true;
}

void toggleHideUI(){
  uiHidden = !uiHidden;
  showSaveMenu = false;
  if (uiHidden) hiddenHintUntilMillis = millis() + 5000;
  fullRepaintNext = true;
}

// ---------------- Animation ----------------
void toggleAnimation(){
  if (animPlaying){
    animPlaying = false;
    fullRepaintNext = true;
    return;
  }
  animPlaying = true;
  animIndex = 0;
  animLastMillis = millis();

  colorByKey.clear(); // blank start
  lastClickedKey = Long.MIN_VALUE;
  lastClickMillis = -999999;
  fullRepaintNext = true;
}

void stepAnimationIfNeeded(){
  int now = millis();
  if (now - animLastMillis < ANIM_INTERVAL_MS) return;
  animLastMillis = now;

  if (animIndex >= events.size()){
    animPlaying = false;
    fullRepaintNext = true;
    return;
  }

  StrokeEvent ev = events.get(animIndex++);
  int q = (int)(ev.key >> 32);
  int rr = (int)(ev.key & 0xffffffffL);
  setColor(q, rr, ev.newCidx);
  fullRepaintNext = true;
}

// ---------------- Save/Load ----------------
void fileSaveAsChosen(File selection){
  if (selection == null) return;

  String out = selection.getAbsolutePath();
  String k = pendingSaveKind;
  pendingSaveKind = "";

  if (k.equals("json")){
    if (!out.toLowerCase().endsWith(".json")) out += ".json";
    saveJSON(out);
  } else if (k.equals("jpg")){
    if (!out.toLowerCase().endsWith(".jpg") && !out.toLowerCase().endsWith(".jpeg")) out += ".jpg";
    exportRaster(out);
  } else if (k.equals("png")){
    if (!out.toLowerCase().endsWith(".png")) out += ".png";
    exportRaster(out);
  }

  println("Saved: " + out);
}

void saveJSON(String path){
  JSONObject root = new JSONObject();
  root.setInt("sizeMode", sizeMode);

  JSONArray cells = new JSONArray();
  for (Long key : colorByKey.keySet()){
    JSONObject o = new JSONObject();
    o.setInt("q", (int)(key >> 32));
    o.setInt("r", (int)(key & 0xffffffffL));
    o.setInt("c", colorByKey.get(key));
    cells.append(o);
  }
  root.setJSONArray("cells", cells);

  JSONArray evs = new JSONArray();
  for (StrokeEvent e : events){
    JSONObject o = new JSONObject();
    o.setInt("q", (int)(e.key >> 32));
    o.setInt("r", (int)(e.key & 0xffffffffL));
    o.setInt("c", e.newCidx);
    evs.append(o);
  }
  root.setJSONArray("events", evs);

  saveJSONObject(root, path);
}

void fileLoadPattern(File selection){
  if (selection == null) return;
  JSONObject root = loadJSONObject(selection.getAbsolutePath());
  if (root == null) return;

  colorByKey.clear();
  events.clear();

  int sm = root.hasKey("sizeMode") ? root.getInt("sizeMode") : SIZE_MEDIUM;
  if (sm != SIZE_SMALL && sm != SIZE_MEDIUM && sm != SIZE_LARGE) sm = SIZE_MEDIUM;
  setSizeMode(sm);

  JSONArray cells = root.getJSONArray("cells");
  for (int i=0;i<cells.size();i++){
    JSONObject o = cells.getJSONObject(i);
    setColor(o.getInt("q"), o.getInt("r"), o.getInt("c"));
  }

  if (root.hasKey("events")){
    JSONArray evs = root.getJSONArray("events");
    for (int i=0;i<evs.size();i++){
      JSONObject o = evs.getJSONObject(i);
      events.add(new StrokeEvent(packKey(o.getInt("q"), o.getInt("r")), o.getInt("c")));
    }
  }

  animPlaying = false;
  animIndex = 0;
  lastClickedKey = Long.MIN_VALUE;
  lastClickMillis = -999999;
  fullRepaintNext = true;

  println("Loaded: " + selection.getAbsolutePath());
}

// Raster export of FULL WINDOW (pattern only; UI is not drawn)
void exportRaster(String outPath){
  PGraphics pg = createGraphics(width, height, JAVA2D);
  pg.beginDraw();
  pg.background(0);
  pg.colorMode(HSB,360,100,100,255);

  // Render current view
  syncViewColorsFromMaster();
  for (PegV pv : viewPegs){
    int cidx = pv.cidx;
    if (cidx == CODE_HOLE){
      pg.noFill();
      pg.stroke(0,0,60,180);
      pg.strokeWeight(2);
      pg.ellipse(pv.x, pv.y, r*2, r*2);
    } else {
      color c = codeToColor(cidx);
      pg.noStroke();
      if (cidx == CODE_BLACK) pg.fill(0,0,0,70);
      else if (cidx == CODE_WHITE) pg.fill(0,0,100,50);
      else if (cidx <= CODE_GRAY_0 && cidx >= CODE_GRAY_4) pg.fill(0,0,50,50);
      else pg.fill(hue(c), 60, 40, 60);
      pg.ellipse(pv.x, pv.y, r*3.2, r*3.2);

      pg.fill(c);
      pg.ellipse(pv.x, pv.y, r*2, r*2);
    }
  }

  pg.endDraw();
  pg.save(outPath);
}
